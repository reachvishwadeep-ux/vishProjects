import numpy as np

from app.face_engine import assess_quality


def _sharp_image(size: int) -> np.ndarray:
    rng = np.random.default_rng(0)
    return rng.integers(0, 255, size=(size, size, 3), dtype=np.uint8)


def test_good_face_passes():
    report = assess_quality(_sharp_image(400), (0, 0, 400, 400), det_score=0.95, yaw_degrees=5.0)
    assert report.passed
    assert report.score > 0.5


def test_small_face_is_rejected():
    report = assess_quality(_sharp_image(64), (0, 0, 64, 64), det_score=0.95, yaw_degrees=0.0)
    assert not report.passed
    assert any("too small" in reason for reason in report.reasons)


def test_blurry_face_is_rejected():
    flat = np.full((400, 400, 3), 128, dtype=np.uint8)
    report = assess_quality(flat, (0, 0, 400, 400), det_score=0.95, yaw_degrees=0.0)
    assert not report.passed
    assert any("blurry" in reason for reason in report.reasons)


def test_extreme_pose_is_rejected():
    report = assess_quality(_sharp_image(400), (0, 0, 400, 400), det_score=0.95, yaw_degrees=70.0)
    assert not report.passed
    assert any("pose" in reason for reason in report.reasons)
