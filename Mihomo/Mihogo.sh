# 创建 bin 目录（如果不存在）
mkdir -p "$HOME/bin"

# 下载 Manage.sh 到 bin
curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Manage.sh -o "$HOME/bin/Manage.sh"
chmod +x "$HOME/bin/Manage.sh"

# 执行 Manage.sh，根据目录判断 deploy 或 update
"$HOME/bin/Manage.sh" $( [ ! -d "$HOME/substore" ] || [ ! -d "$HOME/mihomo" ] && echo "deploy" || echo "update" )

# 设置开机自启，确保 start-services.sh 调用的是 bin 下的 Manage.sh
mkdir -p "$HOME/.termux/boot"
cat > "$HOME/.termux/boot/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/bin/Manage.sh" start
EOF
chmod +x "$HOME/.termux/boot/start-services.sh"

echo "✅ Manage.sh 部署完成，开机自启已设置"
