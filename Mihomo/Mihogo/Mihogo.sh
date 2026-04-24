#!/data/data/com.termux/files/usr/bin/bash
set -e

# 获取脚本
mkdir -p "$HOME/bin"
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Mihogo/Manage.sh -o "$HOME/bin/Manage.sh"
chmod +x "$HOME/bin/Manage.sh"

# 确保Bin目录存在
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/bin:$PATH"
fi

# 开始部署
Manage.sh deploy
