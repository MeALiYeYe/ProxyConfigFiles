#!/usr/bin/env bash
set -e

rm -rf tmp/normalized
mkdir -p tmp/normalized

convert_yaml() {
  sed '1d' "$1" | sed 's/^- //' | while read -r line; do
    if echo "$line" | grep -qE '^(DOMAIN|DOMAIN-SUFFIX|IP-CIDR|IP-CIDR6),'; then
      echo "$line"
    elif echo "$line" | grep -q '^\+\.'; then
      echo "DOMAIN-SUFFIX,${line#+.}"
    elif echo "$line" | grep -q '/'; then
      echo "IP-CIDR,$line"
    else
      echo "DOMAIN,$line"
    fi
  done
}

find tmp/expanded -type f -name '*.list' | while read -r file; do
  rel="${file#tmp/expanded/}"
  out="tmp/normalized/${rel%.*}.list"

  mkdir -p "$(dirname "$out")"

  if grep -q '^payload:' "$file"; then
    convert_yaml "$file" > "$out"
  else
    sed '/^#/d;/^$/d' "$file" > "$out"
  fi
done
