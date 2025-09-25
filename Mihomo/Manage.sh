#!/data/data/com.termux/files/usr/bin/bash
set -e

#------------------------------------------------
# Termux 自身使用代理 (防止 GitHub API、wget 受限)
#------------------------------------------------
# export all_proxy="socks5://127.0.0.1:7890"

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

# 本脚本链接
SHELL_URL="https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Manage.sh"

# Mihomo 核心下载链接 & config
MIHOMO_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/vernesong/mihomo/releases/tags/Prerelease-Alpha \
  | grep "browser_download_url" \
  | grep "android-arm64-v8-alpha-smart" \
  | grep "\.gz" \
  | cut -d '"' -f 4)

# mihomo远程配置链接
CONFIG_URL="https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Alpha/config.yaml"

# 规则集下载链接
RULES_SOURCES=(
    "rules/Redirect.yaml,https://raw.githubusercontent.com/SunsetMkt/anti-ip-attribution/refs/heads/main/generated/rule-provider.yaml"
    "rules/Direct.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Direct.yaml"
    "rules/Reject.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Reject.yaml"
    "rules/Proxy.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Proxy.yaml"
    "rules/Emby.yaml,https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/rule/Emby.yaml"
    "rules/AWAvenue.mrs,https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/refs/heads/main/Filters/AWAvenue-Ads-Rule-Clash.mrs"
)

# Geo 数据
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
# 检查部署状态
#------------------------------------------------
is_deployed() {
    [[ -d "$SUBSTORE_DIR" && -d "$MIHOMO_DIR" && -f "$MIHOMO_DIR/mihomo" ]]
}

# 确保 $HOME/bin 存在
mkdir -p "$HOME/bin"

#------------------------------------------------
# 安装依赖
#------------------------------------------------
install_dependencies() {
    log_info "安装依赖..."
    pkg up -y
    pkg i -y nodejs-lts wget unzip curl jq cronie termux-services

    # 确保服务目录存在
    mkdir -p "$PREFIX/var/service"

    # 尝试启用 crond
    if command -v sv-enable >/dev/null 2>&1; then
        sv-enable crond 2>/dev/null || log_warn "无法启用 crond 服务，可能 termux-services 未正确初始化"
        sv up crond 2>/dev/null || log_warn "无法启动 crond 服务"
    else
        log_warn "sv-enable 命令不存在，跳过 crond 启动"
    fi

    log_info "依赖安装完成"
}

#------------------------------------------------
# 部署 Sub-Store
#------------------------------------------------
deploy_substore() {
    log_info "部署 Sub-Store..."
    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"
    wget -q --show-progress -O sub-store.bundle.js "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
    wget -q --show-progress -O dist.zip "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
    unzip -o dist.zip -d dist && rm -f dist.zip
    log_info "Sub-Store 部署完成"
}

#------------------------------------------------
# 部署 Mihomo
#------------------------------------------------
deploy_mihomo() {
    log_info "部署 Mihomo..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"

    if [ -z "$MIHOMO_DOWNLOAD_URL" ]; then
        log_error "无法获取 Mihomo 下载链接，跳过部署"
    fi

    wget -q --show-progress -O mihomo.gz "$MIHOMO_DOWNLOAD_URL" || log_error "下载 Mihomo 核心失败"
    gunzip -f mihomo.gz

    if [ -f mihomo ]; then
        chmod +x mihomo
    elif ls mihomo-* 1> /dev/null 2>&1; then
        mv mihomo-* mihomo
        chmod +x mihomo
    else
        log_error "Mihomo 核心文件不存在，部署失败"
    fi

    download_assets
    log_info "Mihomo 部署完成"
}

#------------------------------------------------
# 下载配置、规则和 Geo 数据
#------------------------------------------------
download_assets() {
    mkdir -p "$MIHOMO_DIR/rules" "$MIHOMO_DIR/geo"
    cd "$MIHOMO_DIR"
    wget -q --show-progress -O config.yaml "$CONFIG_URL"

    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -q --show-progress -O "$dest" "$src" || { log_error "下载失败: $src"; return 1; }
    done

    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -q --show-progress -O "$dest" "$src" || { log_error "下载失败: $src"; return 1; }
    done
}

#------------------------------------------------
# 服务管理
#------------------------------------------------
start_substore() {
    log_info "启动 Sub-Store..."
    cd "$SUBSTORE_DIR"
    if ! pgrep -f "sub-store.bundle.js" > /dev/null; then
        nohup node sub-store.bundle.js >> "$SUBSTORE_DIR/substore.log" 2>&1 &
    else
        log_warn "Sub-Store 已在运行"
    fi
}

stop_substore() {
    pkill -f "sub-store.bundle.js" || true
    log_info "Sub-Store 已停止"
}
restart_substore() {
    stop_substore
    start_substore
}

start_mihomo() {
    log_info "启动 Mihomo..."
    cd "$MIHOMO_DIR"
    if ! pgrep -f "mihomo" > /dev/null; then
        nohup ./mihomo -d . >> "$MIHOMO_DIR/mihomo.log" 2>&1 &
    else
        log_warn "Mihomo 已在运行"
    fi
}

stop_mihomo() {
    pkill -f "mihomo" || true
    log_info "Mihomo 已停止"
}

restart_mihomo() {
    stop_mihomo
    start_mihomo
}

#------------------------------------------------
# 更新功能
#------------------------------------------------
update_self() {
    log_info "更新 Manage.sh..."
    cd "$HOME/bin"
    wget -q --show-progress -O Manage.sh "$SHELL_URL" || log_error "下载失败: $SHELL_URL"
    chmod +x Manage.sh
    log_info "Manage.sh 已更新完成，请重新执行命令"
}

update_substore() { stop_substore; deploy_substore; start_substore; }
update_mihomo() { stop_mihomo; deploy_mihomo; start_mihomo; }

update_rules() {
    log_info "更新规则集..."
    mkdir -p "$MIHOMO_DIR/rules"
    cd "$MIHOMO_DIR"
    for item in "${RULES_SOURCES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -q --show-progress -O "$dest" "$src" || log_error "下载失败: $src"
    done
    log_info "规则集更新完成"
}

update_geo() {
    log_info "更新 Geo 数据..."
    mkdir -p "$MIHOMO_DIR/geo"
    cd "$MIHOMO_DIR"
    for item in "${GEO_FILES[@]}"; do
        IFS=',' read -r dest src <<< "$item"
        wget -q --show-progress -O "$dest" "$src" || log_error "下载失败: $src"
    done
    log_info "Geo 数据更新完成"
}

update_config() {
    log_info "更新 config.yaml..."
    cd "$MIHOMO_DIR"
    wget -q --show-progress -O config.yaml "$CONFIG_URL"
    log_info "config.yaml 更新完成"
}

update_mihomo_core() {
    log_info "更新 Mihomo 核心..."
    cd "$MIHOMO_DIR"

    if [ -z "$MIHOMO_DOWNLOAD_URL" ]; then
        log_error "无法获取 Mihomo 下载链接，跳过更新"
    fi

    wget -q --show-progress -O mihomo.gz "$MIHOMO_DOWNLOAD_URL"
    gunzip -f mihomo.gz
    if [ -f mihomo ]; then
        chmod +x mihomo
    elif ls mihomo-* 1> /dev/null 2>&1; then
        mv mihomo-* mihomo
        chmod +x mihomo
    else
        log_error "Mihomo 核心文件不存在，更新失败"
    fi
    log_info "Mihomo 核心更新完成"
}

#------------------------------------------------
# 日志查看
#------------------------------------------------
view_substore_log() { tail -f "$SUBSTORE_DIR/substore.log"; }
view_mihomo_log() { tail -f "$MIHOMO_DIR/mihomo.log"; }

#------------------------------------------------
# 主逻辑
#------------------------------------------------
if [ "$1" = "deploy" ]; then
    if is_deployed; then
        log_warn "系统已部署过，如需重新部署请先删除 $SUBSTORE_DIR 和 $MIHOMO_DIR"
        exit 0
    else
        install_dependencies
        deploy_substore
        deploy_mihomo
        start_substore
        start_mihomo
        setup_boot
        # ✅ 部署后为 Termux 设置代理环境变量
        {
            echo 'export all_proxy="socks5://127.0.0.1:7890"'
        } >> "$HOME/.bashrc"
        log_info "已将 Termux 自身代理写入 ~/.bashrc"
        log_info "✅ 首次部署完成"
        exit 0
    fi
fi

case "$1" in
    deploy_substore) [ -d "$SUBSTORE_DIR" ] && log_warn "Sub-Store 已存在" || deploy_substore ;;
    deploy_mihomo) [ -d "$MIHOMO_DIR" ] && log_warn "Mihomo 已存在" || deploy_mihomo ;;
    start_substore) start_substore ;;
    stop_substore) stop_substore ;;
    restart_substore) restart_substore ;;
    start_mihomo) start_mihomo ;;
    stop_mihomo) stop_mihomo ;;
    restart_mihomo) restart_mihomo ;;
    update_self) update_self ;;
    update_substore) update_substore ;;
    update_mihomo) update_mihomo ;;
    update_rules) update_rules ;;
    update_geo) update_geo ;;
    update_config) update_config ;;
    update_mihomo_core) update_mihomo_core ;;
    log_substore) view_substore_log ;;
    log_mihomo) view_mihomo_log ;;
    start) start_substore; start_mihomo ;;
    stop) stop_substore; stop_mihomo ;;
    restart) restart_substore; restart_mihomo ;;
    update)
        update_self
        update_substore
        update_mihomo
        update_rules
        update_geo
        update_config
        update_mihomo_core
        ;;
    *)
        echo "用法: $0 {deploy|deploy_substore|deploy_mihomo|start_substore|stop_substore|restart_substore|start_mihomo|stop_mihomo|restart_mihomo|update_self|update_substore|update_mihomo|update_rules|update_geo|update_config|update_mihomo_core|log_substore|log_mihomo|start|stop|restart|update}"
        exit 1
        ;;
esac

#------------------------------------------------
# 确保 $HOME/bin 在 PATH 中
#------------------------------------------------
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/bin:$PATH"
    log_info "已将 \$HOME/bin 添加到 PATH"
fi

#------------------------------------------------
# 开机自启 (依赖 Termux:Boot 插件)
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR"

    cat > "$BOOT_SCRIPT_DIR/start-services.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
export PATH="\$HOME/bin:\$PATH"
bash "$HOME/bin/Manage.sh" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"

    log_info "✅ 已设置开机自启: $BOOT_SCRIPT_DIR/start-services.sh"
}
