#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p "$HOME/bin"
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Mihogo/Manage.sh -o "$HOME/bin/Manage.sh"
chmod +x "$HOME/bin/Manage.sh"

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/bin:$PATH"
fi

Manage.sh deploy
