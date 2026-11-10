// استوديو التصميم بالذكاء الاصطناعي (Claude)
import './env.js';
// من فكرة مكتوبة ← يولّد: اسم المنتج، الوصف، السعر، الألوان، المواصفات، والرسمة نفسها.
import Anthropic from '@anthropic-ai/sdk';
import { TYPES } from './svg.js';

const MODEL = process.env.AI_MODEL || 'claude-opus-5-5';
let client;
function ai() {
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
    const e = new Error('مفتاح الذكاء الاصطناعي غير مضبوط. أضف ANTHROPIC_API_KEY في ملف .env');
    e.status = 503; throw e;
  }
  return (client ??= new Anthropic({ maxRetries: 2, timeout: 5 * 60 * 1000 }));
}

const shape = {
  type: 'object', additionalProperties: false,
  required: ['kind', 'd', 'x', 'y', 'r', 'text', 'fontSize', 'fill', 'stroke', 'strokeWidth', 'opacity', 'rotate'],
  properties: {
    kind: { type: 'string', enum: ['path', 'circle', 'text'] },
    d: { type: 'string', description: 'SVG path data for kind=path (absolute/relative commands only), else empty string' },
    x: { type: 'number' }, y: { type: 'number' },
    r: { type: 'number', description: 'radius for circle, else 0' },
    text: { type: 'string', description: 'for kind=text, max 18 chars, else empty' },
    fontSize: { type: 'number' },
    fill: { type: 'string', description: '#rrggbb or "none"' },
    stroke: { type: 'string', description: '#rrggbb or "none"' },
    strokeWidth: { type: 'number' },
    opacity: { type: 'number', description: '0..1' },
    rotate: { type: 'number', description: 'degrees' },
  },
};

const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['products'],
  properties: {
    products: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'description', 'type', 'price', 'comparePrice', 'background', 'garment', 'tags', 'specs', 'artwork'],
        properties: {
          name: { type: 'string', description: 'اسم عربي قصير وجذاب (2-4 كلمات)' },
          description: { type: 'string', description: 'وصف تسويقي عربي 2-3 جمل' },
          type: { type: 'string', enum: Object.keys(TYPES) },
          price: { type: 'integer', description: 'السعر بالريال السعودي' },
          comparePrice: { type: 'integer', description: 'سعر قبل الخصم أو 0' },
          background: { type: 'string', description: 'لون خلفية صورة المنتج #rrggbb' },
          garment: { type: 'string', description: 'لون القماش #rrggbb' },
          tags: { type: 'array', items: { type: 'string' } },
          specs: {
            type: 'array',
            items: { type: 'object', additionalProperties: false, required: ['label', 'value'], properties: { label: { type: 'string' }, value: { type: 'string' } } },
          },
          artwork: { type: 'array', items: shape },
        },
      },
    },
  },
};

const SYSTEM = `أنت المصمم الرئيسي لعلامة ملابس الشارع السعودية "ROX".
هوية ROX: جريئة، حادة، خطوط مائلة 14 درجة، أسود + أحمر (#e1281c) + عاجي (#efeae2) كأساس، مع حرية في ألوان أخرى إذا الفكرة تطلب.
مهمتك: تحويل فكرة صاحب المتجر إلى منتجات جاهزة للبيع.

قواعد الرسمة (artwork):
- لوحة الرسم 200×200، المركز (100,100). خلّ الرسمة داخل 10..190.
- رسمة قوية تنفع للطباعة على صدر القطعة: أشكال واضحة وجريئة، 8 إلى 40 شكل.
- استخدم path للأشكال المعقدة (أوامر M L H V C Q A Z فقط بأرقام)، circle للدوائر، text لكلمة لاتينية قصيرة كبيرة (اختياري).
- الألوان لازم تتباين بقوة مع لون القماش (garment) عشان الطباعة تبان.
- ممنوع أي شعار أو شخصية أو علامة تجارية مملوكة لغيرنا. التصميم أصلي 100%.

قواعد التسعير (ريال سعودي، أرقام تنتهي بـ9):
تيشيرت 89-169، سويت شيرت 169-259، هودي 199-329، كاب 79-139، شنطة قماش 59-119، ماوس باد 59-129.
comparePrice يكون 0 غالبًا، واستخدمه فقط لإصدار محدود بخصم واضح.

specs: 3-4 مواصفات مثل الخامة، الوزن، القصّة، الطباعة. tags: 2-4 كلمات.
اكتب الاسم والوصف بالعربي بلهجة سعودية راقية وقريبة.`;

export async function generateProducts({ brief, type = 'any', count = 3 }) {
  const want = type !== 'any' && TYPES[type] ? `كل المنتجات من نوع: ${TYPES[type].ar} (${type}).` : 'نوّع بين أنواع القطع المناسبة للفكرة.';
  const stream = ai().beta.messages.stream({
    model: MODEL,
    max_tokens: 32000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    thinking: { type: 'adaptive' },
    output_config: { effort: 'high', format: { type: 'json_schema', schema: SCHEMA } },
    system: SYSTEM,
    messages: [{
      role: 'user',
      content: `فكرة التشكيلة:\n"""${brief}"""\n\nصمّم ${count} منتج${count > 1 ? 'ات' : ''} مختلفة. ${want}`,
    }],
  });
  const msg = await stream.finalMessage();
  if (msg.stop_reason === 'refusal') {
    const e = new Error('الذكاء الاصطناعي رفض هذه الفكرة. جرّب صياغة مختلفة.'); e.status = 422; throw e;
  }
  if (msg.stop_reason === 'max_tokens') {
    const e = new Error('الرد كان أطول من المسموح. قلّل عدد المنتجات وحاول مرة ثانية.'); e.status = 502; throw e;
  }
  const text = msg.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  let data;
  try { data = JSON.parse(text); } catch {
    const e = new Error('رد الذكاء الاصطناعي غير مكتمل. حاول مرة ثانية.'); e.status = 502; throw e;
  }
  return { products: Array.isArray(data.products) ? data.products.slice(0, count) : [], usage: msg.usage };
}
