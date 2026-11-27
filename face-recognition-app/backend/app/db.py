from collections.abc import Iterator

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings

engine = create_engine(get_settings().database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def ensure_runtime_schema() -> None:
    if engine.dialect.name != "postgresql":
        return
    with engine.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE account "
                "ADD COLUMN IF NOT EXISTS contact_sharing_consented_at timestamptz"
            )
        )
        connection.execute(
            text("ALTER TABLE app_installation " "ADD COLUMN IF NOT EXISTS push_fid varchar(255)")
        )
        connection.execute(
            text(
                "ALTER TABLE app_installation "
                "ADD COLUMN IF NOT EXISTS push_enabled boolean NOT NULL DEFAULT false"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE app_installation "
                "ADD COLUMN IF NOT EXISTS push_fid_updated_at timestamptz"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS "
                "app_installation_push_fid_key "
                "ON app_installation (push_fid) "
                "WHERE push_fid IS NOT NULL"
            )
        )


def get_db() -> Iterator[Session]:
    with SessionLocal() as session:
        yield session
