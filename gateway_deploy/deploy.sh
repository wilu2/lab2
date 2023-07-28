#!/usr/bin/env bash
DEPLOY_PATH=$(realpath "$(dirname "$0")")
echo "当前部署脚本：$DEPLOY_PATH/deploy.sh"

if [ $# -eq 0 ]; then
  echo "1. 全量部署（首次部署）"
  echo "2. 增量部署（确保除本次部署的镜像，其它镜像都存在）"
  read -p "请选择当前部署的方式: " -n 1 deploy_type
  echo ""

  if [ "$deploy_type" != "1" ] && [ "$deploy_type" != "2" ]; then
    echo "无效的输入，请重新选择 1 或 2"
    exit 1
  fi
fi

# 全量部署，服务检查
if [ "$deploy_type" -eq 1 ]; then
  # 检查 Docker 是否安装
  if ! command -v docker >/dev/null 2>&1; then
      echo "Docker 未安装"
      exit 1
  fi

  # 检查 Docker Compose 是否安装
  if ! command -v docker-compose >/dev/null 2>&1; then
      echo "Docker Compose 未安装"
      exit 1
  fi
  echo -e "\033[36m===================核对服务器时间================\033[0m"
  echo $(date +"%Y-%m-%d %H:%M:%S %Z")
fi

echo -e "\033[36m==============阶段一：docker 加载镜像============\033[0m"

if [ -n "$(find $DEPLOY_PATH/images -maxdepth 1 -type f -name '*.tar')" ]; then
  # 如果有 .tar 文件，遍历每个文件并加载镜像
  for file in $DEPLOY_PATH/images/*.tar; do
    echo "加载镜像文件: $file"
    docker load -i "$file"
  done
else
  echo "本次未更新镜像文件"
fi
sleep 0.5

echo -e "\033[36m==============阶段二：设置环境变量===============\033[0m"
read -p "请输入数据挂载的目录，推荐使用绝对路径（默认：/data/gateway）：" db_prefix
if [ -z "$db_prefix" ]; then
  db_prefix="/data/gateway"
fi
sleep 0.5


use_history=false
if [ ! -d "$db_prefix" ]; then
  if [ "$deploy_type" -eq 1 ]; then # 当前为全量部署
    read -p "目录不存在需要创建 $db_prefix 目录。[y/n]（默认：y）" confirm
    if [ "$confirm" == "Y" ] || [ "$confirm" == "y" ] || [ "$confirm" == "" ]; then
      mkdir -p "$db_prefix"
    fi
  else  # 当前为增量部署
    read -p "目录不存在，本次为增量部署请指定正确目录：" db_prefix
  fi
else
  if [ "$deploy_type" -eq 1 ]; then
    read -p "本次为全量部署，指定目录已存在，是否使用 $db_prefix 目录里的数据。[y/n]（默认：y）" confirm
    if [ "$confirm" == "Y" ] || [ "$confirm" == "y" ] || [ "$confirm" == "" ]; then
      use_history=true
      echo "请注意将使用 $db_prefix 目录里的历史数据！！！"
    else
      backup_dir="${db_prefix}_backup_$(date +'%Y%m%d%H%M%S')" # 拼接备份目录名
      echo "备份 $db_prefix 目录里的数据到 ${backup_dir}，请前往目录手动删除！！！"
      mv --backup=numbered ${db_prefix} ${backup_dir}
      mkdir -p $db_prefix
    fi
  fi
fi
sleep 0.5

for subdir in "data/postgres" "logs/body-logger" "logs/control-panel"; do
  fullpath="$db_prefix/$subdir"
  if [ ! -d "$fullpath" ]; then
    mkdir -p "$fullpath"
  fi
done

files=("apisix.yaml" "init-route.yaml" "logs/control-panel/access.log" "logs/control-panel/error.log")

for file in "${files[@]}"; do
  if [ ! -f "$db_prefix/$file" ]; then
    touch "$db_prefix/$file"
    if [ "$file" == "apisix.yaml" ] || [ "$file" == "init-route.yaml" ]; then
      chmod 777 "$db_prefix/$file"
    fi
  fi
done


# 检查子目录是否存在，以及检查目录的权限是否正确
directories=("data/postgres" "logs/body-logger" "logs/control-panel")
error_message=""

for dir in "${directories[@]}"; do
  if [ ! -d "$db_prefix/$dir" ]; then
    error_message="${error_message}目录 ${dir} 不存在\n"
  elif [ "$dir" == "logs/body-logger" ] || [ "$dir" == "logs/control-panel" ]; then
      if [ "$(stat -c %a $db_prefix/$dir)" != "777" ]; then
        chmod -R 777 "$db_prefix/$dir"
        echo "目录 $db_prefix/$dir 权限不足，已添加 777 权限"
      fi
  fi
done

# 检查这两个配置目录的权限为 777 防止部署出问题
directories=("conf" "plugins")
for dir in "${directories[@]}"; do
  if [ ! -d "$DEPLOY_PATH/$dir" ]; then
    error_message="${error_message}目录 ${dir} 不存在\n"
  else
      if [ "$(stat -c %a $DEPLOY_PATH/$dir)" != "777" ]; then
        chmod -R 777 "$DEPLOY_PATH/$dir"
        echo "目录 $DEPLOY_PATH/$dir 权限不足，已添加 777 权限"
      fi
  fi
done

if [ ! -z "$error_message" ]; then
  echo -e "脚本执行过程中发现以下问题：\n$error_message"
fi
# 替换 .env 的 DB_PREFIX=.
sed -i "s#^DB_PREFIX=.*#DB_PREFIX=${db_prefix}#g" "$DEPLOY_PATH/.env"

sleep 0.5
read -p "请输入管理平台部署的IP地址（例如：127.0.0.1）：" gateway_host
sed -i "s/^CONTROL_PANEL_HOST=.*/CONTROL_PANEL_HOST=${gateway_host}/g" $DEPLOY_PATH/.env

sleep 0.5
read -p "请输入管理平台部署的端口（默认: 9080）：" gateway_port
if [ -z "$gateway_port" ]; then
  gateway_port=9080
fi
sed -i "s/^CONTROL_PANEL_PORT=.*/CONTROL_PANEL_PORT=${gateway_port}/g" $DEPLOY_PATH/.env

sleep 0.5
read -p "请输入管理平台前端的地址（默认：$gateway_host:32380）：" gateway_web_address
if [ -z "$gateway_web_address" ]; then
  gateway_web_address="${gateway_host}:32380"
fi
sed -i "s/^ROUTE_GATEWAY_WEB_ADDRESS=.*/ROUTE_GATEWAY_WEB_ADDRESS=${gateway_web_address}/g" $DEPLOY_PATH/.env

sleep 0.5
read -p "请输入管理平台后端的地址（默认：$gateway_host:8080）：" gateway_backend_address
if [ -z "$gateway_backend_address" ]; then
  gateway_backend_address="${gateway_host}:8080"
fi
sed -i "s/^ROUTE_GATEWAY_BACKEND_ADDRESS=.*/ROUTE_GATEWAY_BACKEND_ADDRESS=${gateway_backend_address}/g" $DEPLOY_PATH/.env

echo -e "\033[36m==============阶段三：停止旧服务=================\033[0m"
compose_file=$(docker container inspect --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}' textin-gateway-control-panel)

if [ -z "$compose_file" ]; then
    echo "当前管理平台未使用 docker-compose 部署"
else
    echo "正在停止容器..."
    docker-compose -f $compose_file down
fi

echo -e "\033[36m==============阶段四：启动新服务=================\033[0m"
docker-compose -f $DEPLOY_PATH/docker-compose.yml up -d

echo "管理平台访问地址：http://${gateway_host}:${gateway_port}/textin_gateway/login"
echo "默认账号：admin"
echo "默认密码：12345678"
