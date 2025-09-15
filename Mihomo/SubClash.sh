#!/data/data/com.termux/files/usr/bin/bash
set -e

#================================================
# --- 脚本配置 ---
#================================================
# 目录配置
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

# Mihomo 配置文件及规则源 (集中管理，方便修改)
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
    "geo/Country.mmdb,https://github.com/Loyalsoldier/geoip/release/Country.mmdb"
    "geo/Country-asn.mmdb,https://github.com/Loyalsoldier/geoip/release/Country-asn.mmdb"
)

#================================================
# --- 核心函数 ---
#================================================

# 打印信息
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

# 获取架构
get_arch() {
    ARCH_RAW=$(uname -m)
    # 适配 vernesong 仓库的文件命名
    case "$ARCH_RAW" in
        aarch64) ARCH="arm64-v8a" ;; # vernesong 通常使用 arm64-v8a
        x86_64)  ARCH="x86_64" ;;    # vernesong 使用 x86_64
        *) log_error "不支持的架构: $ARCH_RAW" ;;
    esac
}

# 从 GitHub API 获取最新预发布版链接 (专为 vernesong/mihomo)
get_latest_vernesong_url() {
    local keyword=$1
    local url
    # GitHub API /releases 会按时间倒序排，第一个就是最新的，无论是不是预发布
    url=$(curl -s "https://api.github.com/repos/vernesong/mihomo/releases" | \
          jq -r ".[0].assets[] | select(.name | contains(\"$keyword\")) | .browser_download_url")
    if [ -z "$url" ]; then
        log_error "无法从 vernesong/mihomo 获取包含 '$keyword' 的最新版本链接。"
    fi
    echo "$url"
}

#================================================
# --- 安装流程 ---
#================================================

# 1. 安装依赖
install_dependencies() {
    log_info "1️⃣ 安装依赖..."
    pkg up -y
    pkg i -y nodejs-lts wget unzip curl jq cronie termux-services
    sv-enable crond && sv up crond
    log_info "✅ 依赖安装完成。"
}

# 2. 部署 Sub-Store
deploy_substore() {
    log_info "2️⃣ 部署 Sub-Store..."
    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"

    log_info "下载 Sub-Store 后端..."
    wget -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    
    log_info "下载 Sub-Store 前端..."
    wget -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend
    rm -f dist.zip
    log_info "✅ Sub-Store 部署完成。"
}

# 3. 部署 Mihomo
deploy_mihomo() {
    log_info "3️⃣ 部署 Mihomo (来源: vernesong/mihomo)..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"

    log_info "下载 Mihomo 核心 (架构: $ARCH)..."
    # 注意: vernesong 的文件名可能包含更多细节，我们用 mihomo-android-${ARCH} 作为关键词匹配
    local MIHOMO_URL=$(get_latest_vernesong_url "mihomo-android-${ARCH}")
    wget -O mihomo.gz "$MIHOMO_URL"
    gunzip mihomo.gz
    chmod +x mihomo
    
    log_info "下载 Mihomo 配置文件、规则和 Geo 数据..."
    download_mihomo_assets
    log_info "✅ Mihomo 部署完成。"
}

# 下载 Mihomo 资源的函数 (将被写入管理脚本)
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


# 4. 创建管理脚本
create_manager_script() {
    log_info "4️⃣ 创建管理脚本 sub-mihomo.sh..."
    cat > "$HOME/sub-mihomo.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
set -e
# --- 从主脚本生成的配置 ---
$(declare -p SUBSTORE_DIR MIHOMO_DIR BOOT_SCRIPT_DIR CONFIG_URL)
$(declare -p RULES_SOURCES GEO_FILES)
# --- 从主脚本生成的函数 ---
$(declare -f log_info log_warn log_error get_arch)
$(declare -f get_latest_vernesong_url)
$(declare -f download_mihomo_assets)

# --- 服务管理函数 ---
start_substore() {
    cd "\$SUBSTORE_DIR"
    if pgrep -f "sub-store.bundle.js" > /dev/null; then
        log_warn "Sub-Store 已在运行中。"
    else
        log_info "正在启动 Sub-Store..."
        nohup node sub-store.bundle.js > substore.log 2>&1 &
        sleep 1
        log_info "✅ Sub-Store 已启动。"
        log_info "👉 管理界面: https://sub-store.vercel.app/subs?api=http://127.0.0.1:3000"
    fi
}
start_mihomo() {
    cd "\$MIHOMO_DIR"
    if pgrep -f "mihomo -d" > /dev/null; then
        log_warn "Mihomo 已在运行中。"
    else
        log_info "正在启动 Mihomo..."
        nohup ./mihomo -d . > mihomo.log 2>&1 &
        sleep 1
        log_info "✅ Mihomo 已启动。"
        log_info "👉 管理面板: http://127.0.0.1:9090/ui"
    fi
}
stop_substore() {
    log_info "正在停止 Sub-Store..."
    pkill -f "sub-store.bundle.js" || true
    log_info "✅ Sub-Store 已停止。"
}
stop_mihomo() {
    log_info "正在停止 Mihomo..."
    pkill -f "mihomo -d" || true
    log_info "✅ Mihomo 已停止。"
}

# --- 升级函数 ---
update_all() {
    log_info "🔄 开始更新 Sub-Store..."
    stop_substore
    cd "\$SUBSTORE_DIR"
    wget -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    wget -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d frontend && rm -f dist.zip
    start_substore
    log_info "✅ Sub-Store 更新完成。"
    
    log_info "🔄 开始更新 Mihomo 配置..."
    stop_mihomo
    cd "\$MIHOMO_DIR"
    # 默认只更新配置文件。如需更新 Alpha 核心，请取消下面的注释
    # log_warn "正在更新 Mihomo Alpha 核心..."
    # get_arch
    # MIHOMO_URL=\$(get_latest_vernesong_url "mihomo-android-\${ARCH}")
    # wget -O mihomo.gz "\$MIHOMO_URL"
    # gunzip -f mihomo.gz && chmod +x mihomo
    download_mihomo_assets
    start_mihomo
    log_info "✅ Mihomo 更新完成。"
}

# --- 主逻辑 ---
case "\$1" in
    start) start_substore; start_mihomo ;;
    stop) stop_substore; stop_mihomo ;;
    restart) \$0 stop; \$0 start ;;
    update) update_all ;;
    log) log_info "Sub-Store 日志 (Ctrl+C 退出):"; tail -f "\$SUBSTORE_DIR/substore.log" ;;
    log-mihomo) log_info "Mihomo 日志 (Ctrl+C 退出):"; tail -f "\$MIHOMO_DIR/mihomo.log" ;;
    *) echo "使用方法: \$0 {start|stop|restart|update|log|log-mihomo}"; exit 1 ;;
esac
EOF
    chmod +x "$HOME/sub-mihomo.sh"
    log_info "✅ 管理脚本创建成功: ~/sub-mihomo.sh"
}

# 5. 设置定时任务和自启
setup_automation() {
    log_info "5️⃣ 设置定时任务和开机自启..."
    (crontab -l 2>/dev/null | grep -v "sub-mihomo.sh update" ; echo "0 4 * * * bash $HOME/sub-mihomo.sh update >> $HOME/update-cron.log 2>&1") | crontab -
    mkdir -p "$BOOT_SCRIPT_DIR"
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/sub-mihomo.sh" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"
    log_info "✅ 定时更新和开机自启设置完成。"
}

# --- 运行主程序 ---
main() {
    get_arch
    install_dependencies
    deploy_substore
    deploy_mihomo
    create_manager_script
    setup_automation

    log_info "\n🚀🚀🚀 全部署完成! 🚀🚀🚀"
    log_info "服务将在5秒后首次启动..."
    sleep 5
    bash "$HOME/sub-mihomo.sh" start
    log_info "\n管理服务请使用: bash ~/sub-mihomo.sh {start|stop|restart|update|...}"
}

main
