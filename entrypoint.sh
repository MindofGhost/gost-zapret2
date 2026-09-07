#!/usr/bin/env sh

set -euo pipefail

missing=""
for var in GOST_COMMAND; do
  eval "value=\${$var:-}"
  [ -n "$value" ] || missing="$missing $var"
done

if [ -n "$missing" ]; then
  echo "[entrypoint] ERROR: required environment variables are not set:$missing" >&2
  exit 1
fi

sync_defaults() {
  src_dir=$1
  dst_dir=$2
  label=$3

  [ -d "$src_dir" ] && [ -d "$dst_dir" ] || return 0

  for src in "$src_dir"/*; do
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    dst="$dst_dir/$name"
    [ -e "$dst" ] && continue
    echo "[entrypoint] Copying $label: $name"
    cp -a "$src" "$dst"
  done
}

sync_defaults "/opt/zapret2/lua.dist" "/opt/zapret2/lua" "lua script"
sync_defaults "/opt/zapret2/init.d/custom.d.examples.linux.dist" "/opt/zapret2/init.d/custom.d.examples.linux" "custom.d script"
sync_defaults "/opt/zapret2/files/fake.dist" "/opt/zapret2/files/fake" "fake file"

/opt/zapret2/init.d/sysv/zapret2 start

cleanup() {
  /opt/zapret2/init.d/sysv/zapret2 stop || true
  [ -n "${GOST_PID:-}" ] && kill "${GOST_PID}" 2>/dev/null || true
}

trap cleanup EXIT TERM INT

GOST_VERBOSE_FLAG=""
if [ "${GOST_VERBOSE:-0}" = "1" ]; then
  GOST_VERBOSE_FLAG="-D"
fi

/bin/gost ${GOST_VERBOSE_FLAG} ${GOST_COMMAND} &
GOST_PID=$!

wait
