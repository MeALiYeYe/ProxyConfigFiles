#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

# Mihomo 下载链接模板
MIHOMO_DOWNLOAD_URL_ARM64="https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-f83f0c7.gz"
MIHOMO_DOWNLOAD_URL_X86_64="https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-x86_64-alpha-smart-f83f0c7.gz"

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

# 下载函数，带重试和文件检查
download_with_check() {
    local dest="$1"
    local url="$2"
    local retries=3
    local wait_time=3
    local success=0

    for i in $(seq 1 $retries); do
        log_info "下载 $dest (尝试 $i/$retries)..."
        wget -c "$url" -O "$dest" && [[ -s "$dest" ]] && success=1 && break
        log_warn "下载失败，等待 $wait_time 秒后重试..."
        sleep $wait_time
    done

    [[ $success -ne 1 ]] && log_error "下载失败或文件为空: $dest"
}

#------------------------------------------------
# 架构检测
#------------------------------------------------
get_arch() {
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
        aarch64)
            ARCH="arm64-v8a"
            MIHOMO_DOWNLOAD_URL="$MIHOMO_DOWNLOAD_URL_ARM64"
            ;;
        x86_64)
            ARCH="x86_64"
            MIHOMO_DOWNLOAD_URL="$MIHOMO_DOWNLOAD_URL_X86_64"
            ;;
        *)
            log_warn "未知架构: $ARCH_RAW"
            ARCH="unknown"
            MIHOMO_DOWNLOAD_URL=""
            ;;
    esac
    log_info "检测到架构: $ARCH"
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
    download_with_check "sub-store.bundle.js" "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    download_with_check "dist.zip" "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend && rm -f dist.zip
    log_info "Sub-Store 部署完成"
}

#------------------------------------------------
# 部署 Mihomo
#------------------------------------------------
deploy_mihomo() {
    get_arch
    [[ -z "$MIHOMO_DOWNLOAD_URL" ]] && log_error "无法获取 Mihomo 下载链接"

    log_info "部署 Mihomo..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"

    download_with_check "mihomo.gz" "$MIHOMO_DOWNLOAD_URL"
    gunzip -f mihomo.gz
    chmod +x mihomo || true

    update_config
    update_rules
    update_geo
    log_info "Mihomo 部署完成"
}

#------------------------------------------------
# 下载与更新功能
#------------------------------------------------
update_config() { download_with_check "$MIHOMO_DIR/config.yaml" "$CONFIG_URL"; log_info "✅ config.yaml 更新完成"; }
update_rules() {
    mkdir -p "$MIHOMO_DIR/rules"
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        download_with_check "$MIHOMO_DIR/$dest" "$src"
    done
    log_info "✅ 规则集更新完成"
}
update_geo() {
    mkdir -p "$MIHOMO_DIR"
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        if [ ! -f "$dest" ]; then
            log_warn "$dest 不存在，开始下载..."
            wget -O "$dest" "$src"
        else
            log_info "检测 $dest 是否需要更新..."
            wget -N -O "$dest" "$src"
        fi
    done
    log_info "✅ GEO 数据已更新（如有新版本）"
}

update_core() {
    get_arch
    [[ -z "$MIHOMO_DOWNLOAD_URL" ]] && log_error "无法获取 Mihomo 下载链接"
    download_with_check "$MIHOMO_DIR/mihomo.gz" "$MIHOMO_DOWNLOAD_URL"
    gunzip -f "$MIHOMO_DIR/mihomo.gz"
    chmod +x "$MIHOMO_DIR/mihomo" || true
    log_info "✅ Mihomo 核心更新完成"
}

#------------------------------------------------
# 启动前检查必要文件
#------------------------------------------------
check_mihomo_ready() {
    [[ ! -x "$MIHOMO_DIR/mihomo" ]] && log_error "Mihomo 核心不存在或不可执行"
    [[ ! -s "$MIHOMO_DIR/config.yaml" ]] && log_error "config.yaml 不存在或为空"
    [[ ! -s "$MIHOMO_DIR/geo/geosite.dat" ]] && log_error "Geo 文件 geosite.dat 不存在或为空"
    [[ ! -s "$MIHOMO_DIR/geo/geoip.dat" ]] && log_error "Geo 文件 geoip.dat 不存在或为空"
}

#------------------------------------------------
# 服务管理
#------------------------------------------------
start_services() {
    check_mihomo_ready

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

restart_services() {
    stop_services
    start_services
}

#------------------------------------------------
# Termux 开机自启
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR"
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/$(basename "$0")" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"
    log_info "已设置开机自启: $BOOT_SCRIPT_DIR/start-services.sh"
}

#------------------------------------------------
# 查看日志
#------------------------------------------------
view_log() { tail -f "$SUBSTORE_DIR/substore.log"; }
view_mihomo_log() { tail -f "$MIHOMO_DIR/mihomo.log"; }

#------------------------------------------------
# 主逻辑
#------------------------------------------------
case "$1" in
    deploy)
        install_dependencies
        deploy_substore
        deploy_mihomo
        start_services
        setup_boot
        log_info "✅ 初次部署完成"
        ;;
    start) start_services ;;
    stop) stop_services ;;
    restart) restart_services ;;
    update)
        update_config
        update_rules
        update_geo
        update_core
        ;;
    update-config) update_config ;;
    update-rules) update_rules ;;
    update-geo) update_geo ;;
    update-core) update_core ;;
    log) view_log ;;
    log-mihomo) view_mihomo_log ;;
    *)
        echo "用法: $0 {deploy|start|stop|restart|update|update-config|update-rules|update-geo|update-core|log|log-mihomo}"
        exit 1
        ;;
esac
