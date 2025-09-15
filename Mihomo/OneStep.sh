#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================="
echo "1️⃣ 安装依赖"
pkg up -y
pkg i -y nodejs-lts wget unzip curl -y

echo "=========================="
echo "2️⃣ 部署 Sub-Store"

mkdir -p ~/substore
cd ~/substore

# 下载后端
if [ ! -f sub-store.bundle.js ]; then
    wget -O sub-store.bundle.js https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js
fi

# 下载前端
if [ ! -d frontend ]; then
    wget -O dist.zip https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip
    unzip dist.zip -d frontend
    rm -f dist.zip
fi

# 启动 Sub-Store
nohup node sub-store.bundle.js > substore.log 2>&1 &
echo "✅ Sub-Store 已启动，日志: ~/substore/substore.log"
echo "👉 打开管理界面: https://sub-store.vercel.app/subs?api=http://127.0.0.1:3000"

echo "=========================="
echo "3️⃣ 部署 Mihomo"

mkdir -p ~/mihomo
cd ~/mihomo

# 下载 Mihomo 核心
if [ ! -f mihomo ]; then
    wget -O mihomo.gz https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-f83f0c7.gz
    gunzip mihomo.gz
    chmod +x mihomo
fi

# 下载配置文件
wget -O config.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml

# 创建规则目录
mkdir -p rules

# 下载规则集
wget -O rules/Redirect.yaml "https://raw.githubusercontent.com/SunsetMkt/anti-ip-attribution/refs/heads/main/generated/rule-provider.yaml"
wget -O rules/Direct.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Direct.yaml"
wget -O rules/Reject.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Reject.yaml"
wget -O rules/Proxy.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Proxy.yaml"
wget -O rules/Emby.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Emby.yaml"
wget -O rules/AWAvenue.yaml "https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/Filters/AWAvenue-Ads-Rule-Clash.yaml"

# 下载 Geo 文件
mkdir -p geo
wget -O geo/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
wget -O geo/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
wget -O geo/Country.mmdb "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb"
wget -O geo/Country-asn.mmdb "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country-asn.mmdb"

# 启动 Mihomo
nohup ./mihomo -d . > mihomo.log 2>&1 &
echo "✅ Mihomo 已启动，日志: ~/mihomo/mihomo.log"
echo "👉 管理界面: http://127.0.0.1:9090 （如有 external-ui）"
