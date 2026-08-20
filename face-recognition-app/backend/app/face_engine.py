"""Detection, alignment and embedding.

Wraps InsightFace (SCRFD detector + ArcFace recogniser) running on ONNX Runtime.
Both models come from the ``buffalo_l`` bundle and run comfortably on CPU.

The embedding is 512-d and L2-normalised, so cosine similarity is a plain dot
product and ``1 - cosine_distance`` is the similarity score used everywhere else.
"""

from __future__ import annotations

import math
import threading
from dataclasses import dataclass
from functools import lru_cache

import cv2
import numpy as np
from insightface.app import FaceAnalysis

from app.config import get_settings
from app.schemas import QualityReport


@dataclass(frozen=True)
class DetectedFace:
    embedding: np.ndarray
    bbox: tuple[int, int, int, int]
    det_score: float
    quality: QualityReport


class FaceEngine:
    def __init__(self) -> None:
        settings = get_settings()
        self.model_name = settings.insightface_model
        self._lock = threading.Lock()
        self._app = FaceAnalysis(
            name=self.model_name,
            root=settings.insightface_root,
            providers=["CPUExecutionProvider"],
        )
        self._app.prepare(ctx_id=-1, det_size=(settings.det_size, settings.det_size))

    @property
    def model_tag(self) -> str:
        return f"insightface/{self.model_name}"

    def detect_all(self, image_bgr: np.ndarray) -> list[DetectedFace]:
        # ONNX Runtime sessions are not guaranteed thread-safe for concurrent
        # Run() calls on the same session, and FastAPI serves sync endpoints from
        # a threadpool, so serialise inference.
        with self._lock:
            faces = self._app.get(image_bgr)
        return [self._to_detected(image_bgr, face) for face in faces]

    def detect_primary(self, image_bgr: np.ndarray) -> DetectedFace | None:
        """Return the largest face, which is the subject in an uploaded portrait."""
        faces = self.detect_all(image_bgr)
        if not faces:
            return None
        return max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))

    def _to_detected(self, image_bgr: np.ndarray, face) -> DetectedFace:
        x1, y1, x2, y2 = (int(v) for v in face.bbox)
        bbox = (max(x1, 0), max(y1, 0), max(x2, 0), max(y2, 0))
        embedding = np.asarray(face.normed_embedding, dtype=np.float32)
        return DetectedFace(
            embedding=embedding,
            bbox=bbox,
            det_score=float(face.det_score),
            quality=assess_quality(image_bgr, bbox, float(face.det_score), _yaw_of(face)),
        )


def _yaw_of(face) -> float:
    pose = getattr(face, "pose", None)
    if pose is None:
        return 0.0
    return float(pose[1])


def assess_quality(
    image_bgr: np.ndarray,
    bbox: tuple[int, int, int, int],
    det_score: float,
    yaw_degrees: float,
) -> QualityReport:
    settings = get_settings()
    x1, y1, x2, y2 = bbox
    crop = image_bgr[y1:y2, x1:x2]
    face_pixels = min(x2 - x1, y2 - y1)

    if crop.size == 0:
        blur_variance = 0.0
    else:
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        blur_variance = float(cv2.Laplacian(gray, cv2.CV_64F).var())

    reasons: list[str] = []
    if face_pixels < settings.min_face_pixels:
        reasons.append(f"face too small ({face_pixels}px < {settings.min_face_pixels}px)")
    if det_score < settings.min_det_score:
        reasons.append(f"low detector confidence ({det_score:.2f} < {settings.min_det_score})")
    if blur_variance < settings.min_blur_variance:
        reasons.append(
            f"image too blurry (variance {blur_variance:.1f} < {settings.min_blur_variance})"
        )
    if abs(yaw_degrees) > settings.max_abs_yaw_degrees:
        reasons.append(f"extreme pose (yaw {yaw_degrees:.0f} deg)")

    # A single 0-1 summary, useful for ranking several enrolment photos.
    score = min(
        1.0,
        0.4 * min(face_pixels / (2 * settings.min_face_pixels), 1.0)
        + 0.3 * det_score
        + 0.2 * min(blur_variance / (4 * settings.min_blur_variance), 1.0)
        + 0.1 * max(0.0, math.cos(math.radians(yaw_degrees))),
    )

    return QualityReport(
        face_pixels=face_pixels,
        det_score=det_score,
        blur_variance=blur_variance,
        yaw_degrees=yaw_degrees,
        score=score,
        passed=not reasons,
        reasons=reasons,
    )


@lru_cache
def get_engine() -> FaceEngine:
    return FaceEngine()
