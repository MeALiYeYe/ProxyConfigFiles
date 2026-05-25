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

trim() {
  # 去空格 + 去 \r
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r'
}

hash() {
  echo -n "$1" | md5sum | cut -d' ' -f1
}

################################
# 🔐 Safe Fetch（并发安全 + 缓存）
################################

fetch_url() {
  local url
  url=$(trim "$1")

  # 基础校验
  if ! [[ "$url" =~ ^https?:// ]]; then
    err "invalid url: $url"
    return 1
  fi

  local key
  key=$(hash "$url")

  local cache_file="$CACHE_DIR/$key"
  local lock_file="$CACHE_DIR/$key.lock"

  if [[ -s "$cache_file" ]]; then
    log "cache hit: $url"
    cat "$cache_file"
    return
  fi

  exec 9>"$lock_file"
  flock 9

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

  # 去 BOM
  sed -i '1s/^\xEF\xBB\xBF//' "$tmp_file"

  mv "$tmp_file" "$cache_file"
  flock -u 9

  cat "$cache_file"
}

################################
# 🔁 Expand Core
################################

declare -A visited

expand_stream() {
  local source="$1"
  local input="$2"
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

  while IFS= read -r raw || [[ -n "$raw" ]]; do

    line=$(trim "$raw")

    ################################
    # @https
    ################################
    if [[ "$line" =~ ^@https?:// ]]; then
      url="${line#@}"
      url=$(trim "$url")

      echo "# source: $url"

      if content=$(fetch_url "$url"); then
        expand_stream "$url" <(printf "%s\n" "$content") $((depth+1))
      fi

    ################################
    # @local
    ################################
    elif [[ "$line" =~ ^@ ]]; then
      ref="${line#@}"
      ref=$(trim "$ref")

      local_path="$(dirname "$input")/$ref"

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
      ref=$(trim "$ref")

      echo "#!include: $ref"

      if [[ "$ref" =~ ^https?:// ]]; then
        if content=$(fetch_url "$ref"); then
          expand_stream "$ref" <(printf "%s\n" "$content") $((depth+1))
        fi
      else
        local_path="$(dirname "$input")/$ref"

        if [[ -f "$local_path" ]]; then
          expand_stream "$local_path" "$local_path" $((depth+1))
        else
          err "missing include: $local_path"
        fi
      fi

    ################################
    # normal
    ################################
    else
      echo "$line"
    fi

  done < "$input"
}

################################
# 🧹 include 检测
################################

included_files=$(mktemp)

grep -RhoE '^#!(include|source):[[:space:]]*[^ ]+' rules \
  | sed -E 's/^#!(include|source):[[:space:]]*//' \
  | sed 's/\r//' \
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
