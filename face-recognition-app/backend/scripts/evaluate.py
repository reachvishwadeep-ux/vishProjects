"""Threshold calibration and accuracy evaluation.

Computes the genuine/impostor score distributions on a labelled directory
(same layout as scripts/ingest.py) and reports the numbers you should quote
instead of "accuracy":

  * TAR@FAR       - true accept rate at a fixed false accept rate (verification)
  * EER           - equal error rate, and the threshold where it occurs
  * Rank-1        - closed-set identification accuracy (leave-one-out)
  * TPIR@FPIR     - open-set identification rates, which is what /v1/search does
  * suggested MATCH_THRESHOLD / REVIEW_THRESHOLD for your data

The suggested thresholds come from the open-set numbers, not from TAR@FAR: a
search compares the probe against the whole gallery, so a per-pair FAR of 1e-3
against 1000 stored faces means a false accept on roughly every second search.

Usage:
    python -m scripts.evaluate /path/to/repository --fpir 0.01 --out report.json
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


def open_set_scores(
    embeddings: dict[str, np.ndarray],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Per-probe top gallery scores, leave-one-out.

    This mirrors what /v1/search returns: one score per probe, the best over the
    gallery. Returns ``(genuine_top, rival_top, impostor_top)`` where the first
    two are aligned per probe (probes whose person has another image enrolled)
    and ``impostor_top`` covers every probe -- it is the score a stranger would
    get, so the threshold has to sit above it.
    """
    names, gallery = [], []
    for name, vectors in embeddings.items():
        for vector in vectors:
            names.append(name)
            gallery.append(vector)

    labels = np.asarray(names)
    scores = np.vstack(gallery) @ np.vstack(gallery).T
    np.fill_diagonal(scores, -np.inf)  # never match a probe against itself

    genuine_top, rival_top, impostor_top = [], [], []
    for i, name in enumerate(names):
        other_person = labels != name
        same = (labels == name) & (np.arange(len(names)) != i)
        best_impostor = float(scores[i][other_person].max())
        impostor_top.append(best_impostor)
        if same.any():
            genuine_top.append(float(scores[i][same].max()))
            rival_top.append(best_impostor)

    return np.asarray(genuine_top), np.asarray(rival_top), np.asarray(impostor_top)


def identification_rates(
    embeddings: dict[str, np.ndarray], fpir: float
) -> tuple[float, float, float]:
    """Threshold hitting the target false-positive identification rate, plus TPIR.

    TPIR counts a probe as correct only when the top match is the right person
    *and* clears the threshold, which is the decision the API actually makes.
    """
    genuine_top, rival_top, impostor_top = open_set_scores(embeddings)
    threshold = float(np.quantile(impostor_top, 1.0 - fpir))
    correct = (genuine_top >= threshold) & (genuine_top >= rival_top)
    tpir = float(correct.mean()) if genuine_top.size else float("nan")
    return threshold, tpir, float(impostor_top.max())


def evaluate(
    root: Path, far: float, fpir: float, limit_per_person: int | None
) -> dict[str, object]:
    embeddings = embed_directory(root, limit_per_person)
    if len(embeddings) < 2:
        raise SystemExit("need at least 2 people with detectable faces")

    genuine, impostor = pair_scores(embeddings)
    if genuine.size == 0:
        raise SystemExit("need at least 2 photos of at least one person for genuine pairs")

    threshold, tar = tar_at_far(genuine, impostor, far)
    eer_threshold, eer = equal_error_rate(genuine, impostor)
    match_threshold, tpir, worst_impostor = identification_rates(embeddings, fpir)

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
        f"tpir_at_fpir_{fpir:g}": tpir,
        "worst_impostor_top_score": worst_impostor,
        "suggested_match_threshold": round(match_threshold, 4),
        "suggested_review_threshold": round(max(match_threshold - 0.1, 0.0), 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--far", type=float, default=1e-3, help="verification FAR for TAR@FAR")
    parser.add_argument(
        "--fpir",
        type=float,
        default=0.01,
        help="target false-positive identification rate; sets the suggested thresholds",
    )
    parser.add_argument("--limit-per-person", type=int, default=None)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    report = evaluate(args.root, args.far, args.fpir, args.limit_per_person)
    text = json.dumps(report, indent=2)
    print(text)
    if args.out:
        args.out.write_text(text)


if __name__ == "__main__":
    main()
