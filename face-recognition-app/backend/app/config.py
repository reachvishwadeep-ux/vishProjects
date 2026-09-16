from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://facerec:facerec@localhost:5432/facerec"

    s3_endpoint_url: str = "http://localhost:9000"
    s3_public_endpoint_url: str | None = None
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_bucket: str = "faces"
    s3_region: str = "us-east-1"
    presign_ttl_seconds: int = 3600

    insightface_model: str = "buffalo_l"
    insightface_root: str = "/models"
    det_size: int = 640

    # Matching thresholds on cosine similarity of L2-normalised ArcFace embeddings.
    # Calibrate on your own data with scripts/evaluate.py before trusting these.
    match_threshold: float = 0.42
    review_threshold: float = 0.32

    # Enrolment quality gates.
    min_face_pixels: int = 112
    min_det_score: float = 0.70
    min_blur_variance: float = 30.0
    max_abs_yaw_degrees: float = 40.0


@lru_cache
def get_settings() -> Settings:
    return Settings()
