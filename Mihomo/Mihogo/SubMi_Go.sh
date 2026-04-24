#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

pkg update -y && pkg install -y wget

# 获取脚本
mkdir -p "$HOME/bin"
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/main/Mihomo/Mihogo/Manage.sh -o "$HOME/bin/SubMi.sh"
chmod +x "$HOME/bin/Manage.sh"

# 确保Bin目录存在
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/bin:$PATH"
fi

# 立即生效（当前 shell）
export PATH="$HOME/bin:$PATH"

# 开始部署
Manage.sh deploy
