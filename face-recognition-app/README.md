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

Request and verify a development phone OTP first. The local response includes the code
so the demo does not need a paid SMS provider:

```bash
curl -X POST localhost:8000/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone_number":"+919876543210"}'

curl -X POST localhost:8000/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"phone_number":"+919876543210","challenge_id":"<challenge-id>","code":"<development-code>"}'
```

Create missing/found cases. Each upload searches only the opposite repository, and
reviewable candidates are retained for later retrieval:

```bash
curl -H "Authorization: Bearer <access-token>" \
  -F image=@missing.jpg -F case_type=missing localhost:8000/v1/cases
curl -H "Authorization: Bearer <access-token>" \
  -F image=@found.jpg -F case_type=found localhost:8000/v1/cases
curl -H "Authorization: Bearer <access-token>" \
  localhost:8000/v1/cases/<case-id>/matches
```

Matching runs immediately for every upload. A restart-safe reconciliation sweep also
runs every 15 minutes: it processes only case faces added since its durable watermark,
searches their opposite repository, and updates candidate links for both the new and
previously uploaded cases. Existing candidate rows are updated idempotently rather than
duplicated. Configure it with `RECONCILIATION_ENABLED`,
`RECONCILIATION_INTERVAL_SECONDS`, `RECONCILIATION_BATCH_SIZE`, and
`RECONCILIATION_TOP_K`.

When a high-scoring missing/found pair belongs to two different accounts, the API
creates a private in-app connection notification. Both accounts must consent before
the server derives distinct six-digit meeting codes. Codes expire after 15 minutes,
are never stored in plaintext, and are revoked if either party withdraws consent.
Phone numbers and precise locations are not included in connection responses.

Bulk-ingest an existing repository (`repository/<person_name>/*.jpg`):

```bash
docker compose exec api python -m scripts.ingest /data/repository
```

## API

| Endpoint | Purpose |
|---|---|
| `POST /v1/auth/otp/request` | Request a six-digit phone OTP. Local development returns `development_code`; production requires an SMS adapter. |
| `POST /v1/auth/otp/verify` | Verify an OTP and receive a 15-minute access token plus rotating refresh token. |
| `POST /v1/auth/refresh` | Rotate the refresh token and issue a new access token. |
| `POST /v1/auth/logout` | Revoke the current authenticated session. |
| `GET /v1/auth/me` | Return the authenticated phone account. |
| `POST /v1/enroll` | Add a photo. Fields: `image`, `person_name`, `consent_ref?`, `force?`. Rejects low-quality photos unless `force=true`. |
| `POST /v1/search` | 1:N identification. Returns ranked matches with cosine scores and a `decision` of `match` / `review` / `no_match`. |
| `POST /v1/cases` | Store a `missing` or `found` case and search only the opposite repository. |
| `GET /v1/cases/{id}/matches` | Retrieve persisted possible matches for an owned case. |
| `DELETE /v1/cases/{id}` | Delete an owned case, its embedding, stored photo, and candidate links. |
| `GET /v1/connections` | List the authenticated account's private match notifications and consent state. |
| `POST /v1/connections/{id}/consent` | Consent to the connection; meeting codes activate after mutual consent. |
| `POST /v1/connections/{id}/withdraw-consent` | Withdraw consent and immediately revoke active meeting codes. |
| `POST /v1/connections/{id}/meeting-code/verify` | Verify the other participant's short-lived code once. |
| `POST /v1/connections/{id}/meeting-code/renew` | Rotate expired or used meeting codes after mutual consent. |
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
- Recognition routes require a phone-authenticated bearer session. Development OTPs
  are returned only when `OTP_DELIVERY_MODE=development`; never use that mode on a
  public server. Add an SMS provider, HTTPS, upload rate limits, and stricter
  role/case authorization before production.
- Face similarity and a successful meeting-code exchange do not prove identity,
  guardianship, custody, intent, or a safe child handoff. They must never
  automatically authorize a child transfer.

## Development

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest
ruff check app scripts tests && ruff format --check app scripts tests
```

Run the MatchSnap Flutter app from `poc_app` and point it at the API with
`--dart-define=API_BASE_URL=...`; the Android emulator reaches the host as
`http://10.0.2.2:8000`.

Set `S3_PUBLIC_ENDPOINT_URL` to the object-storage URL reachable by the phone. Docker
Compose defaults it to `http://10.0.2.2:9000` for the Android emulator. Use HTTPS URLs
for both the API and object storage outside local development.
