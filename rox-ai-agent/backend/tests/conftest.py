import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def tmp_data(tmp_path, monkeypatch):
    monkeypatch.setenv("ROX_DATA_DIR", str(tmp_path / "data"))
    import keyring
    from keyrings.alt.file import PlaintextKeyring  # test-only backend
    kr = PlaintextKeyring(); kr.file_path = str(tmp_path / "kr.cfg"); keyring.set_keyring(kr)
    from rox.storage import db
    db.reset_for_tests()
    from rox.security.policy import STOP
    STOP.clear()
    yield tmp_path
    db.reset_for_tests()
