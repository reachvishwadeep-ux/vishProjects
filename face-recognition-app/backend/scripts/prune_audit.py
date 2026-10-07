"""Apply configured MatchSnap audit retention limits."""

from app.audit_service import apply_audit_retention
from app.db import SessionLocal


def main() -> None:
    with SessionLocal() as db:
        print(apply_audit_retention(db))


if __name__ == "__main__":
    main()
