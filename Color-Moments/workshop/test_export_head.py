import json

import numpy as np

import export_head


def test_round_trip(tmp_path):
    W = np.random.rand(3, 4).astype(np.float32)
    export_head.write(tmp_path, ids=["a", "b", "c"], W=W, bias=np.zeros(3), mean=np.zeros(4), std=np.ones(4), words_version=6)
    meta = json.load(open(tmp_path / "WordHead.json"))
    back = np.fromfile(tmp_path / "WordHead.bin", dtype="<f2").reshape(3, 4)
    assert meta["ids"] == ["a", "b", "c"] and meta["dim"] == 4 and meta["wordsVersion"] == 6
    assert np.allclose(back, W, atol=1e-3)
    assert "test" not in meta


def test_test_flag(tmp_path):
    W = np.zeros((1, 2), dtype=np.float32)
    export_head.write(tmp_path, ids=["a"], W=W, bias=np.zeros(1), mean=np.zeros(2), std=np.ones(2), words_version=6, test=True)
    assert json.load(open(tmp_path / "WordHead.json"))["test"] is True
