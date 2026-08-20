CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS person (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name text NOT NULL UNIQUE,
    consent_ref  text,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS face (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id  uuid NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    image_key  text NOT NULL,
    bbox       integer[] NOT NULL,
    det_score  real NOT NULL,
    quality    real,
    model_tag  text NOT NULL,
    embedding  vector(512) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS face_person_id_idx ON face (person_id);
CREATE INDEX IF NOT EXISTS face_model_tag_idx ON face (model_tag);

-- Approximate nearest neighbour over cosine distance. Embeddings are
-- L2-normalised, so 1 - cosine_distance is the cosine similarity score.
CREATE INDEX IF NOT EXISTS face_embedding_hnsw
    ON face USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE TABLE IF NOT EXISTS search_log (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    top_score         real,
    matched_person_id uuid,
    decision          text NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now()
);
