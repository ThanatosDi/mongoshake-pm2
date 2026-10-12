# mongoshake-pm2

[MongoShake](https://github.com/alibaba/MongoShake) collector + [pm2](https://pm2.keymetrics.io/) 的多架構 container image（`linux/amd64`、`linux/arm64`）。
一個 container 內用 pm2 同時跑多個 collector process，一個 conf 檔對應一個 process。

官方 release 只有 x86-64 binary，在 arm64 上走模擬層會 SIGSEGV，所以這裡從原始碼以 Go cross-compile 建置。

## 使用

```bash
cd examples
cp .env.example .env          # 填連線字串
docker compose up -d
docker exec mongoshake pm2 ls
```

- 把 `*.conf` 放進 `conf.tpl/`，每個檔案會啟動一個 pm2 app，名稱為 `shake-<檔名>`。
- 啟動時 `entrypoint.sh` 會把 `conf.tpl/*.conf` 內的 `${VAR}` 用環境變數替換後輸出到 `/opt/mongoshake/conf/`；未定義的變數保留原樣。
- 多個 instance 時，`id`、`checkpoint.storage.db`、`incr_sync.http_port` / `full_sync.http_port` / `prom.http_port`、`log.file` 都必須互不相同。
- image 不宣告 `EXPOSE`，需要對外的 port（如 `prom.http_port`）請在 docker compose 的 `ports` 自行對應 conf 內的設定。

### 環境變數

| 變數 | 預設 | 說明 |
|---|---|---|
| `SHAKE_INSTANCES` | 空（全部） | 只啟動指定的 conf，填檔名不含 `.conf`，逗號分隔 |
| `SHAKE_VERBOSE` | `0` | collector `-verbose` 等級 |
| `SHAKE_TPL_DIR` | `/opt/mongoshake/conf.tpl` | conf 模板目錄 |
| `SHAKE_CONF_DIR` | `/opt/mongoshake/conf` | 渲染後 conf 目錄 |

### Volume

| 路徑 | 說明 |
|---|---|
| `/opt/mongoshake/conf.tpl` | conf 模板 |
| `/opt/mongoshake/logs` | collector 與 pm2 log（pm2-logrotate：100M、保留 7 份、壓縮） |

## 本機建置

```bash
./build.sh                                         # 兩架構，load 進本機（需 containerd image store）
PLATFORMS=linux/arm64 ./build.sh                   # 單一架構
PUSH=1 IMAGE=docker.io/xxx/mongoshake-pm2 ./build.sh
MONGOSHAKE_TAG=release-v2.8.8-20260428 TAG=2.8.8 ./build.sh
```

## CI

`.github/workflows/build.yml` 會建置兩架構並推到 GHCR 與 Docker Hub。

- push 到 `main`：build + push
- pull request：只 build
- 手動觸發：可指定 `mongoshake_tag`

Tags：`2.8.8`、`release-v2.8.8-20260428`、`latest`、`sha-xxxxxxx`

需要在 repo 的 Settings → Secrets and variables → Actions 設定：

| 類型 | 名稱 | 說明 |
|---|---|---|
| Variable | `DOCKERHUB_USERNAME` | Docker Hub 帳號（也當 image namespace）；未設定則跳過 Docker Hub |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub Access Token（Read & Write） |

GHCR 使用內建 `GITHUB_TOKEN`。第一次推送後 package 預設為 private，需要到 package 設定改成 public。
