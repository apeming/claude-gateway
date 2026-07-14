#!/bin/sh
set -eu

WORKER_PROCESSES_VALUE="${WORKER_PROCESSES:-1}"

case "$WORKER_PROCESSES_VALUE" in
  auto)
    ;;
  ''|*[!0-9]*)
    echo "invalid WORKER_PROCESSES: $WORKER_PROCESSES_VALUE" >&2
    exit 1
    ;;
  *)
    ;;
esac

sed "s/__WORKER_PROCESSES__/$WORKER_PROCESSES_VALUE/" \
  /usr/local/openresty/nginx/conf/nginx.conf.template \
  > /usr/local/openresty/nginx/conf/nginx.conf

exec /usr/local/openresty/bin/openresty -g "daemon off;"
