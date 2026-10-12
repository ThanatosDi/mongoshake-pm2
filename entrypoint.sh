#!/usr/bin/env bash
set -euo pipefail

TPL_DIR=${SHAKE_TPL_DIR:-/opt/mongoshake/conf.tpl}
CONF_DIR=${SHAKE_CONF_DIR:-/opt/mongoshake/conf}
ECOSYSTEM=/opt/mongoshake/pm2/ecosystem.config.js
mkdir -p "$CONF_DIR" /opt/mongoshake/logs

if [ ! -f "$ECOSYSTEM" ]; then
  echo "[entrypoint] 找不到 $ECOSYSTEM，請掛載含 ecosystem.config.js 的目錄到 /opt/mongoshake/pm2" >&2
  exit 1
fi

# 只替換「目前有定義」的環境變數；未定義的 $xxx 原樣保留，避免 conf 內字面值被吃掉
VARS=$(env | cut -d= -f1 | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' | sed 's/^/$/' | tr '\n' ' ')

shopt -s nullglob
tpls=("$TPL_DIR"/*.conf)
if [ ${#tpls[@]} -eq 0 ]; then
  echo "[entrypoint] $TPL_DIR 沒有任何 *.conf，請掛載 conf 模板" >&2
  exit 1
fi

rm -f "$CONF_DIR"/*.conf
for tpl in "${tpls[@]}"; do
  name=$(basename "$tpl")
  envsubst "$VARS" < "$tpl" > "$CONF_DIR/$name"
  echo "[entrypoint] rendered $CONF_DIR/$name"
done

exec "$@"
