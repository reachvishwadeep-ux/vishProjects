# MatchSnap cloud deployment

The cloud stack runs FastAPI, PostgreSQL/pgvector, MinIO, and Caddy on one
Docker host. Only HTTP/HTTPS are published; PostgreSQL, MinIO, and FastAPI stay
on the private Compose network.

The pinned MinIO community release is built from its tagged source because its
historical pre-built container is no longer reliably available from a public
registry.

## Configure

1. Copy `.env.cloud.example` to `.env.cloud`.
2. Set unique generated values for every password or secret.
3. Set `API_DOMAIN` and `MEDIA_DOMAIN` to DNS names that resolve to the host.
4. Set the Telnyx Verify credentials without committing `.env.cloud`.

## Start

```bash
docker compose --env-file .env.cloud -f docker-compose.cloud.yml config --quiet
docker compose --env-file .env.cloud -f docker-compose.cloud.yml up -d --build
docker compose --env-file .env.cloud -f docker-compose.cloud.yml ps
curl --fail "https://${API_DOMAIN}/health"
```

Caddy obtains and renews public TLS certificates automatically. The API creates
short-lived, signed MinIO URLs using `https://${MEDIA_DOMAIN}`.

## Maintenance

```bash
docker compose --env-file .env.cloud -f docker-compose.cloud.yml logs --tail=200
docker compose --env-file .env.cloud -f docker-compose.cloud.yml pull
docker compose --env-file .env.cloud -f docker-compose.cloud.yml up -d --build
docker compose --env-file .env.cloud -f docker-compose.cloud.yml exec api \
  python -m scripts.prune_audit
```
