"""Bulk-ingest an existing photo repository.

Expected layout (one directory per person, any number of photos each):

    repository/
      alice/
        img1.jpg
        img2.png
      bob/
        portrait.jpg

Usage:
    python -m scripts.ingest /path/to/repository [--force] [--limit-per-person N]

Rebuild the ANN index afterwards for a large import:
    REINDEX INDEX face_embedding_hnsw;
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

import cv2

from app.db import SessionLocal
from app.face_engine import get_engine
from app.service import enroll_face, get_or_create_person
from app.storage import get_store

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
logger = logging.getLogger("ingest")


def ingest(root: Path, *, force: bool, limit_per_person: int | None) -> dict[str, int]:
    engine = get_engine()
    get_store().ensure_bucket()
    stats = {"enrolled": 0, "no_face": 0, "low_quality": 0}

    with SessionLocal() as db:
        for person_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            images = sorted(p for p in person_dir.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES)
            if limit_per_person:
                images = images[:limit_per_person]
            if not images:
                continue

            person = get_or_create_person(db, person_dir.name, None)
            for path in images:
                image = cv2.imread(str(path))
                if image is None:
                    logger.warning("unreadable: %s", path)
                    continue
                face = engine.detect_primary(image)
                if face is None:
                    stats["no_face"] += 1
                    logger.warning("no face: %s", path)
                    continue
                if not face.quality.passed and not force:
                    stats["low_quality"] += 1
                    logger.warning("low quality %s: %s", path, face.quality.reasons)
                    continue
                enroll_face(
                    db,
                    person=person,
                    image_bytes=path.read_bytes(),
                    face=face,
                    content_type="image/jpeg",
                )
                stats["enrolled"] += 1
            logger.info("%s: %d/%d enrolled", person_dir.name, stats["enrolled"], len(images))
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--force", action="store_true", help="ignore quality gates")
    parser.add_argument("--limit-per-person", type=int, default=None)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    print(ingest(args.root, force=args.force, limit_per_person=args.limit_per_person))


if __name__ == "__main__":
    main()
