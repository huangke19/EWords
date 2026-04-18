#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_ARCHIVE="/tmp/inkwell-deploy-$$.tgz"

REMOTE_HOST="${INKWELL_REMOTE_HOST:-root@207.246.106.137}"
REMOTE_DIR="${INKWELL_REMOTE_DIR:-/opt/inkwell}"
REMOTE_SERVICE="${INKWELL_REMOTE_SERVICE:-inkwell}"
REMOTE_URL="${INKWELL_REMOTE_URL:-http://207.246.106.137:9090}"

SYNC_DB=0
SKIP_BUILD=0

usage() {
  cat <<EOF
用法: ./deploy-vps.sh [选项]

选项:
  --with-db      同步本地 ewords.db 到 VPS
  --skip-build   不在 VPS 上重新 go build
  -h, --help     显示帮助

环境变量:
  INKWELL_REMOTE_HOST     远端 SSH 地址，默认 ${REMOTE_HOST}
  INKWELL_REMOTE_DIR      远端项目目录，默认 ${REMOTE_DIR}
  INKWELL_REMOTE_SERVICE  systemd 服务名，默认 ${REMOTE_SERVICE}
  INKWELL_REMOTE_URL      健康检查地址，默认 ${REMOTE_URL}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-db)
      SYNC_DB=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

cleanup() {
  rm -f "$TMP_ARCHIVE"
}
trap cleanup EXIT

cd "$ROOT_DIR"

echo "==> 打包本地项目"
tar czf "$TMP_ARCHIVE" \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='ewords.db' \
  --exclude='ewords.db-*' \
  --exclude='ewords.remote.db' \
  --exclude='ewords.remote.db-*' \
  --exclude='ewords.merged.db' \
  --exclude='*.log' \
  --exclude='.inkwell.pid' \
  --exclude='inkwell' \
  --exclude='inkwell_linux_new' \
  -C "$ROOT_DIR" .

echo "==> 上传部署包到 ${REMOTE_HOST}"
scp "$TMP_ARCHIVE" "${REMOTE_HOST}:/tmp/inkwell-deploy.tgz"

if [[ "$SYNC_DB" -eq 1 ]]; then
  if [[ ! -f "$ROOT_DIR/ewords.db" ]]; then
    echo "本地缺少 ewords.db，无法同步数据库" >&2
    exit 1
  fi
  echo "==> 上传本地数据库到 ${REMOTE_HOST}"
  scp "$ROOT_DIR/ewords.db" "${REMOTE_HOST}:/tmp/ewords.db.deploy"
fi

REMOTE_SCRIPT=$(cat <<EOF
set -euo pipefail

REMOTE_DIR='${REMOTE_DIR}'
REMOTE_SERVICE='${REMOTE_SERVICE}'
SKIP_BUILD='${SKIP_BUILD}'
SYNC_DB='${SYNC_DB}'

cd "\$REMOTE_DIR"

timestamp=\$(date +%Y%m%d_%H%M%S)

echo "==> 停止服务"
systemctl stop "\$REMOTE_SERVICE"

echo "==> 备份当前运行文件"
if [[ -f inkwell_linux ]]; then
  cp inkwell_linux "inkwell_linux.bak.\$timestamp"
fi
if [[ -f ewords.db ]]; then
  cp ewords.db "ewords.db.bak.\$timestamp"
fi

echo "==> 解压最新项目文件"
tar xzf /tmp/inkwell-deploy.tgz -C "\$REMOTE_DIR"

if [[ "\$SYNC_DB" == "1" ]]; then
  echo "==> 替换远端数据库"
  cp /tmp/ewords.db.deploy "\$REMOTE_DIR/ewords.db"
fi

if [[ "\$SKIP_BUILD" != "1" ]]; then
  echo "==> 远端编译 inkwell_linux"
  export PATH=/snap/bin:\$PATH
  go build -o inkwell_linux .
fi

echo "==> 启动服务"
systemctl start "\$REMOTE_SERVICE"
systemctl is-active "\$REMOTE_SERVICE"

rm -f /tmp/inkwell-deploy.tgz /tmp/ewords.db.deploy
EOF
)

echo "==> 在 VPS 上执行部署"
ssh "$REMOTE_HOST" "$REMOTE_SCRIPT"

echo "==> 健康检查 ${REMOTE_URL}"
curl --fail --silent --show-error -I "$REMOTE_URL" >/dev/null

echo "部署完成"
