#!/bin/sh
set -eu

chown -R minio:minio /data
exec su-exec minio /usr/local/bin/minio "$@"
