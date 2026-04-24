#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#------------------------------------------------
# 目录配置
#------------------------------------------------
SUBSTORE_DIR="$HOME/substore"
MIHOMO_DIR="$HOME/mihomo"
BOOT_SCRIPT_DIR="$HOME/.termux/boot"

SHELL_URL="https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/main/Mihomo/Mihogo/Manage.sh"

MIHOMO_URL="https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-android-arm64-v8-alpha-smart-1383218.gz"
CONFIG_URL="https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/main/Mihomo/OpenWRT/openclash.yaml"

# ⭐ 新增：SubStore版本文件
BACKEND_VER_FILE="$SUBSTORE_DIR/backend.version"
FRONTEND_VER_FILE="$SUBSTORE_DIR/frontend.version"

# ⭐ 新增：API
BACKEND_API="https://api.github.com/repos/sub-store-org/Sub-Store/releases/latest"
FRONTEND_API="https://api.github.com/repos/sub-store-org/Sub-Store-Front-End/releases/latest"

#------------------------------------------------
# 工具函数
#------------------------------------------------
log_info() { echo -e "\e[32m[INFO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

safe_wget() {
    local url="$1"
    local out="${2:-}"

    if [ -z "$out" ]; then
        # stdout模式，不输出日志
        wget --tries=5 --timeout=30 --retry-connrefused --waitretry=3 -qO- "$url"
    else
        log_info "下载: $url"
        wget --continue --tries=5 --timeout=30 --retry-connrefused --waitretry=3 -O "$out" "$url"
        [ -s "$out" ] || log_error "下载失败: $url"
    fi
}

# ⭐ 新增
get_latest_version() {
    wget -qO- "$1" | jq -r '.tag_name'
}

check_port() {
    local port=$1
    if command -v lsof >/dev/null && lsof -i:$port >/dev/null 2>&1; then
        log_error "端口 $port 已被占用"
    fi
}

get_mihomo_url() {
    wget -qO- https://api.github.com/repos/vernesong/mihomo/releases/tags/Prerelease-Alpha \
    | jq -r '.assets[] | select(.name | test("android-arm64.*alpha.*\\.gz")) | .browser_download_url' \
    | head -n 1
}

#------------------------------------------------
# 模型选择
#------------------------------------------------
choose_model() {
    local base_url="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model"

    echo "请选择 Mihomo Smart 模型："
    echo "1) 轻量模型（默认）"
    echo "2) 中等模型"
    echo "3) 最大模型（推荐高性能设备）"
    if read -t 10 -rp "输入选项 [1-3] (默认1): " choice; then
        echo ""
    else
        echo -e "\n超时未输入，使用默认选项 1"
        choice=1
    fi

    case "${choice:-1}" in
        1) model_file="Model.bin"; MODEL_NAME="轻量模型" ;;
        2) model_file="Model-middle.bin"; MODEL_NAME="中等模型" ;;
        3) model_file="Model-large.bin"; MODEL_NAME="最大模型" ;;
        *) model_file="Model.bin"; MODEL_NAME="轻量模型" ;;
    esac

    MODEL_URL="${base_url}/${model_file}"
    log_info "已选择: $MODEL_NAME"
}

#------------------------------------------------
# ⭐ 新增：回滚
#------------------------------------------------
rollback_backend() {
    [ -f "$SUBSTORE_DIR/sub-store.bundle.js.bak" ] && \
        mv "$SUBSTORE_DIR/sub-store.bundle.js.bak" "$SUBSTORE_DIR/sub-store.bundle.js"
}

rollback_frontend() {
    [ -d "$SUBSTORE_DIR/dist.bak" ] && {
        rm -rf "$SUBSTORE_DIR/dist"
        mv "$SUBSTORE_DIR/dist.bak" "$SUBSTORE_DIR/dist"
    }
}

#------------------------------------------------
# 检查部署
#------------------------------------------------
is_deployed() {
    [[ -d "$SUBSTORE_DIR" && -d "$MIHOMO_DIR" && -f "$MIHOMO_DIR/mihomo" ]]
}

mkdir -p "$HOME/bin"

#------------------------------------------------
# 安装依赖
#------------------------------------------------
install_dependencies() {
    log_info "安装依赖..."
    pkg update -y
    pkg install -y nodejs-lts wget unzip jq cronie termux-services lsof

    mkdir -p "$PREFIX/var/service"

    if command -v sv-enable >/dev/null 2>&1; then
        sv-enable crond 2>/dev/null || log_warn "无法启用 crond 服务"
        sv up crond 2>/dev/null || log_warn "无法启动 crond 服务"
    fi

    log_info "依赖安装完成"
}

#------------------------------------------------
# Sub-Store
#------------------------------------------------
deploy_substore() {
    log_info "部署 Sub-Store..."
    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"

    safe_wget "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js" "sub-store.bundle.js"
    safe_wget "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip" "dist.zip"

    rm -rf dist tmp_dist
    mkdir -p tmp_dist dist

    unzip -o dist.zip -d tmp_dist

    if [ -d "tmp_dist/dist" ]; then
        mv tmp_dist/dist/* dist/
    else
        mv tmp_dist/* dist/
    fi

    rm -rf dist.zip tmp_dist

    # ⭐ 写入版本
    get_latest_version "$BACKEND_API" > "$BACKEND_VER_FILE"
    get_latest_version "$FRONTEND_API" > "$FRONTEND_VER_FILE"

    log_info "Sub-Store 部署完成（已记录版本）"
}

start_substore() {
    log_info "启动 Sub-Store..."

    check_port 3000
    check_port 3001

    cd "$SUBSTORE_DIR"

    if ! pgrep -f "node .*sub-store.bundle.js" >/dev/null; then
        setsid env PORT=3000 node sub-store.bundle.js > substore.log 2>&1 &
        echo $! > substore.pid
    fi

    if ! command -v serve >/dev/null; then
        npm i -g serve
    fi

    if ! pgrep -f "serve .*3001" >/dev/null; then
        setsid serve "$SUBSTORE_DIR/dist" -l 3001 -s > frontend.log 2>&1 &
        echo $! > frontend.pid
    fi

    log_info "前端: http://127.0.0.1:3001"
    log_info "后端: http://127.0.0.1:3000"
}

stop_substore() {
    log_info "停止 Sub-Store..."
    [ -f "$SUBSTORE_DIR/substore.pid" ] && kill $(cat "$SUBSTORE_DIR/substore.pid") 2>/dev/null || true
    [ -f "$SUBSTORE_DIR/frontend.pid" ] && kill $(cat "$SUBSTORE_DIR/frontend.pid") 2>/dev/null || true

    pkill -f sub-store.bundle.js || true
    pkill -f "serve .*3001" || pkill -f "serve" || true
    log_info "Sub-Store 已停止（前后端）"
}

restart_substore() {
    stop_substore
    start_substore
}

#------------------------------------------------
# Mihomo
#------------------------------------------------
deploy_mihomo() {
    log_info "部署 Mihomo..."
    mkdir -p "$MIHOMO_DIR"
    cd "$MIHOMO_DIR"

    MIHOMO_API_URL=$(get_mihomo_url || true)

    if [ -z "${MIHOMO_API_URL:-}" ]; then
        MIHOMO_API_URL="$MIHOMO_URL"
        log_warn "使用备用 Mihomo 下载链接"
    fi

    safe_wget "$MIHOMO_API_URL" "mihomo.gz"
    gzip -t mihomo.gz || log_error "核心损坏"
    gunzip -f mihomo.gz

    chmod +x mihomo

    # ⭐ 模型选择
    choose_model
    safe_wget "$MODEL_URL" "Model.bin"

    safe_wget "$CONFIG_URL" "config.yaml"
}

start_mihomo() {
    log_info "启动 Mihomo..."
    cd "$MIHOMO_DIR"

    if ! pgrep -f "$MIHOMO_DIR/mihomo" >/dev/null; then
        setsid ./mihomo -d . > mihomo.log 2>&1 &
        echo $! > mihomo.pid
    fi
}

stop_mihomo() {
    [ -f "$MIHOMO_DIR/mihomo.pid" ] && kill $(cat "$MIHOMO_DIR/mihomo.pid") 2>/dev/null || true
    pkill -f "$MIHOMO_DIR/mihomo" || true
}

restart_mihomo() {
    stop_mihomo
    start_mihomo
}

#------------------------------------------------
# 更新
#------------------------------------------------
update_self() {
    log_info "更新 Manage.sh..."
    cd "$HOME/bin"

    TMP_FILE="Manage.sh.new"
    BACKUP_FILE="Manage.sh.bak"

    # 1️⃣ 下载到临时文件
    if safe_wget "$SHELL_URL" "$TMP_FILE"; then

        # 2️⃣ 校验文件是否有效（非空）
        if [ -s "$TMP_FILE" ]; then

            # ⭐ 新增：必须是脚本（检查 shebang）
            if ! head -n 1 "$TMP_FILE" | grep -q "^#!"; then
                log_error "下载内容异常（不是脚本，可能是HTML），已取消更新"
            fi

            # ⭐ 新增：防止HTML错误页
            if grep -qi "<html" "$TMP_FILE"; then
                log_error "下载内容包含HTML，更新中止"
            fi

            # 3️⃣ 备份旧版本
            [ -f Manage.sh ] && cp Manage.sh "$BACKUP_FILE"

            # 4️⃣ 替换
            mv "$TMP_FILE" Manage.sh
            chmod +x Manage.sh

            log_info "Manage.sh 已更新完成"

        else
            log_error "下载文件为空，更新失败"
        fi

    else
        log_error "下载失败，更新终止"
    fi
}

update_substore() {
    log_info "检查 Sub-Store 更新..."

    mkdir -p "$SUBSTORE_DIR"
    cd "$SUBSTORE_DIR"

    # 后端
    LATEST_BACKEND_VER=$(get_latest_version "$BACKEND_API")
    LOCAL_BACKEND_VER=$(cat "$BACKEND_VER_FILE" 2>/dev/null || true)

    if [ "$LATEST_BACKEND_VER" = "$LOCAL_BACKEND_VER" ] && [ -n "$LATEST_BACKEND_VER" ]; then
        log_info "后端已是最新版本"
    else
        log_info "更新后端 → $LATEST_BACKEND_VER"
        mv sub-store.bundle.js sub-store.bundle.js.bak 2>/dev/null || true

        if safe_wget "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js" "sub-store.bundle.js"; then
            echo "$LATEST_BACKEND_VER" > "$BACKEND_VER_FILE"
        else
            log_warn "后端更新失败，回滚"
            rollback_backend
        fi
    fi

    # 前端
    LATEST_FRONTEND_VER=$(get_latest_version "$FRONTEND_API")
    LOCAL_FRONTEND_VER=$(cat "$FRONTEND_VER_FILE" 2>/dev/null || true)

    if [ "$LATEST_FRONTEND_VER" = "$LOCAL_FRONTEND_VER" ] && [ -n "$LATEST_FRONTEND_VER" ]; then
        log_info "前端已是最新版本"
    else
        log_info "更新前端 → $LATEST_FRONTEND_VER"

        mv dist dist.bak 2>/dev/null || true

        safe_wget "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip" "dist.zip"

        rm -rf dist
        mkdir -p tmp_dist
        unzip -o dist.zip -d tmp_dist

        if [ -d "tmp_dist/dist" ]; then
            mv tmp_dist/dist/* dist/
        else
            mv tmp_dist/* dist/
        fi

        if [ $? -ne 0 ]; then
            log_warn "前端更新失败，回滚"
            rollback_frontend
        else
            echo "$LATEST_FRONTEND_VER" > "$FRONTEND_VER_FILE"
            rm -rf dist.bak
        fi

        rm -rf dist.zip tmp_dist
    fi

    start_substore
}

update_model() {
    log_info "更新模型..."
    cd "$MIHOMO_DIR"

    choose_model
    safe_wget "$MODEL_URL" "Model.bin"

    log_info "模型更新完成"
}

update_config() {
    log_info "更新 config.yaml..."
    cd "$MIHOMO_DIR"
    safe_wget "$CONFIG_URL" "config.yaml"
    log_info "config.yaml 更新完成"
}

update_mihomo_core() {
    log_info "更新 Mihomo 核心..."
    cd "$MIHOMO_DIR"

    MIHOMO_API_URL=$(get_mihomo_url || true)
    [ -z "${MIHOMO_API_URL:-}" ] && MIHOMO_API_URL="$MIHOMO_URL"

    safe_wget "$MIHOMO_API_URL" "mihomo.gz"
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
# 日志
#------------------------------------------------
view_substore_log() { tail -f "$SUBSTORE_DIR/substore.log"; }
view_mihomo_log() { tail -f "$MIHOMO_DIR/mihomo.log"; }

#------------------------------------------------
# 设置开机自启 (mihomo + substore)
# 依赖 Termux:Boot 插件
#------------------------------------------------
setup_boot() {
    mkdir -p "$BOOT_SCRIPT_DIR" "$HOME/bin"

    #------------------------------------------------
    # 写入启动脚本（Termux:Boot）
    #------------------------------------------------
    cat > "$BOOT_SCRIPT_DIR/start-services.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/bin/Manage.sh" start
EOF
    chmod +x "$BOOT_SCRIPT_DIR/start-services.sh"

    #------------------------------------------------
    # Boot 软链接（无需 rm，直接覆盖）
    #------------------------------------------------
    LINK_PATH="$BOOT_SCRIPT_DIR/Manage.sh"
    ln -sf "$HOME/bin/Manage.sh" "$LINK_PATH"

    #------------------------------------------------
    # 快捷命令 sm
    #------------------------------------------------
    SM_LINK="$HOME/bin/sm"
    ln -sf "$HOME/bin/Manage.sh" "$SM_LINK"

    #------------------------------------------------
    # PATH 防重复写入（关键）
    #------------------------------------------------
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "已写入 PATH 到 .bashrc"
    fi

    # 当前会话立即生效（不重复添加）
    case ":$PATH:" in
        *":$HOME/bin:"*) ;;
        *) export PATH="$HOME/bin:$PATH" ;;
    esac

    log_info "开机自启已设置"
    log_info "快捷命令: sm 已可用"
}

#------------------------------------------------
# 主逻辑
#------------------------------------------------
if [ "${1:-}" = "deploy" ]; then
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
        log_info "✅ 首次部署完成"
        exit 0
    fi
fi

#------------------------------------------------
# 交互菜单（无参数时触发）
#------------------------------------------------
if [ -z "${1:-}" ]; then
    echo "=============================="
    echo "   Manage.sh 管理菜单"
    echo "=============================="
    echo " 1) 部署全部 (deploy)"
    echo " 2) 启动全部 (start)"
    echo " 3) 停止全部 (stop)"
    echo " 4) 重启全部 (restart)"
    echo " 5) 更新全部 (update)"
    echo "------------------------------"
    echo " 6) 更新 Sub-Store"
    echo " 7) 更新 Mihomo 配置"
    echo " 8) 更新模型"
    echo " 9) 更新 Mihomo 核心"
    echo "------------------------------"
    echo "10) 查看 Sub-Store 日志"
    echo "11) 查看 Mihomo 日志"
    echo " 0) 退出"
    echo "=============================="

    read -rp "请输入选项: " choice

    case "$choice" in
        1) set -- deploy ;;
        2) set -- start ;;
        3) set -- stop ;;
        4) set -- restart ;;
        5) set -- update ;;
        6) set -- update_substore ;;
        7) set -- update_config ;;
        8) set -- update_model ;;
        9) set -- update_mihomo_core ;;
        10) set -- log_substore ;;
        11) set -- log_mihomo ;;
        0) exit 0 ;;
        *) echo "无效选项"; exit 1 ;;
    esac
fi

case "${1:-}" in
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
    update_config) update_config ;;
    update_model) update_model ;;
    update_mihomo_core) update_mihomo_core ;;
    log_substore) view_substore_log ;;
    log_mihomo) view_mihomo_log ;;
    start) start_substore; start_mihomo ;;
    stop) stop_substore; stop_mihomo ;;
    restart) restart_substore; restart_mihomo ;;
    update)
        update_self
        update_substore
        update_model
        update_config
        update_mihomo_core
      ;;
    *)
        echo "用法: $0 {deploy|deploy_substore|deploy_mihomo|start_substore|stop_substore|restart_substore|start_mihomo|stop_mihomo|restart_mihomo|update_self|update_substore|update_model|update_config|update_mihomo_core|log_substore|log_mihomo|start|stop|restart|update}"
        exit 1
        ;;
esac
