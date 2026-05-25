#!/usr/bin/env bash
set -e

# 定义核心的存储路径与版本记录路径
STATIC_DIR="Mihomo/static"
MIHOMO_PATH="$STATIC_DIR/mihomo"
VERSION_FILE="$STATIC_DIR/version.json"

mkdir -p "$STATIC_DIR"

# 如果文件存在且可执行，直接使用
if [ -x "$MIHOMO_PATH" ]; then
  echo "Mihomo already exists in $MIHOMO_PATH, skip download"
  "$MIHOMO_PATH" -v || true
else
  echo "Mihomo not found in static directory, fetching latest release..."
  
  # 清理历史残留
  rm -f mihomo.gz mihomo
  
  # 动态获取最新版本号
  LATEST_MIHOMO_VER=$(curl -sL "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | jq -r '.tag_name')
  
  if [ -z "$LATEST_MIHOMO_VER" ] || [ "$LATEST_MIHOMO_VER" = "null" ]; then
    echo "Error: Failed to fetch the latest Mihomo version from GitHub API."
    exit 1
  fi
  
  URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_MIHOMO_VER}/mihomo-linux-amd64-${LATEST_MIHOMO_VER}.gz"
  echo "Downloading Mihomo ${LATEST_MIHOMO_VER} from: $URL"
  
  curl -L --fail --retry 3 --connect-timeout 10 -o mihomo.gz "$URL"

  # 校验 gzip（防止下载到 HTML 报错页面）
  if ! file mihomo.gz | grep -q gzip; then
    echo "Download failed (not gzip)"
    cat mihomo.gz | head -n 20
    exit 1
  fi

  gunzip -f mihomo.gz
  mv -f mihomo "$MIHOMO_PATH"
  chmod +x "$MIHOMO_PATH"
  
  # 顺便同步更新一下本地的 version.json 记录（如果该文件存在）
  if [ -f "$VERSION_FILE" ]; then
    jq ".mihomo = \"$LATEST_MIHOMO_VER\"" "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"
  else
    echo "{\"mihomo\": \"$LATEST_MIHOMO_VER\", \"zashboard\": \"none\"}" > "$VERSION_FILE"
  fi

  echo "Mihomo ready in static directory:"
  "$MIHOMO_PATH" -v || true
fi

# 指定静态内核路径
MIHOMO_PATH="Mihomo/static/mihomo"

detect_behavior() {
  file="$1"
  first=$(grep -v '^payload:' "$file" | sed 's/^- //' | head -n 1)

  if echo "$first" | grep -q '/'; then
    echo "ipcidr"
  else
    echo "domain"
  fi
}

find Mihomo/rule -type f -name '*.yaml' | sort | while read -r file; do

  rel_path="${file#Mihomo/rule/}"
  name="${rel_path%.yaml}"
  output="Mihomo/rule/$name.mrs"

  mkdir -p "$(dirname "$output")"

  behavior=$(detect_behavior "$file")

  echo "[MRS] $name → $behavior"

  # 使用静态目录下的 mihomo 核心执行转换操作
  "$MIHOMO_PATH" convert-ruleset "$behavior" yaml "$file" "$output"

done
