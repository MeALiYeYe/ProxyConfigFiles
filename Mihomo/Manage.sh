#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
SUB_MIHOMO_SCRIPT="$HOME/SubMihomo.sh"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

#------------------------------------------------
# 配置文件和规则集下载链接
#------------------------------------------------
MIHOMO_DOWNLOAD_URL="https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-f83f0c7.gz"
CONFIG_URL="https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml"

RULES_SOURCES=(
    "rules/Redirect.yaml,https://raw.githubusercontent.com/SunsetMkt/anti-ip-attribution/refs/heads/main/generated/rule-provider.yaml"
    "rules/Direct.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Direct.yaml"
    "rules/Reject.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Reject.yaml"
    "rules/Proxy.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Proxy.yaml"
    "rules/Emby.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Emby.yaml"
    "rules/AWAvenue.yaml,https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/Filters/AWAvenue-Ads-Rule-Clash.yaml"
)

GEO_FILES=(
    "geo/geoip.dat,https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    "geo/geosite.dat,https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    "geo/Country.mmdb,https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb"
    "geo/Country-asn.mmdb,https://github.com/Loyalsoldier/geoip/releases/latest/download/Country-asn.mmdb"
)

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
# 部署 Sub-Store
#------------------------------------------------
deploy_substore() {
    log_info "部署 Sub-Store..."
    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"
    wget -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    wget -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend && rm -f dist.zip
    log_info "Sub-Store 部署完成"
}

#------------------------------------------------
# 部署 Mihomo
#------------------------------------------------
deploy_mihomo() {
    log_info "部署 Mihomo..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"
    wget -O mihomo.gz "$MIHOMO_DOWNLOAD_URL"
    gunzip -f mihomo.gz
    chmod +x mihomo || true
    log_info "Mihomo 部署完成"
}

#------------------------------------------------
# 启动 Sub-Store
#------------------------------------------------
start_substore() {
    log_info "启动 Sub-Store..."
    cd "$SUBSTORE_DIR"
    if ! pgrep -f "sub-store.bundle.js" > /dev/null; then
        nohup node sub-store.bundle.js >> substore.log 2>&1 &
        log_info "Sub-Store 启动成功"
    else
        log_warn "Sub-Store 已在运行"
    fi
}

#------------------------------------------------
# 启动 Mihomo
#------------------------------------------------
start_mihomo() {
    log_info "启动 Mihomo..."
    cd "$MIHOMO_DIR"
    if ! pgrep -f "mihomo" > /dev/null; then
        nohup ./mihomo -d . >> mihomo.log 2>&1 &
        log_info "Mihomo 启动成功"
    else
        log_warn "Mihomo 已在运行"
    fi
}

#------------------------------------------------
# 停止 Sub-Store
#------------------------------------------------
stop_substore() {
    pkill -f "sub-store.bundle.js" || true
    log_info "Sub-Store 停止成功"
}

#------------------------------------------------
# 停止 Mihomo
#------------------------------------------------
stop_mihomo() {
    pkill -f "mihomo" || true
    log_info "Mihomo 停止成功"
}

#------------------------------------------------
# 重启 Sub-Store
#------------------------------------------------
restart_substore() {
    stop_substore
    start_substore
}

#------------------------------------------------
# 重启 Mihomo
#------------------------------------------------
restart_mihomo() {
    stop_mihomo
    start_mihomo
}

#------------------------------------------------
# 更新 Sub-Store
#------------------------------------------------
update_substore() {
    log_info "更新 Sub-Store..."
    stop_substore
    deploy_substore
    start_substore
    log_info "Sub-Store 更新完成"
}

#------------------------------------------------
# 更新 Mihomo
#------------------------------------------------
update_mihomo() {
    log_info "更新 Mihomo..."
    stop_mihomo
    deploy_mihomo
    start_mihomo
    log_info "Mihomo 更新完成"
}

#------------------------------------------------
# 下载配置与规则
#------------------------------------------------
download_assets() {
    cd "$MIHOMO_DIR" || exit
    log_info "下载 config.yaml..."
    wget -O config.yaml "$CONFIG_URL"

    log_info "下载规则集..."
    mkdir -p rules
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -O "$dest" "$src"
    done

    log_info "下载 Geo 数据..."
    mkdir -p geo
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -O "$dest" "$src"
    done
}

#------------------------------------------------
# 开机自启
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR"
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/SubMihomo.sh" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"
    log_info "已设置开机自启: $BOOT_SCRIPT_DIR/start-services.sh"
}

#------------------------------------------------
# 主逻辑
#------------------------------------------------
case "$1" in
    deploy)
        if is_deployed; then
            log_warn "系统已部署过，如需重新部署请先删除 $SUB_MIHOMO_SCRIPT 及相关目录。"
        else
            deploy_substore
            deploy_mihomo
            start_substore
            start_mihomo
            setup_boot
            log_info "✅ 部署完成"
        fi
        ;;
    start-substore) start_substore ;;
    start-mihomo) start_mihomo ;;
    stop-substore) stop_substore ;;
    stop-mihomo) stop_mihomo ;;
    restart-substore) restart_substore ;;
    restart-mihomo) restart_mihomo ;;
    update-substore) update_substore ;;
    update-mihomo) update_mihomo ;;
    log) tail -f "$SUBSTORE_DIR/substore.log" ;;
    log-mihomo) tail -f "$MIHOMO_DIR/mihomo.log" ;;
    *)
        echo "用法: $0 {deploy|start-substore|start-mihomo|stop-substore|stop-mihomo|restart-substore|restart-mihomo|update-substore|update-mihomo|log|log-mihomo}"
        exit 1
        ;;
esac
