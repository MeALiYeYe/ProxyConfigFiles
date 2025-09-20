#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 创建 bin 目录并下载 Manage.sh
#------------------------------------------------
mkdir -p "$HOME/bin"
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Manage.sh -o "$HOME/bin/Manage.sh"
chmod +x "$HOME/bin/Manage.sh"
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }

#------------------------------------------------
# 首次执行部署或更新
#------------------------------------------------
if [ ! -d "$HOME/substore" ] || [ ! -d "$HOME/mihomo" ]; then
    log_info "检测到未部署，执行首次部署..."
    "$HOME/bin/Manage.sh" deploy
else
    log_info "目录已存在，执行更新..."
    "$HOME/bin/Manage.sh" update
fi
