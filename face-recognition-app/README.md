# Face Recognition App

Cross-platform mobile app (Android + iOS) that identifies a person from an uploaded
photo by searching a stored photo repository. Fully open source, CPU-only, no paid
services.

```
Flutter app ──HTTPS──> FastAPI ──> InsightFace (SCRFD detect + ArcFace embed, ONNX Runtime)
                          │              │
                          │              └──> 512-d L2-normalised embedding
                          ├──> Postgres + pgvector   (vectors + metadata, HNSW ANN search)
                          └──> MinIO / any S3 API    (original images)
```

Recognition is **not** a per-person classifier: adding someone means storing one more
vector, so enrolment is instant and no retraining is ever needed.

| Layer | Choice | Licence |
|---|---|---|
| Detection + embedding | InsightFace `buffalo_l` (SCRFD + ArcFace r50) on ONNX Runtime | MIT (code) |
| API | FastAPI + SQLAlchemy 2 | MIT |
| Vector search | Postgres 16 + pgvector, HNSW over cosine distance | PostgreSQL / MIT |
| Image storage | MinIO (S3-compatible) | AGPL-3.0 |
| Mobile | Flutter 3 | BSD-3 |

> InsightFace *code* is MIT, but some pretrained weights are released for
> **non-commercial research use**. Fine for students/researchers — check before
> shipping commercially.

## Quick start

```bash
cd face-recognition-app
docker compose up -d          # db + minio + api; downloads ~280 MB of ONNX weights once
curl localhost:8000/health    # {"status":"ok","model_tag":"insightface/buffalo_l"}
open http://localhost:8000/docs
```

Enrol and search:

```bash
curl -F image=@alice1.jpg -F person_name=Alice localhost:8000/v1/enroll
curl -F image=@unknown.jpg -F top_k=3        localhost:8000/v1/search
```

Bulk-ingest an existing repository (`repository/<person_name>/*.jpg`):

```bash
docker compose exec api python -m scripts.ingest /data/repository
```

## API

| Endpoint | Purpose |
|---|---|
| `POST /v1/enroll` | Add a photo. Fields: `image`, `person_name`, `consent_ref?`, `force?`. Rejects low-quality photos unless `force=true`. |
| `POST /v1/search` | 1:N identification. Returns ranked matches with cosine scores and a `decision` of `match` / `review` / `no_match`. |
| `GET /v1/persons`, `GET /v1/persons/{id}` | Repository listing with presigned image URLs. |
| `DELETE /v1/persons/{id}` | Purge a person's vectors and images (GDPR / BIPA erasure). |
| `GET /health` | Liveness plus the active `model_tag`. |

## Thresholds — calibrate before you trust them

`MATCH_THRESHOLD` / `REVIEW_THRESHOLD` default to 0.42 / 0.32 cosine similarity.
Those are starting points, not answers: the right value depends on your images and
grows stricter as the gallery grows. Derive yours from labelled data:

```bash
docker compose exec api python -m scripts.evaluate /data/repository --far 1e-3
```

It reports TAR@FAR, EER, Rank-1 and suggested thresholds. Report **TAR@FAR** and
**Rank-1**, never bare "accuracy" — accuracy is meaningless on unbalanced pair sets.

Scores between the two thresholds return `decision="review"` so borderline hits go to
a human instead of being asserted as matches.

## Design notes

- **`model_tag` is stored on every embedding** and every query filters on it.
  Embeddings from different models are not comparable, so a model upgrade means
  re-embedding the gallery — this makes that migration safe instead of silently wrong.
- **Quality gates at enrolment** (face size, detector confidence, Laplacian blur
  variance, yaw) — one bad enrolment photo degrades every later search for that person.
- **Multiple photos per person** are encouraged; a person is scored by their best
  matching face, which handles pose and lighting variation.
- **`ON DELETE CASCADE`** plus object deletion makes erasure a single request.

## Before anyone relies on this

- **Anti-spoofing is not implemented.** A printed photo or a phone screen will
  defeat plain recognition. Any authentication/attendance use needs liveness
  detection (e.g. MiniFASNet / Silent-Face-Anti-Spoofing) plus active challenges.
- **Measure demographic bias** (RFW, FairFace) — open models have materially
  different error rates across skin tone, age and gender.
- **Face embeddings are biometric data**: GDPR Art. 9 (explicit consent, DPIA),
  Illinois BIPA, and the EU AI Act's limits on remote biometric identification all
  apply. Get ethics/IRB approval before collecting faces; store consent in
  `person.consent_ref`.
- Most public face datasets (VGGFace2, Glint360K, WebFace260M) are research-only
  with registration. Never scrape faces.
- `/v1/search` should be rate-limited in production to prevent gallery enumeration,
  and the API has no authentication yet — put it behind one.

## Development

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest
ruff check app scripts tests && ruff format --check app scripts tests
```

Point the mobile app at the API with `--dart-define=API_BASE_URL=...`; the Android
emulator reaches the host as `http://10.0.2.2:8000`. See [mobile/README.md](mobile/README.md).
