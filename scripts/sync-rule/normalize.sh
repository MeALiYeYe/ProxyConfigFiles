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
    # 新增权重排序
    cat "$out" "$tmp" | sed '/^#/d;/^$/d' | \
    awk -F',' '{
      type=$1
      if (type=="DEST-PORT") w=1;
      else if (type=="DOMAIN") w=2;
      else if (type=="DOMAIN-SUFFIX") w=3;
      else if (type=="DOMAIN-KEYWORD") w=4;
      else if (type=="DOMAIN-WILDCARD") w=5;
      else if (type=="URL-REGEX") w=6;
      else if (type=="IP-CIDR") w=7;
      else if (type=="IP-CIDR6") w=8;
      else if (type=="GEOIP") w=9;
      else if (type=="IP-ASN") w=10;
      else if (type=="PROTOCOL") w=11;
      else w=99;

      print w "|" $0
    }' | sort -t'|' -k1,1n -k2 | cut -d'|' -f2- | uniq > "${out}.new"
    mv "${out}.new" "$out"
  else
    mv "$tmp" "$out"
  fi

done
