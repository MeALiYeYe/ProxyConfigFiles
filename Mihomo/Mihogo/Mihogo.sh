#!/data/data/com.termux/files/usr/bin/bash
set -e

# 确保 bin 目录和 Manage.sh 存在
mkdir -p "$HOME/bin"
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Mihogoo/Manage.sh -o "$HOME/bin/Manage.sh"
chmod +x "$HOME/bin/Manage.sh"

# 确保 PATH 中有 $HOME/bin
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/bin:$PATH"
fi

# 调用 Manage.sh 部署
Manage.sh deploy
