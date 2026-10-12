#!/usr/bin/env bash
# 建置 linux/amd64 + linux/arm64 的 MongoShake + pm2 image。
#
# 用法：
#   ./build.sh                         # 兩架構都建，load 進本機（需 containerd image store）
#   PUSH=1 IMAGE=registry/x/mongoshake ./build.sh   # 兩架構建完直接 push 成 manifest list
#   PLATFORMS=linux/arm64 ./build.sh   # 只建單一架構
#
# 環境變數：
#   IMAGE           image 名稱，預設 mongoshake-pm2
#   TAG             image tag，預設 2.8.8
#   MONGOSHAKE_TAG  MongoShake git tag，預設 release-v2.8.8-20260428
#   PLATFORMS       預設 linux/amd64,linux/arm64
#   PUSH            1 = push 到 registry；否則 --load
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=${IMAGE:-mongoshake-pm2}
TAG=${TAG:-2.8.8}
MONGOSHAKE_TAG=${MONGOSHAKE_TAG:-release-v2.8.8-20260428}
PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}

if [ "${PUSH:-0}" = "1" ]; then
  output=--push
else
  output=--load
fi

docker buildx build \
  --platform "$PLATFORMS" \
  --build-arg MONGOSHAKE_TAG="$MONGOSHAKE_TAG" \
  -t "$IMAGE:$TAG" \
  "$output" \
  .
