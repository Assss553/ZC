"""Offline translation on the PC with Argos Translate models (MIT/CC0) run by CTranslate2.
Models are downloaded once from the official Argos package index, then everything is offline.
Non-English sources pivot through English (ja→en→ar) because that is how Argos models are published."""
import json
import logging
import os
import threading
import urllib.request
import zipfile
from pathlib import Path

from .textlogic import TranslationCache

log = logging.getLogger("rox.translate")
INDEX_URL = "https://raw.githubusercontent.com/argosopentech/argospm-index/main/index.json"
# Honest client identification (the server rejects the anonymous default "Python-urllib" agent)
UA = {"User-Agent": "ROX-Server/1.0 (Argos Translate model client)"}


def _download(url, dest=None, timeout=120):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        if dest is None:
            return r.read()
        with open(dest, "wb") as f:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)


def models_dir() -> Path:
    base = Path(os.environ.get("ROX_DATA", Path.home() / ".rox-server"))
    p = base / "models"
    p.mkdir(parents=True, exist_ok=True)
    return p


class ArgosModel:
    def __init__(self, path: Path, device: str):
        import ctranslate2
        import sentencepiece as spm

        root = path
        # package zip contains a single top-level folder
        subs = [d for d in path.iterdir() if d.is_dir()]
        if not (path / "model").exists() and len(subs) == 1:
            root = subs[0]
        self.translator = ctranslate2.Translator(str(root / "model"), device=device, compute_type="auto")
        sp = root / "sentencepiece.model"
        self.sp = spm.SentencePieceProcessor(model_file=str(sp))

    def translate(self, texts):
        toks = [self.sp.encode(t, out_type=str) for t in texts]
        res = self.translator.translate_batch(toks, beam_size=2, max_decoding_length=256)
        return [self.sp.decode(r.hypotheses[0]).replace("▁", " ").strip() for r in res]


class Translator:
    def __init__(self, target="ar", device=None):
        self.target = target
        self.cache = TranslationCache()
        self._models = {}
        self._lock = threading.Lock()
        self._index = None
        self.status = {}
        self.device = device or self._best_device()

    @staticmethod
    def _best_device():
        try:
            import ctranslate2
            if ctranslate2.get_cuda_device_count() > 0:
                return "cuda"  # NVIDIA GPU
        except Exception:
            pass
        return "cpu"

    def _load_index(self):
        if self._index is None:
            cache = models_dir() / "index.json"
            try:
                data = _download(INDEX_URL, timeout=20)
                cache.write_bytes(data)
            except Exception as e:
                log.warning("index download failed (%s), using cached index", e)
                data = cache.read_bytes()
            self._index = json.loads(data)
        return self._index

    def _model(self, src, dst):
        key = f"{src}_{dst}"
        with self._lock:
            if key in self._models:
                return self._models[key]
            path = models_dir() / key
            if not path.exists():
                pkg = next((p for p in self._load_index() if p["from_code"] == src and p["to_code"] == dst), None)
                if pkg is None:
                    self.status[key] = "unsupported"
                    self._models[key] = None
                    return None
                url = next(l for l in pkg["links"] if l.startswith("http"))
                self.status[key] = "downloading"
                log.info("Downloading model %s from %s", key, url)
                tmp = models_dir() / f"{key}.zip"
                _download(url, tmp)
                with zipfile.ZipFile(tmp) as z:
                    z.extractall(path)
                tmp.unlink()
            m = ArgosModel(path, self.device)
            self._models[key] = m
            self.status[key] = f"ready ({self.device})"
            return m

    def prepare(self, src):
        for a, b in self._chain(src):
            self._model(a, b)

    def _chain(self, src):
        if src == self.target:
            return []
        if src == "en" or self.target == "en":
            return [(src, self.target)]
        return [(src, "en"), ("en", self.target)]

    def translate(self, text, src):
        if src in ("und", "", self.target):
            return text if src == self.target else None
        hit = self.cache.get(text)
        if hit is not None:
            return hit
        cur = [text]
        try:
            for a, b in self._chain(src):
                m = self._model(a, b)
                if m is None:
                    return None
                cur = m.translate(cur)
        except Exception as e:
            log.error("translation failed: %s", e)
            self.status[f"{src}_{self.target}"] = f"error: {e}"
            return None
        self.cache.put(text, cur[0])
        return cur[0]
