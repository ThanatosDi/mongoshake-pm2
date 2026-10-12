# mongoshake-pm2

[繁體中文](README.md) | English

Multi-arch container image (`linux/amd64`, `linux/arm64`) of the [MongoShake](https://github.com/alibaba/MongoShake) collector + [pm2](https://pm2.keymetrics.io/).
pm2 runs multiple collector processes inside a single container, one process per conf file.

Official releases ship only an x86-64 binary, which crashes with SIGSEGV under emulation on arm64, so this image builds MongoShake from source with Go cross-compilation.

## Usage

```yaml
services:
  mongoshake:
    image: ghcr.io/<owner>/mongoshake-pm2:2.8.8
    env_file: .env                                  # values for ${VAR} in conf templates
    volumes:
      - ./pm2:/opt/mongoshake/pm2:ro                # ecosystem.config.js
      - ./conf.tpl:/opt/mongoshake/conf.tpl:ro      # *.conf templates
      - ./logs:/opt/mongoshake/logs
    ports:
      - "9100:9100"                                 # match http_port in your conf
```

```bash
cp ecosystem.config.js.example pm2/ecosystem.config.js   # adjust apps to your conf files
docker compose up -d
docker compose exec mongoshake pm2 ls
```

- The image does not ship an `ecosystem.config.js`. You must mount one at `/opt/mongoshake/pm2/`, otherwise the container exits on startup. This file decides which collectors run and their pm2 options; see `ecosystem.config.js.example`.
- In `ecosystem.config.js`, point each collector's `-conf` to `/opt/mongoshake/conf/<file>` (the rendered file), not `conf.tpl/`.
- On startup, `entrypoint.sh` substitutes `${VAR}` in `conf.tpl/*.conf` with environment variables and writes the result to `/opt/mongoshake/conf/`. Undefined variables are left as-is.
- When running multiple instances, `id`, `checkpoint.storage.db`, `incr_sync.http_port` / `full_sync.http_port` / `prom.http_port`, and `log.file` must all be unique.
- The image declares no `EXPOSE`. Publish the ports you need (e.g. `prom.http_port`) with `ports` in docker compose, matching your conf.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `SHAKE_TPL_DIR` | `/opt/mongoshake/conf.tpl` | Conf template directory |
| `SHAKE_CONF_DIR` | `/opt/mongoshake/conf` | Rendered conf directory |

### Volumes

| Path | Description |
|---|---|
| `/opt/mongoshake/pm2` | `ecosystem.config.js` (required) |
| `/opt/mongoshake/conf.tpl` | Conf templates |
| `/opt/mongoshake/logs` | Collector and pm2 logs (pm2-logrotate: 100M, keep 7, compressed) |

## Local build

```bash
./build.sh                                         # both archs, loaded locally (requires containerd image store)
PLATFORMS=linux/arm64 ./build.sh                   # single arch
PUSH=1 IMAGE=docker.io/xxx/mongoshake-pm2 ./build.sh
MONGOSHAKE_TAG=release-v2.8.8-20260428 TAG=2.8.8 ./build.sh
```

## CI

`.github/workflows/build.yml` builds both architectures and pushes to GHCR and Docker Hub.

- Push to `main`: build + push
- Pull request: build only
- Manual trigger: `mongoshake_tag` can be specified

Tags: `2.8.8`, `release-v2.8.8-20260428`, `latest`, `sha-xxxxxxx`

Configure the following under the repo's Settings → Secrets and variables → Actions:

| Type | Name | Description |
|---|---|---|
| Variable | `DOCKERHUB_USERNAME` | Docker Hub username (also used as the image namespace); Docker Hub is skipped if unset |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token (Read & Write) |

GHCR uses the built-in `GITHUB_TOKEN`. After the first push the package is private by default; change it to public in the package settings.
