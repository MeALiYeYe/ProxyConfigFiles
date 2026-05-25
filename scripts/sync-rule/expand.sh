#!/usr/bin/env bash
set -e

rm -rf tmp/expanded
mkdir -p tmp/expanded

declare -A visited_file
declare -A visited_url

cache_dir="/tmp/rule_cache"
mkdir -p "$cache_dir"

fetch_url() {
  local url="$1"
  local key
  key=$(echo -n "$url" | md5sum | cut -d' ' -f1)
  local cache_file="$cache_dir/$key"

  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return
  fi

  if [[ -n "${visited_url[$url]}" ]]; then
    return
  fi
  visited_url[$url]=1

  echo "[fetch] $url"
  curl -sSL --retry 3 --connect-timeout 10 "$url" | tee "$cache_file"
}

expand_file() {
  local file="$1"

  if [[ -n "${visited_file[$file]}" ]]; then
    return
  fi
  visited_file[$file]=1

  while IFS= read -r line || [ -n "$line" ]; do

    if [[ "$line" =~ ^@https?:// ]]; then
      url="${line#@}"
      echo "# source: $url"
      fetch_url "$url"

    elif [[ "$line" =~ ^@ ]]; then
      path="$(dirname "$file")/${line#@}"
      [ -f "$path" ] && expand_file "$path"

    elif [[ "$line" =~ ^#!(include|source): ]]; then
      ref=$(echo "$line" | sed -E 's/^#!(include|source):[[:space:]]*//')
      echo "$line"

      if [[ "$ref" =~ ^https?:// ]]; then
        fetch_url "$ref"
      else
        expand_file "$(dirname "$file")/$ref"
      fi

    else
      echo "$line"
    fi

  done < "$file"
}

included_files=$(mktemp)

grep -RhoE '^#!(include|source):[[:space:]]*[^ ]+' rules \
  | sed -E 's/^#!(include|source):[[:space:]]*//' \
  | grep -vE '^https?://' \
  | sort -u > "$included_files"

find rules -type f -name '*.list' | while read -r file; do
  rel="${file#rules/}"

  if grep -qx "$rel" "$included_files"; then
    echo "[skip include] $file"
    continue
  fi

  out="tmp/expanded/$rel"
  mkdir -p "$(dirname "$out")"

  unset visited_file
  declare -A visited_file

  echo "[expand] $file"
  expand_file "$file" > "$out"

done
