执行
bash <(curl -sL https://raw.githubusercontent.com/MeALiYeYe/ProxyConfigFiles/refs/heads/main/Mihomo/Manage.sh) $( [ ! -d "$HOME/substore" ] || [ ! -d "$HOME/mihomo" ] && echo "deploy" || echo "update" )
以拉取并执行Manage.sh，
Manage.sh可以用SubMihomo.sh部署substore和mihomo
