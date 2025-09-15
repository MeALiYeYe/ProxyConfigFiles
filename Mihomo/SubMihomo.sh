#!/data/data/com.termux/files/usr/bin/bash
set -e

#================================================
# --- 脚本配置 ---
#================================================
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

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

#================================================
# --- 工具函数 ---
#================================================
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

get_arch() {
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
        aarch64) ARCH="arm64-v8a" ;;
        x86_64)  ARCH="x86_64" ;;
        *) log_error "不支持的架构: $ARCH_RAW" ;;
    esac
}

get_latest_vernesong_url() {
    local keyword="arm64-v8-alpha"
    curl -s "https://api.github.com/repos/vernesong/mihomo/releases" | \
    jq -r '.[] | .assets[] | select(.name | contains("'"$keyword"'")) | .browser_download_url' | head -n1
}

#================================================
# --- 安装流程 ---
#================================================
install_dependencies() {
    log_info "1️⃣ 安装依赖..."
    pkg up -y
    pkg i -y nodejs-lts wget unzip curl jq cronie termux-services
    sv-enable crond && sv up crond
    log_info "✅ 依赖安装完成。"
}

deploy_substore() {
    log_info "2️⃣ 部署 Sub-Store..."
    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"

    wget -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    wget -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend && rm -f dist.zip
    log_info "✅ Sub-Store 部署完成。"
}

deploy_mihomo() {
    log_info "3️⃣ 部署 Mihomo..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"

    local MIHOMO_URL
    MIHOMO_URL=$(get_latest_vernesong_url "mihomo-android-${ARCH}-alpha")
    if [ -z "$MIHOMO_URL" ]; then
        log_error "未找到合适的 Mihomo 下载链接。"
    fi

    wget -O mihomo.tar.gz "$MIHOMO_URL"

    # 解压处理
    if file mihomo.tar.gz | grep -q "gzip compressed"; then
        tar -xzf mihomo.tar.gz
        rm -f mihomo.tar.gz
    else
        gunzip -f mihomo.tar.gz
    fi

    chmod +x mihomo || true

    download_mihomo_assets
    log_info "✅ Mihomo 部署完成。"
}

download_mihomo_assets() {
    cd "$MIHOMO_DIR" || exit
    log_info "下载 config.yaml..."
    wget -O config.yaml "$CONFIG_URL"

    log_info "下载规则集..."
    mkdir -p rules
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest_path src_url <<< "$item"
        wget -O "$dest_path" "$src_url"
    done

    log_info "下载 Geo 数据..."
    mkdir -p geo
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest_path src_url <<< "$item"
        wget -O "$dest_path" "$src_url"
    done
}

#================================================
# --- 管理脚本 / 自动化 ---
#================================================
create_manager_script() {
    log_info "4️⃣ 创建管理脚本 ~/sub-mihomo.sh..."
    cat > "$HOME/sub-mihomo.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"

log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

start_substore() {
    cd "$SUBSTORE_DIR"
    if pgrep -f "sub-store.bundle.js" > /dev/null; then
        log_warn "Sub-Store 已在运行中。"
    else
        nohup node sub-store.bundle.js >> substore.log 2>&1 &
        log_info "✅ Sub-Store 已启动。"
    fi
}

start_mihomo() {
    cd "$MIHOMO_DIR"
    if pgrep -f "mihomo" > /dev/null; then
        log_warn "Mihomo 已在运行中。"
    else
        echo "---- 启动 Mihomo: $(date) ----" >> mihomo.log
        nohup ./mihomo -d . >> mihomo.log 2>&1 &
        log_info "✅ Mihomo 已启动。"
    fi
}

stop_substore() { pkill -f "sub-store.bundle.js" || true; log_info "✅ Sub-Store 已停止。"; }
stop_mihomo() { pkill -f "mihomo" || true; log_info "✅ Mihomo 已停止。"; }

update_all() {
    stop_substore
    cd "$SUBSTORE_DIR"
    wget -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    wget -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend && rm -f dist.zip
    start_substore

    stop_mihomo
    cd "$MIHOMO_DIR"
    # 更新配置和规则
    wget -O config.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml"
    mkdir -p rules geo
    wget -O rules/Direct.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Direct.yaml"
    wget -O rules/Reject.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Reject.yaml"
    wget -O rules/Proxy.yaml "https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Proxy.yaml"
    wget -O geo/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    wget -O geo/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    wget -O geo/Country.mmdb "https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb"
    wget -O geo/Country-asn.mmdb "https://github.com/Loyalsoldier/geoip/releases/latest/download/Country-asn.mmdb"
    start_mihomo
}

case "$1" in
    start) start_substore; start_mihomo ;;
    stop) stop_substore; stop_mihomo ;;
    restart) $0 stop; $0 start ;;
    update) update_all ;;
    log) tail -f "$SUBSTORE_DIR/substore.log" ;;
    log-mihomo) tail -f "$MIHOMO_DIR/mihomo.log" ;;
    *) echo "用法: $0 {start|stop|restart|update|log|log-mihomo}" ;;
esac
EOF
    chmod +x "$HOME/sub-mihomo.sh"
    log_info "✅ 管理脚本已创建。"
}

setup_automation() {
    log_info "5️⃣ 设置定时任务和开机自启..."
    (crontab -l 2>/dev/null | grep -v "sub-mihomo.sh update" ; echo "0 */12 * * * bash $HOME/sub-mihomo.sh update >> $HOME/update-cron.log 2>&1") | crontab -
    mkdir -p "$BOOT_SCRIPT_DIR"
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/sub-mihomo.sh" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"
    log_info "✅ 定时更新和开机自启设置完成。"
}

#================================================
# --- 主程序 ---
#================================================
main() {
    get_arch
    install_dependencies
    deploy_substore
    deploy_mihomo
    create_manager_script
    setup_automation
    bash "$HOME/sub-mihomo.sh" start
}

main
