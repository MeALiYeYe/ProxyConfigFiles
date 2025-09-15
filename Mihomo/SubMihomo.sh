#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

# Mihomo 核心下载链接
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
# 安装依赖
#------------------------------------------------
install_dependencies() {
    log_info "安装依赖..."
    pkg up -y
    pkg i -y nodejs-lts wget unzip curl jq cronie termux-services
    sv-enable crond && sv up crond
    log_info "依赖安装完成"
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

    # 解压
    if file mihomo.gz | grep -q "gzip compressed"; then
        gunzip -f mihomo.gz
    else
        log_warn "Mihomo 文件非 gzip 压缩"
    fi

    chmod +x mihomo || true
    download_assets
    log_info "Mihomo 部署完成"
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
# 服务管理
#------------------------------------------------
start_services() {
    log_info "启动 Sub-Store 与 Mihomo..."
    cd "$SUBSTORE_DIR"
    if ! pgrep -f "sub-store.bundle.js" > /dev/null; then
        nohup node sub-store.bundle.js >> substore.log 2>&1 &
    fi
    cd "$MIHOMO_DIR"
    if ! pgrep -f "mihomo" > /dev/null; 键，然后
        nohup ./mihomo -d . >> mihomo.log 2>&1 &
    fi
    log_info "服务已启动"
}

stop_services() {
    pkill -f "sub-store.bundle.js" || true
    pkill -f "mihomo" || true
    log_info "服务已停止"
}

update_services() {
    log_info "更新 Sub-Store 与 Mihomo..."
    stop_services
    deploy_substore
    deploy_mihomo
    start_services
    log_info "更新完成"
}

#------------------------------------------------
# 开机自启与定时更新
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR"
    BOOT_FILE="$BOOT_SCRIPT_DIR/start-services.sh"
    cat > "$BOOT_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/SubMihomo.sh" start
EOF
    chmod +x "$BOOT_FILE"
    log_info "已设置开机自启: $BOOT_FILE"

    # 定时更新
    (crontab -l 2>/dev/null | grep -v "SubMihomo.sh update" ; echo "0 */12 * * * bash $HOME/SubMihomo.sh update >> $HOME/SubMihomo-update.log 2>&1") | crontab -
    log_info "已设置每 12 小时自动更新 SubMihomo.sh"
}

#------------------------------------------------
# 主逻辑
#------------------------------------------------
case "$1" in
    deploy)
        if is_deployed; then
            log_warn "系统已部署过，如需重新部署请先删除 $SUB_MIHOMO_SCRIPT 及相关目录。"
        else
            deploy_submihomo
            deploy_services
            log_info "✅ 初次部署完成"
        fi
        ;;
    start) start_services ;;
    stop) stop_services ;;
    restart) restart_services ;;
    update) update_services ;;
    log) view_log ;;
    log-mihomo) view_mihomo_log ;;
    *)
        echo "用法: $0 {deploy|start|stop|restart|update|log|log-mihomo}"
        exit 1
        ;;
esac
