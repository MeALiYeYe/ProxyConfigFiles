#!/data/data/com.termux/files/usr/bin/bash
# Termux 一键部署 + 管理 Sub-Store + Mihomo Smart 核心 + Alpha 配置

# 防止休眠杀后台
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

echo "=========================="
echo "2️⃣ 部署 Sub-Store"
cd ~/substore
if [ ! -f sub-store.bundle.js ]; then
    echo "下载 Sub-Store..."
    wget -O sub-store.bundle.js https://github.com/MeALiYeYe/substore/releases/download/v1.0.0/sub-store.bundle.js
fi
nohup node sub-store.bundle.js > substore.log 2>&1 &
echo "Sub-Store 已启动，日志: ~/substore/substore.log"

echo "=========================="
echo "3️⃣ 部署 Mihomo (Smart 核心 + Alpha 配置)"
cd ~/.config/mihomo
if [ ! -f $PREFIX/bin/mihomo ]; then
    echo "下载 Mihomo Smart 核心..."
    wget -O mihomo-smart.gz https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-f83f0c7.gz
    gunzip -f mihomo-smart.gz
    mv mihomo-smart $PREFIX/bin/mihomo
    chmod +x $PREFIX/bin/mihomo
fi

echo "下载 Alpha 配置文件..."
wget -O config.yaml https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml

nohup mihomo -d ~/.config/mihomo > mihomo.log 2>&1 &
echo "Mihomo Smart 核心 + Alpha 配置已启动，日志: ~/.config/mihomo/mihomo.log"

echo "=========================="
echo "4️⃣ 配置 Termux:Boot 自动启动"
mkdir -p ~/.termux/boot
cp ~/deploy.sh ~/.termux/boot/
chmod +x ~/.termux/boot/deploy.sh
echo "脚本已复制到 Termux:Boot 目录，重启后自动启动"

echo "=========================="
echo "✅ 部署完成！"
echo "可通过以下命令查看日志："
echo "Sub-Store: tail -f ~/substore/substore.log"
echo "Mihomo: tail -f ~/.config/mihomo/mihomo.log"
echo "停止服务: 重新运行脚本选择 '2'"
