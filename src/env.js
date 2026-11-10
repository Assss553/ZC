// تحميل الإعدادات قبل أي شي ثاني (لازم يُستورد أول ملف)
import { existsSync } from 'node:fs';
if (existsSync('.env')) process.loadEnvFile('.env');

// Netlify Functions (وأي استضافة serverless تعمل على AWS Lambda)
export const SERVERLESS = !!process.env.AWS_LAMBDA_FUNCTION_NAME;
const nenv = (k) => process.env[k] || globalThis.Netlify?.env?.get?.(k) || '';
if (SERVERLESS) {
  process.env.NODE_ENV ||= 'production';
  process.env.TRUST_PROXY ||= '1';
}
// قاعدة Netlify Database تعطي الرابط باسم NETLIFY_DB_URL
if (!process.env.DATABASE_URL && nenv('NETLIFY_DB_URL')) process.env.DATABASE_URL = nenv('NETLIFY_DB_URL');
// رابط الموقع: Render أو Netlify يعطونه تلقائيًا
if (!process.env.PUBLIC_URL) process.env.PUBLIC_URL = process.env.RENDER_EXTERNAL_URL || nenv('URL') || '';

// في الإنتاج لازم قاعدة بيانات خارجية: قرص الاستضافات المجانية يُمسح
if (process.env.NODE_ENV === 'production' && !process.env.DATABASE_URL && process.env.ALLOW_LOCAL_DB !== 'true') {
  throw new Error('DATABASE_URL غير مضبوط. أضف رابط قاعدة PostgreSQL في متغيرات البيئة.');
}
