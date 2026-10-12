# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# MongoShake + pm2，多架構（linux/amd64、linux/arm64）。
#
# - builder 固定跑在 BUILDPLATFORM（本機原生架構），用 Go cross-compile 產出
#   TARGETARCH 的 binary，不走 QEMU 模擬，速度快也不會踩 netpoll SIGSEGV。
# - runtime 用 node slim（官方本身就是 multi-arch），裝 pm2 管多個 collector。
#
# 建置：./build.sh（見該檔說明）
# ---------------------------------------------------------------------------
ARG MONGOSHAKE_TAG=release-v2.8.8-20260428
ARG GO_VERSION=1.27
# builder base：alpine / bookworm 皆可（CGO_ENABLED=0 靜態 binary，不依賴 libc）
ARG GO_VARIANT=alpine
ARG NODE_VERSION=24

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-${GO_VARIANT} AS builder
ARG MONGOSHAKE_TAG
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src

RUN wget -qO /tmp/src.tgz \
      "https://github.com/alibaba/MongoShake/archive/refs/tags/${MONGOSHAKE_TAG}.tar.gz" \
 && tar -xzf /tmp/src.tgz --strip-components=1 -C /src \
 && rm /tmp/src.tgz

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# 不用官方 build.sh —— 它固定 GOARCH=amd64 且會編 darwin/windows。
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
    go build -trimpath \
      -ldflags "-s -w \
                -X github.com/alibaba/MongoShake/v2/common.BRANCH=${MONGOSHAKE_TAG},release \
                -X github.com/alibaba/MongoShake/v2/common.SIGNALPROFILE=31 \
                -X github.com/alibaba/MongoShake/v2/common.SIGNALSTACK=30" \
      -o /out/collector ./cmd/collector \
 && cp /src/conf/collector.conf /out/collector.conf.default

# 只匯出 binary：docker buildx build --target artifact --output type=local,dest=./dist .
FROM scratch AS artifact
COPY --from=builder /out/ /

# ---------------------------------------------------------------------------
FROM node:${NODE_VERSION}-bookworm-slim
ARG MONGOSHAKE_TAG
ARG PM2_VERSION=5

LABEL org.opencontainers.image.title="mongoshake-pm2" \
      org.opencontainers.image.source="https://github.com/alibaba/MongoShake" \
      org.opencontainers.image.version="${MONGOSHAKE_TAG}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates gettext-base \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g "pm2@${PM2_VERSION}" \
 && npm cache clean --force \
 && pm2 install pm2-logrotate \
 && pm2 set pm2-logrotate:max_size 100M \
 && pm2 set pm2-logrotate:retain 7 \
 && pm2 set pm2-logrotate:compress true \
 && pm2 kill

WORKDIR /opt/mongoshake
COPY --from=builder /out/collector /opt/mongoshake/collector
COPY --from=builder /out/collector.conf.default /opt/mongoshake/collector.conf.default
COPY ecosystem.config.js /opt/mongoshake/ecosystem.config.js
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/mongoshake/collector \
 && mkdir -p /opt/mongoshake/conf.tpl /opt/mongoshake/conf /opt/mongoshake/logs

# conf.tpl：放 *.conf 模板，一個檔 = 一個 collector process
# logs    ：pm2 與 collector 的 log
VOLUME ["/opt/mongoshake/conf.tpl", "/opt/mongoshake/logs"]

# 不 EXPOSE：port 由 conf.tpl 的 incr_sync / full_sync / prom http_port 決定，
# 對外由 docker compose 的 ports 設定。

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["pm2-runtime", "start", "/opt/mongoshake/ecosystem.config.js"]
