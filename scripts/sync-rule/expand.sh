#!/usr/bin/env bash
set -euo pipefail

################################
# ⚙️ Config
################################

CACHE_DIR="${CACHE_DIR:-/tmp/rule_cache}"
OUT_DIR="tmp/expanded"
DEBUG="${DEBUG:-0}"
MAX_DEPTH=20

mkdir -p "$CACHE_DIR" "$OUT_DIR"

################################
# 🧠 Utils
################################

log() {
  [[ "$DEBUG" == "1" ]] && echo "[DEBUG] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

hash() {
  echo -n "$1" | md5sum | cut -d' ' -f1
}

################################
# 🔐 Safe Fetch（带并发锁 + 缓存）
################################

fetch_url() {
  local url="$1"
  local key
  key=$(hash "$url")

  local cache_file="$CACHE_DIR/$key"
  local lock_file="$CACHE_DIR/$key.lock"

  # 已缓存
  if [[ -s "$cache_file" ]]; then
    log "cache hit: $url"
    cat "$cache_file"
    return
  fi

  # 🔐 文件锁（并发安全）
  exec 9>"$lock_file"
  flock 9

  # 再次检查（防止别的进程刚写完）
  if [[ -s "$cache_file" ]]; then
    log "cache hit after lock: $url"
    cat "$cache_file"
    flock -u 9
    return
  fi

  log "fetch: $url"

  tmp_file=$(mktemp)

  if ! curl -fsSL --retry 3 --connect-timeout 10 "$url" -o "$tmp_file"; then
    err "fetch failed: $url"
    rm -f "$tmp_file"
    flock -u 9
    return 1
  fi

  mv "$tmp_file" "$cache_file"

  flock -u 9

  cat "$cache_file"
}

################################
# 🔁 Expand Core（递归展开）
################################

declare -A visited   # 防循环（统一 file+url）

expand_stream() {
  local source="$1"   # file path or URL tag
  local input="$2"    # 实际内容来源（file or stdin）
  local depth="$3"

  if (( depth > MAX_DEPTH )); then
    err "max depth exceeded: $source"
    return
  fi

  if [[ -n "${visited[$source]:-}" ]]; then
    log "skip visited: $source"
    return
  fi
  visited["$source"]=1

  while IFS= read -r line || [[ -n "$line" ]]; do

    ################################
    # @https
    ################################
    if [[ "$line" =~ ^@https?:// ]]; then
      url="${line#@}"
      echo "# source: $url"

      content=$(fetch_url "$url" || true)
      [[ -n "$content" ]] && expand_stream "$url" <(echo "$content") $((depth+1))

    ################################
    # @local
    ################################
    elif [[ "$line" =~ ^@ ]]; then
      local_path="$(dirname "$input")/${line#@}"

      if [[ -f "$local_path" ]]; then
        echo "# include: $local_path"
        expand_stream "$local_path" "$local_path" $((depth+1))
      else
        err "missing file: $local_path"
      fi

    ################################
    # #!include / #!source
    ################################
    elif [[ "$line" =~ ^#!(include|source): ]]; then
      ref=$(echo "$line" | sed -E 's/^#!(include|source):[[:space:]]*//')

      echo "$line"

      if [[ "$ref" =~ ^https?:// ]]; then
        content=$(fetch_url "$ref" || true)
        [[ -n "$content" ]] && expand_stream "$ref" <(echo "$content") $((depth+1))
      else
        local_path="$(dirname "$input")/$ref"
        if [[ -f "$local_path" ]]; then
          expand_stream "$local_path" "$local_path" $((depth+1))
        else
          err "missing include: $local_path"
        fi
      fi

    ################################
    # normal line
    ################################
    else
      echo "$line"
    fi

  done < "$input"
}

################################
# 🧹 找出被 include 的文件（避免重复生成）
################################

included_files=$(mktemp)

grep -RhoE '^#!(include|source):[[:space:]]*[^ ]+' rules \
  | sed -E 's/^#!(include|source):[[:space:]]*//' \
  | grep -vE '^https?://' \
  | sort -u > "$included_files"

################################
# 🚀 主流程
################################

find rules -type f -name '*.list' | while read -r file; do

  rel="${file#rules/}"

  if grep -qx "$rel" "$included_files"; then
    echo "[skip include] $file"
    continue
  fi

  out="$OUT_DIR/$rel"
  mkdir -p "$(dirname "$out")"

  echo "[expand] $file → $out"

  visited=()
  expand_stream "$file" "$file" 0 > "$out"

done

rm -f "$included_files"

echo "== Expand DONE =="
