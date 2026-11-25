#!/usr/bin/env bash
# يثبّت الذكاء الاصطناعي الخاص على سيرفر Linux فيه كرت NVIDIA (يفضّل 12GB VRAM أو أكثر)
set -e
cd "$(dirname "$0")/.."

echo "== 1) Ollama (كتابة السيناريو) =="
command -v ollama >/dev/null || curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:14b

echo "== 2) Piper (الصوت العربي) =="
pip install --user piper-tts
mkdir -p voices
base=https://huggingface.co/rhasspy/piper-voices/resolve/main/ar/ar_JO/kareem/medium
curl -fL -o voices/ar_JO-kareem-medium.onnx      $base/ar_JO-kareem-medium.onnx
curl -fL -o voices/ar_JO-kareem-medium.onnx.json $base/ar_JO-kareem-medium.onnx.json

echo "== 3) Stable Diffusion WebUI (الصور) =="
[ -d sd-webui ] || git clone https://github.com/lllyasviel/stable-diffusion-webui-forge sd-webui
mkdir -p sd-webui/models/Stable-diffusion
# نموذج أنمي عالي الجودة (SDXL). تقدر تحط أي نموذج .safetensors ثاني بنفس المجلد
[ -f sd-webui/models/Stable-diffusion/animagine-xl.safetensors ] || \
  curl -fL -o sd-webui/models/Stable-diffusion/animagine-xl.safetensors \
  https://huggingface.co/cagliostrolab/animagine-xl-3.1/resolve/main/animagine-xl-3.1.safetensors

grep -q '^AI_MODE=local' .env 2>/dev/null || { [ -f .env ] || cp .env.example .env; sed -i 's/^AI_MODE=.*/AI_MODE=local/' .env; }
echo
echo "تم ✓  شغّل الصور بأمر:   cd sd-webui && ./webui.sh --api --listen"
echo "وبعدين التطبيق بأمر:      npm start"
