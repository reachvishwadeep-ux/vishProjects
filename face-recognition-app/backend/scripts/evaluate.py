"""Threshold calibration and accuracy evaluation.

Computes the genuine/impostor score distributions on a labelled directory
(same layout as scripts/ingest.py) and reports the numbers you should quote
instead of "accuracy":

  * TAR@FAR       - true accept rate at a fixed false accept rate (verification)
  * EER           - equal error rate, and the threshold where it occurs
  * Rank-1        - closed-set identification accuracy (leave-one-out)
  * suggested MATCH_THRESHOLD / REVIEW_THRESHOLD for your data

Usage:
    python -m scripts.evaluate /path/to/repository --far 1e-3 --out report.json
"""

from __future__ import annotations

import argparse
import itertools
import json
import logging
import random
from pathlib import Path

import cv2
import numpy as np

from app.face_engine import get_engine

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
logger = logging.getLogger("evaluate")


def embed_directory(root: Path, limit_per_person: int | None = None) -> dict[str, np.ndarray]:
    """Return {person_name: (n_images, 512) embedding matrix}."""
    engine = get_engine()
    per_person: dict[str, list[np.ndarray]] = {}

    for person_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        paths = sorted(p for p in person_dir.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES)
        if limit_per_person:
            paths = paths[:limit_per_person]
        for path in paths:
            image = cv2.imread(str(path))
            if image is None:
                continue
            face = engine.detect_primary(image)
            if face is None:
                logger.warning("no face: %s", path)
                continue
            per_person.setdefault(person_dir.name, []).append(face.embedding)
        logger.info("%s: %d embeddings", person_dir.name, len(per_person.get(person_dir.name, [])))

    return {name: np.vstack(vectors) for name, vectors in per_person.items() if vectors}


def pair_scores(
    embeddings: dict[str, np.ndarray], max_impostor_pairs: int = 200_000, seed: int = 0
) -> tuple[np.ndarray, np.ndarray]:
    """Cosine similarity for all genuine pairs and a sample of impostor pairs."""
    rng = random.Random(seed)

    genuine = [
        float(vectors[i] @ vectors[j])
        for vectors in embeddings.values()
        for i, j in itertools.combinations(range(len(vectors)), 2)
    ]

    names = list(embeddings)
    impostor_pairs = [(a, b) for a, b in itertools.combinations(names, 2)]
    rng.shuffle(impostor_pairs)

    impostor: list[float] = []
    for name_a, name_b in impostor_pairs:
        va, vb = embeddings[name_a], embeddings[name_b]
        impostor.extend((va @ vb.T).ravel().tolist())
        if len(impostor) >= max_impostor_pairs:
            break

    return np.asarray(genuine), np.asarray(impostor[:max_impostor_pairs])


def tar_at_far(genuine: np.ndarray, impostor: np.ndarray, far: float) -> tuple[float, float]:
    """Threshold achieving the requested FAR, and the TAR there."""
    threshold = float(np.quantile(impostor, 1.0 - far))
    return threshold, float((genuine >= threshold).mean())


def equal_error_rate(genuine: np.ndarray, impostor: np.ndarray) -> tuple[float, float]:
    thresholds = np.unique(np.concatenate([genuine, impostor]))
    fars = np.array([(impostor >= t).mean() for t in thresholds])
    frrs = np.array([(genuine < t).mean() for t in thresholds])
    idx = int(np.argmin(np.abs(fars - frrs)))
    return float(thresholds[idx]), float((fars[idx] + frrs[idx]) / 2)


def rank1(embeddings: dict[str, np.ndarray]) -> float:
    """Leave-one-out closed-set identification accuracy."""
    names, gallery = [], []
    for name, vectors in embeddings.items():
        for vector in vectors:
            names.append(name)
            gallery.append(vector)
    if len(gallery) < 2:
        return float("nan")

    matrix = np.vstack(gallery)
    scores = matrix @ matrix.T
    np.fill_diagonal(scores, -np.inf)  # leave the probe itself out
    predicted = [names[int(i)] for i in scores.argmax(axis=1)]
    return float(np.mean([p == t for p, t in zip(predicted, names, strict=True)]))


def evaluate(root: Path, far: float, limit_per_person: int | None) -> dict[str, object]:
    embeddings = embed_directory(root, limit_per_person)
    if len(embeddings) < 2:
        raise SystemExit("need at least 2 people with detectable faces")

    genuine, impostor = pair_scores(embeddings)
    if genuine.size == 0:
        raise SystemExit("need at least 2 photos of at least one person for genuine pairs")

    threshold, tar = tar_at_far(genuine, impostor, far)
    eer_threshold, eer = equal_error_rate(genuine, impostor)

    return {
        "people": len(embeddings),
        "images": int(sum(len(v) for v in embeddings.values())),
        "genuine_pairs": int(genuine.size),
        "impostor_pairs": int(impostor.size),
        "genuine_score": {"mean": float(genuine.mean()), "min": float(genuine.min())},
        "impostor_score": {"mean": float(impostor.mean()), "max": float(impostor.max())},
        f"tar_at_far_{far:g}": tar,
        "eer": eer,
        "eer_threshold": eer_threshold,
        "rank1": rank1(embeddings),
        "suggested_match_threshold": round(threshold, 4),
        "suggested_review_threshold": round(min(threshold, eer_threshold) - 0.05, 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--far", type=float, default=1e-3)
    parser.add_argument("--limit-per-person", type=int, default=None)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    report = evaluate(args.root, args.far, args.limit_per_person)
    text = json.dumps(report, indent=2)
    print(text)
    if args.out:
        args.out.write_text(text)


if __name__ == "__main__":
    main()
