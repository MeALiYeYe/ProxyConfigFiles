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
# 部署 SubMihomo.sh 脚本
#------------------------------------------------
deploy_submihomo() {
    log_info "下载 SubMihomo.sh..."
    curl -L https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/SubMihomo.sh -o "$SUB_MIHOMO_SCRIPT"
    chmod +x "$SUB_MIHOMO_SCRIPT"
    log_info "SubMihomo.sh 已下载并赋予可执行权限"
}

#------------------------------------------------
# 执行 SubMihomo.sh 部署
#------------------------------------------------
deploy_services() {
    bash "$SUB_MIHOMO_SCRIPT" deploy
}

#------------------------------------------------
# 服务管理
#------------------------------------------------
start_services() { bash "$SUB_MIHOMO_SCRIPT" start; }
stop_services() { bash "$SUB_MIHOMO_SCRIPT" stop; }
restart_services() { bash "$SUB_MIHOMO_SCRIPT" restart; }
update_services() { bash "$SUB_MIHOMO_SCRIPT" update; }

view_log() { tail -f "$SUBSTORE_DIR/substore.log"; }
view_mihomo_log() { tail -f "$MIHOMO_DIR/mihomo.log"; }

#------------------------------------------------
# 主逻辑
#------------------------------------------------
case "$1" in
    deploy)
        if is_deployed; 键，然后
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
    *) echo "用法: $0 {deploy|start|stop|restart|update|log|log-mihomo}"; exit 1 ;;
esac
