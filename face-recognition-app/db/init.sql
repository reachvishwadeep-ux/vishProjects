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

CREATE TABLE IF NOT EXISTS case_record (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_type     text NOT NULL CHECK (case_type IN ('missing', 'found')),
    subject_label text NOT NULL,
    status        text NOT NULL DEFAULT 'active',
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS case_face (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id    uuid NOT NULL REFERENCES case_record(id) ON DELETE CASCADE,
    case_type  text NOT NULL CHECK (case_type IN ('missing', 'found')),
    image_key  text NOT NULL,
    bbox       integer[] NOT NULL,
    det_score  real NOT NULL,
    quality    real,
    model_tag  text NOT NULL,
    embedding  vector(512) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS case_record_type_status_idx
    ON case_record (case_type, status);
CREATE INDEX IF NOT EXISTS case_face_case_id_idx ON case_face (case_id);
CREATE INDEX IF NOT EXISTS case_face_model_tag_idx ON case_face (model_tag);
CREATE INDEX IF NOT EXISTS case_face_missing_hnsw
    ON case_face USING hnsw (embedding vector_cosine_ops)
    WHERE case_type = 'missing';
CREATE INDEX IF NOT EXISTS case_face_found_hnsw
    ON case_face USING hnsw (embedding vector_cosine_ops)
    WHERE case_type = 'found';

CREATE TABLE IF NOT EXISTS case_match (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    missing_case_id  uuid NOT NULL REFERENCES case_record(id) ON DELETE CASCADE,
    found_case_id    uuid NOT NULL REFERENCES case_record(id) ON DELETE CASCADE,
    missing_face_id  uuid NOT NULL REFERENCES case_face(id) ON DELETE CASCADE,
    found_face_id    uuid NOT NULL REFERENCES case_face(id) ON DELETE CASCADE,
    score            real NOT NULL,
    decision         text NOT NULL,
    model_tag        text NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT case_match_pair_model_key
        UNIQUE (missing_case_id, found_case_id, model_tag)
);

CREATE INDEX IF NOT EXISTS case_match_missing_idx ON case_match (missing_case_id);
CREATE INDEX IF NOT EXISTS case_match_found_idx ON case_match (found_case_id);
