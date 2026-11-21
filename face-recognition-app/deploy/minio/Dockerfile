FROM golang:1.23-alpine AS builder

ARG MINIO_VERSION

RUN apk add --no-cache bash git

WORKDIR /src
RUN git clone --depth 1 --branch "${MINIO_VERSION}" \
      https://github.com/minio/minio.git .
RUN CGO_ENABLED=0 go build \
      -tags kqueue \
      -trimpath \
      --ldflags "$(go run buildscripts/gen-ldflags.go)" \
      -o /out/minio .


FROM alpine:3.21

RUN apk add --no-cache ca-certificates curl su-exec \
    && addgroup -S minio \
    && adduser -S -G minio minio

COPY --from=builder /out/minio /usr/local/bin/minio
COPY deploy/minio/entrypoint.sh /usr/local/bin/minio-entrypoint
RUN chmod 0755 /usr/local/bin/minio-entrypoint

VOLUME ["/data"]
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/minio-entrypoint"]
CMD ["server", "/data"]
