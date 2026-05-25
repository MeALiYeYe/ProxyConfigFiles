#!/usr/bin/env bash
set -e

mkdir -p Mihomo/rule
mkdir -p Egern/rule
mkdir -p "Quantumult X/rule"
mkdir -p Surge/rule

# ✅ 清理旧文件
rm -rf Mihomo/rule/* Egern/rule/* "Quantumult X/rule"/* Surge/rule/*

total_rules=0

while read -r file; do

  rel_path="${file#tmp/normalized/}"
  rel_path="${rel_path#./}"

  out_dir=$(dirname "$rel_path")
  base=$(basename "$rel_path" .list)

  name="$out_dir/$base"
  [[ "$out_dir" == "." ]] && name="$base"

  tmp=$(mktemp)
  sorted=$(mktemp)

  echo "Processing $name"

  ################################
  # 基础清洗
  ################################

  sed '/^#/d;/^$/d' "$file" | sort -u > "$tmp"

  ################################
  # 分类输出（保证不丢规则）
  ################################

  # DOMAIN 系列
  grep '^DOMAIN,' "$tmp" | sort -u >> "$sorted" || true
  grep '^DOMAIN-SUFFIX,' "$tmp" | sort -u >> "$sorted" || true
  grep '^DOMAIN-KEYWORD,' "$tmp" | sort -u >> "$sorted" || true
  grep '^DOMAIN-WILDCARD,' "$tmp" | sort -u >> "$sorted" || true
  grep '^DOMAIN-REGEX,' "$tmp" | sort -u >> "$sorted" || true

  ################################
  # IP 聚合
  ################################

  ipv4_tmp=$(mktemp)
  ipv6_tmp=$(mktemp)

  grep '^IP-CIDR,' "$tmp" | cut -d',' -f2 > "$ipv4_tmp" || true
  grep '^IP-CIDR6,' "$tmp" | cut -d',' -f2 > "$ipv6_tmp" || true

  py_script=$(mktemp)

  cat > "$py_script" << 'EOF'
import sys, ipaddress

mode = sys.argv[1]
file = sys.argv[2]

with open(file) as f:
    nets = [ipaddress.ip_network(line.strip(), strict=False) for line in f if line.strip()]

collapsed = sorted(ipaddress.collapse_addresses(nets))

if mode == "ipv4":
    for net in collapsed:
        if net.version == 4:
            print(f"IP-CIDR,{net}")
elif mode == "ipv6":
    for net in collapsed:
        if net.version == 6:
            print(f"IP-CIDR6,{net}")
EOF

  if [ -s "$ipv4_tmp" ]; then
    python3 "$py_script" ipv4 "$ipv4_tmp" >> "$sorted"
  fi

  if [ -s "$ipv6_tmp" ]; then
    python3 "$py_script" ipv6 "$ipv6_tmp" >> "$sorted"
  fi

  rm -f "$ipv4_tmp" "$ipv6_tmp" "$py_script"

  ################################
  # 其他规则（不覆盖，只追加）
  ################################

  grep -Ev '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|DOMAIN-WILDCARD|DOMAIN-REGEX|IP-CIDR|IP-CIDR6),' "$tmp" >> "$sorted" || true

  ################################
  # 覆盖 tmp（最终规则集）
  ################################

  mv "$sorted" "$tmp"

  ################################
  # 统计
  ################################

  count=$(wc -l < "$tmp")
  total_rules=$((total_rules + count))

  domain_count=$(grep -Ec '^(DOMAIN|DOMAIN-SUFFIX),' "$tmp" || true)
  ip_count=$(grep -Ec '^(IP-CIDR|IP-CIDR6),' "$tmp" || true)

  echo "$name total: $count (domain: $domain_count / ip: $ip_count)"

  ################################
  # Mihomo
  ################################

  mihomo_domain_out="Mihomo/rule/$name.yaml"
  mihomo_ip_out="Mihomo/rule/${name}_ip.yaml"

  mkdir -p "$(dirname "$mihomo_domain_out")"

  domain_lines=$(grep -E '^(DOMAIN|DOMAIN-SUFFIX),' "$tmp" || true)

  if [ -n "$domain_lines" ]; then
    echo "payload:" > "$mihomo_domain_out"

    echo "$domain_lines" | while IFS=',' read -r type value extra; do
      case "$type" in
        DOMAIN-SUFFIX)
          echo "  - +.$value"
          ;;
        DOMAIN)
          echo "  - $value"
          ;;
      esac
    done >> "$mihomo_domain_out"
  else
    rm -f "$mihomo_domain_out"
  fi

  ################################
  # Mihomo IP
  ################################

  ip_lines=$(grep -E '^(IP-CIDR|IP-CIDR6),' "$tmp" | cut -d',' -f2 || true)

  if [ -n "$ip_lines" ]; then
    echo "payload:" > "$mihomo_ip_out"
    echo "$ip_lines" | sed 's/^/  - /' >> "$mihomo_ip_out"
  else
    rm -f "$mihomo_ip_out"
  fi

  ################################
  # Quantumult X
  ################################

  qx_out="Quantumult X/rule/$name.list"
  mkdir -p "$(dirname "$qx_out")"
  cp "$tmp" "$qx_out"

  ################################
  # Surge
  ################################

  surge_out="Surge/rule/$name.list"
  mkdir -p "$(dirname "$surge_out")"
  cp "$tmp" "$surge_out"

  ################################
  # Egern
  ################################

  egern_out="Egern/rule/$name.yaml"
  mkdir -p "$(dirname "$egern_out")"
  rm -f "$egern_out"

  if grep -qE '^IP-CIDR,|^IP-CIDR6,|^GEOIP,' "$tmp"; then
    echo "no_resolve: true" >> "$egern_out"
  fi

  if grep -q '^DOMAIN-SUFFIX,' "$tmp"; then
    echo "domain_suffix_set:" >> "$egern_out"
    grep '^DOMAIN-SUFFIX,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^DOMAIN,' "$tmp"; then
    echo "domain_set:" >> "$egern_out"
    grep '^DOMAIN,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^DOMAIN-KEYWORD,' "$tmp"; then
    echo "domain_keyword_set:" >> "$egern_out"
    grep '^DOMAIN-KEYWORD,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^DOMAIN-WILDCARD,' "$tmp"; then
    echo "domain_wildcard_set:" >> "$egern_out"
    grep '^DOMAIN-WILDCARD,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^DOMAIN-REGEX,' "$tmp"; then
    echo "domain_regex_set:" >> "$egern_out"
    grep '^DOMAIN-REGEX,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^IP-CIDR,' "$tmp"; then
    echo "ip_cidr_set:" >> "$egern_out"
    grep '^IP-CIDR,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^IP-CIDR6,' "$tmp"; then
    echo "ip_cidr6_set:" >> "$egern_out"
    grep '^IP-CIDR6,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^GEOIP,' "$tmp"; then
    echo "geoip_set:" >> "$egern_out"
    grep '^GEOIP,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

  if grep -q '^PROTOCOL,' "$tmp"; then
    echo "protocol_set:" >> "$egern_out"
    grep '^PROTOCOL,' "$tmp" | cut -d',' -f2 | sed 's/^/  - /' >> "$egern_out"
  fi

done < <(find tmp/normalized -type f -name '*.list')

echo "Total rules: $total_rules"
