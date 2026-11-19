"""Downloads the real Argos en→ar model and translates. Needs internet (runs in Windows CI)."""
import os

import pytest

from rox_server.translate import Translator


@pytest.mark.skipif(os.environ.get("ROX_NET_TESTS") != "1", reason="needs internet (set ROX_NET_TESTS=1)")
def test_english_to_arabic():
    t = Translator("ar")
    out = t.translate("Follow me and stay quiet.", "en")
    print("translation:", out, t.status)
    assert out and any("\u0600" <= c <= "\u06ff" for c in out)
    assert t.translate("follow me and stay quiet.", "en") == out  # cached
