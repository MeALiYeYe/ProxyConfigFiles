#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

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
    [[ -d "$SUBSTORE_DIR" && -d "$MIHOMO_DIR" && -f "$MIHOMO_DIR/mihomo" ]]
}

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
    gunzip -f mihomo.gz
    chmod +x mihomo || true
    download_assets
    log_info "Mihomo 部署完成"
}

#------------------------------------------------
# 下载配置、规则和 Geo 文件
#------------------------------------------------
download_assets() {
    mkdir -p "$MIHOMO_DIR/rules" "$MIHOMO_DIR/geo"
    cd "$MIHOMO_DIR"
    wget -O config.yaml "$CONFIG_URL"

    # 下载规则集
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        mkdir -p "$(dirname "$dest")"
        wget -O "$dest" "$src"
    done

    # 下载 Geo 文件
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        mkdir -p "$(dirname "$dest")"
        wget -O "$dest" "$src"
    done
}

#------------------------------------------------
# 服务管理
#------------------------------------------------
start_services() {
    log_info "启动 Sub-Store..."
    cd "$SUBSTORE_DIR"
    if ! pgrep -f "sub-store.bundle.js" > /dev/null; then
        nohup node sub-store.bundle.js >> substore.log 2>&1 &
    else log_warn "Sub-Store 已在运行"; fi

    log_info "启动 Mihomo..."
    cd "$MIHOMO_DIR"
    if ! pgrep -f "mihomo" > /dev/null; then
        nohup ./mihomo -d . >> mihomo.log 2>&1 &
    else log_warn "Mihomo 已在运行"; fi

    log_info "服务已启动"
}

stop_services() {
    pkill -f "sub-store.bundle.js" || true
    pkill -f "mihomo" || true
    log_info "服务已停止"
}

update_geo() {
    log_info "更新 Geo 数据..."
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        mkdir -p "$(dirname "$dest")"
        wget -O "$dest" "$src"
    done
    log_info "Geo 更新完成"
}

update_rules() {
    log_info "更新规则集..."
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        mkdir -p "$(dirname "$dest")"
        wget -O "$dest" "$src"
    done
    log_info "规则集更新完成"
}

update_config() {
    log_info "更新 config.yaml..."
    wget -O "$MIHOMO_DIR/config.yaml" "$CONFIG_URL"
    log_info "config.yaml 更新完成"
}

update_mihomo() {
    log_info "更新 Mihomo 核心..."
    cd "$MIHOMO_DIR"
    wget -O mihomo.gz "$MIHOMO_DOWNLOAD_URL"
    gunzip -f mihomo.gz
    chmod +x mihomo || true
    log_info "Mihomo 核心更新完成"
}

update_all() {
    stop_services
    update_mihomo
    update_config
    update_rules
    update_geo
    start_services
    log_info "全部更新完成"
}

#------------------------------------------------
# 开机自启
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR"
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
Manage.sh start
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
            log_warn "系统已部署过"
        else
            install_dependencies
            deploy_substore
            deploy_mihomo
            start_services
            setup_boot
            log_info "✅ 部署完成"
        fi
        ;;
    start) start_services ;;
    stop) stop_services ;;
    restart) stop_services; start_services ;;
    update-geo) update_geo ;;
    update-rules) update_rules ;;
    update-config) update_config ;;
    update-mihomo) update_mihomo ;;
    update-all) update_all ;;
    log) tail -f "$SUBSTORE_DIR/substore.log" ;;
    log-mihomo) tail -f "$MIHOMO_DIR/mihomo.log" ;;
    *) echo "用法: $0 {deploy|start|stop|restart|update-geo|update-rules|update-config|update-mihomo|update-all|log|log-mihomo}" ;;
esac
