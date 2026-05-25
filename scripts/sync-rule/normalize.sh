#!/usr/bin/env bash
set -e

convert_yaml() {
  input="$1"
  output="$2"

  sed '1d' "$input" | sed 's/^- //' | while read -r line; do
    if echo "$line" | grep -qE '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|DOMAIN-WILDCARD|DOMAIN-REGEX|IP-CIDR|IP-CIDR6|GEOIP|PROTOCOL),'; then
      echo "$line"
    elif echo "$line" | grep -q '^\+\.'; then
      echo "DOMAIN-SUFFIX,${line#+.}"
    elif echo "$line" | grep -q '/'; then
      echo "IP-CIDR,$line"
    else
      echo "DOMAIN,$line"
    fi
  done > "$output"
}

normalize_file() {
  input="$1"
  output="$2"

  tmp_input=$(mktemp)
  sed '/^# source:/d' "$input" > "$tmp_input"

  if grep -q '^payload:' "$tmp_input"; then
    convert_yaml "$tmp_input" "$output"
  else
    sed '/^#/d;/^$/d' "$tmp_input" > "$output"
  fi

  rm -f "$tmp_input"
}

find tmp/expanded -type f \
  ! -path "*/\.*" \
  ! -name "*.md" \
  | while read -r file; do

  rel_path="${file#tmp/expanded/}"
  rel_path="${rel_path#./}"

  dir_path=$(dirname "$rel_path")
  filename=$(basename "$file")

  if [[ "$filename" == *"@"* ]]; then
    base="${filename%%@*}"
  else
    base="${filename%.*}"
  fi

  out="tmp/normalized/${dir_path}/${base}.list"
  mkdir -p "$(dirname "$out")"

  tmp=$(mktemp)
  normalize_file "$file" "$tmp"

  if [ -f "$out" ]; then
    cat "$out" "$tmp" | sed '/^#/d;/^$/d' | sort -u > "${out}.new"
    mv "${out}.new" "$out"
  else
    mv "$tmp" "$out"
  fi

done
