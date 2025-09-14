#!/data/data/com.termux/files/usr/bin/bash
# Termux 一键部署 Sub-Store + Mihomo Smart 核心 + Alpha 配置 + Geo + 完整规则集

termux-wake-lock

echo "=========================="
echo "请选择操作:"
echo "1. 部署并启动 Sub-Store + Mihomo"
echo "2. 停止 Sub-Store + Mihomo"
read -p "请输入数字 (1 或 2): " choice

# ---------- 停止进程 ----------
if [ "$choice" = "2" ]; then
    echo "停止 Sub-Store 和 Mihomo..."
    pkill -f "sub-store.bundle.js"
    pkill -f "mihomo"
    echo "已停止所有进程。"
    exit 0
fi

# ---------- 部署 & 启动 ----------
echo "=========================="
echo "1️⃣ 准备目录"
cd ~
mkdir -p ~/substore
mkdir -p ~/.config/mihomo
mkdir -p ~/.config/mihomo/rules
mkdir -p ~/.config/mihomo/geo

# ---------- Sub-Store ----------
echo "=========================="
echo "2️⃣ 部署 Sub-Store"
cd ~/substore
if [ ! -f sub-store.bundle.js ]; then
    wget -O sub-store.bundle.js https://github.com/MeALiYeYe/substore/releases/download/v1.0.0/sub-store.bundle.js
fi
nohup node sub-store.bundle.js > substore.log 2>&1 &
echo "Sub-Store 已启动，日志: ~/substore/substore.log"

# ---------- Mihomo 核心 ----------
echo "=========================="
echo "3️⃣ 下载 Mihomo 核心"
if [ ! -f $PREFIX/bin/mihomo ]; then
    wget -O ~/.config/mihomo/mihomo-smart.gz https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-f83f0c7.gz
    gunzip -f ~/.config/mihomo/mihomo-smart.gz
    mv ~/.config/mihomo/mihomo-smart $PREFIX/bin/mihomo
    chmod +x $PREFIX/bin/mihomo
fi

# ---------- Mihomo 配置文件 ----------
echo "=========================="
echo "4️⃣ 下载配置文件"
wget -O ~/.config/mihomo/config.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml

# ---------- Geo 文件 ----------
echo "=========================="
echo "5️⃣ 下载 Geo 文件"
cd ~/.config/mihomo/geo
wget -O geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
wget -O geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
wget -O Country.mmdb https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb
wget -O Country-asn.mmdb https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country-asn.mmdb

# ---------- 规则集 ----------
echo "=========================="
echo "6️⃣ 下载规则集文件"
cd ~/.config/mihomo/rules
wget -O Redirect.yaml https://raw.githubusercontent.com/SunsetMkt/anti-ip-attribution/refs/heads/main/generated/rule-provider.yaml
wget -O Direct.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Direct.yaml
wget -O Reject.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Reject.yaml
wget -O Proxy.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Proxy.yaml
wget -O Emby.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Emby.yaml
wget -O AWAvenue.yaml https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/Filters/AWAvenue-Ads-Rule-Clash.yaml

# ---------- 启动 Mihomo ----------
echo "=========================="
echo "7️⃣ 启动 Mihomo"
nohup mihomo -d ~/.config/mihomo > ~/.config/mihomo/mihomo.log 2>&1 &
echo "Mihomo 已启动，日志: ~/.config/mihomo/mihomo.log"

# ---------- 配置 Termux:Boot 自动启动 ----------
echo "=========================="
mkdir -p ~/.termux/boot
cp ~/deploy.sh ~/.termux/boot/deploy.sh
chmod +x ~/.termux/boot/deploy.sh
echo "脚本已复制到 Termux:Boot，重启后自动启动"

echo "=========================="
echo "✅ 部署完成！"
echo "查看日志："
echo "Sub-Store: tail -f ~/substore/substore.log"
echo "Mihomo: tail -f ~/.config/mihomo/mihomo.log"
echo "停止服务: 重新运行脚本选择 '2'"
