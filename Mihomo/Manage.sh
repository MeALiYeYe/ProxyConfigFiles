#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUB_MIHOMO_SCRIPT="$HOME/SubMihomo.sh"
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

#------------------------------------------------
# 工具函数
#------------------------------------------------
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

#------------------------------------------------
# 检查是否已部署
#------------------------------------------------
is_deployed() {
    [[ -d "$SUBSTORE_DIR" && -d "$MIHOMO_DIR" && -f "$SUB_MIHOMO_SCRIPT" ]]
}

#------------------------------------------------
# 自动下载 SubMihomo.sh
#------------------------------------------------
ensure_submihomo() {
    if [ ! -f "$SUB_MIHOMO_SCRIPT" ]; then
        log_info "📥 下载 SubMihomo.sh..."
        curl -L https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/SubMihomo.sh -o "$SUB_MIHOMO_SCRIPT"
        chmod +x "$SUB_MIHOMO_SCRIPT"
        log_info "✅ SubMihomo.sh 下载完成"
    fi
}

#------------------------------------------------
# 部署流程
#------------------------------------------------
deploy() {
    log_info "🛠️ 发现未部署，开始初次部署..."
    ensure_submihomo
    bash "$SUB_MIHOMO_SCRIPT" deploy
    setup_boot_autostart
    log_info "✅ 初次部署完成"
}

#------------------------------------------------
# 服务管理
#------------------------------------------------
start_services() {
    log_info "🚀 启动 Sub-Store 和 Mihomo 服务..."
    bash "$SUB_MIHOMO_SCRIPT" start
}

stop_services() {
    log_info "🛑 停止 Sub-Store 和 Mihomo 服务..."
    bash "$SUB_MIHOMO_SCRIPT" stop
}

restart_services() {
    log_info "🔄 重启 Sub-Store 和 Mihomo 服务..."
    bash "$SUB_MIHOMO_SCRIPT" restart
}

update_services() {
    log_info "🔄 更新 Sub-Store 和 Mihomo 资源..."
    ensure_submihomo
    bash "$SUB_MIHOMO_SCRIPT" update
}

#------------------------------------------------
# 日志查看
#------------------------------------------------
view_log() {
    log_info "📄 Sub-Store 日志 (Ctrl+C 退出):"
    tail -n 100 -f "$SUBSTORE_DIR/substore.log"
}

view_mihomo_log() {
    log_info "📄 Mihomo 日志 (Ctrl+C 退出):"
    tail -n 100 -f "$MIHOMO_DIR/mihomo.log"
}

#------------------------------------------------
# Termux 开机自启
#------------------------------------------------
setup_boot_autostart() {
    mkdir -p "$BOOT_SCRIPT_DIR"
    BOOT_FILE="$BOOT_SCRIPT_DIR/start-services.sh"
    cat > "$BOOT_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$SUB_MIHOMO_SCRIPT" start
EOF
    chmod +x "$BOOT_FILE"
    log_info "✅ 已设置 Termux 开机自启: $BOOT_FILE"
}

#------------------------------------------------
# 主逻辑
#------------------------------------------------
case "$1" in
    deploy)
        if is_deployed; then
            log_warn "系统已部署过，如需重新部署请先删除 $SUB_MIHOMO_SCRIPT 及相关目录"
        else
            deploy
        fi
        ;;
    start) start_services ;;
    stop) stop_services ;;
    restart) restart_services ;;
    update) update_services ;;
    log) view_log ;;
    log-mihomo) view_mihomo_log ;;
    *)
        # 自动判断部署或更新
        if ! is_deployed; then
            deploy
        else
            update_services
        fi
        ;;
esac
