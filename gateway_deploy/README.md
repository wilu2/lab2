# 管理平台部署

```shell
├── conf                    # 服务依赖的配置文件
│  ├── control-panel        # apisix
│  │  └── config.yaml       # apisix 配置文件
│  └── data-panel           # 管理平台后端配置（建议持久化）
│     └── api-server.yaml   # 数据面板控制文件
├── deploy.sh               # 部署脚本（手动执行）
├── docker-compose.yml      # docker-compose 启动文件
├── images                  # 需要更新的镜像tar包
├── init                    # 当数据挂载目录为空时，会进行初始化脚本（无需手动执行）
│  └── postgres
├── plugins                 # apisix 插件挂载目录
├── script                  # 执行脚本
│  ├── delete_body.sh       # 清理 logs/body-logger 下的日志数据的脚本
│  └── password.sh          # 生成加密和解密结果的脚本
├── .env                    # docker-compose 变量配置
├── CHANGELOG.md            # 版本增量升级记录
└── README.md

# 数据挂载目录，默认：/data/gateway
# 查看 .env 文件中的 DB_PREFIX 变量，代表数据挂载的目录，一般不会变动。

├── data                    # 数据库挂载目录
│  └── postgres
├── logs                    # 日志数据
│  ├── body-logger          # 请求体和返回值的数据挂载路径
│  └── control-panel        # apisix 的日志路径
├── apisix.yaml             # apisix 配置路由文件，通过 data-panel 生成的文件，被 control-panel 使用
└── init-route.yaml         # 配置初始化路由，如果需要手动配置其他一些上游服务时，在该文件添加内容
```

# 部署前提

1. 本机需要有 `docker` 和 `docker-compose` 命令。
2. 需要校准本机时间，否则数据保存时间会有问题。

## docker-compose 安装
`wget https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-linux-x86_64 -O /usr/local/bin/docker-compose sudo chmod +x /usr/local/bin/docker-compose`


## Docker 服务

1. `textin-gateway-postgres`: 管理平台后端用户创建的数据。
2. `textin-gateway-control-panel`: `apisix` 管理端，基于 `nginx` 的二次开发。
3. `textin-gateway-data-panel`: 管理平台后台
4. `textin-gateway-web`: 管理平台前端

## 服务部署
在当前目录执行 `bash deploy.sh` 文件，按照提示依次执行。

注意：若不使用 `docker-compose` 或者机器分开部署数据库，请修改 `data-panel/api-server.yaml` 中的 `db.host`。

注意：`control-panel` 依赖 `data-panel` 生成的 `apisix.yaml` 文件，两个组件挂载需要部署在一起，共享挂载目录中的 `apisix.yaml` 文件。

* 服务登录地址：`http://{ip}:9080/textin_gateway/login`
* 默认账号 `admin` 默认密码 `12345678`
* 请求方式：`url` 为创建服务时定义的路径，`App_key,App_secret` 为应用管理定义的值。

1. 方式一 curl 通过 data-binary 二进制流

```shell
curl -X "POST" "http://{ip}:9080/ai/service/model/1114" \
     -H 'App_key: p4y3xhtbi435dgw7rfchawlh4jl9sco1' \
     -H 'App_secret: j88sh2ymwi3tibjoutmc2e9a3lv2243d' \
     --data-binary @"$(pwd)/{filename}"
```

2. 方式二 base64 图片内容
* 图片生成 `base64` 内容：`身份证.png > 身份证base64.txt`

```shell
curl -X "POST" "http://{ip}:9080/ai/service/model/1114" \
     -H 'App_key: p4y3xhtbi435dgw7rfchawlh4jl9sco1' \
     -H 'App_secret: j88sh2ymwi3tibjoutmc2e9a3lv2243d' \
     -H 'Content-Type: application/json' \
     -d $'{"file_base64": ""}'
```

## 多节点部署

在不考虑数据库高可用的情况下，需要将两台机器的 `${DB_PREFIX}/logs` 和 `${DB_PREFIX}/apisix.yaml` 文件进行数据共享。

## script 脚本使用

### delete-body.sh
该脚本用于删除 `logs/body-logger` 挂载目录下的数据，按照日期进行删除。
在执行脚本之前，请确保你有足够的权限来删除这些文件夹。

```shell
chmod +x delete-body.sh  # 授予文件执行权限
bash delete.sh 2023-06-25 2023-06-27 /data/gateway/logs/body-logger
已删除文件夹: /data/gateway/logs/body-logger/2023-06-25
已删除文件夹: /data/gateway/logs/body-logger/2023-06-26
已删除文件夹: /data/gateway/logs/body-logger/2023-06-27
```

### password.sh
如果在配置文件 `api-server.yaml` 中开启了 `password-encrypt: true` 代表，填入的密码都需要加密。

```shell
chmod +x password.sh
bash password.sh 'password@#!@123'
Encrypted: k@#!@89awhzzDvy
Decrypted: password@#!@123
```

## 自定义 apisix 初始化路由(非必需)

1. 首先在 `docker-compose.yaml` 文件的 `textin-gateway-data-panel` 添加环境变量。
2. 左边环境变量要 ROUTE 开头 ADDRESS 结尾。
3. 在 `init-route` 添加额外的环境配置。

## QA

注意：数据挂载路径查看 `.env` 文件的 `DB_PREFIX=/data/gateway`

### `textin-gateway-data-panel`
   * 日志排查：`docker logs -f textin-gateway-data-panel`
   * 服务状态检查：`curl http://127.0.0.1:8080/health`
   * 配置文件排查：`conf/data-panel/api-server.yaml`

### `textin-gateway-control-panel`
   * `docker` 日志排查：`docker logs -f textin-gateway-control-panel`
   * 挂载日志排查：`tail -f /data/gateway/logs/control-panel/error.log`
   * 配置文件排查：`conf/control-panel/config.yaml`

### 访问统计无法查看请求详情
   * 文件保存路径：`/data/gateway/logs/body-logger/`。
   * 查看对应请求 `ID` 是否存在对应 `req、resp` 结尾的文件，且查看文件的大小是否为 `0`
   * 将 `chrome` 的 `network` 查看请求的 `respone` 内容的格式，拍照提供给开发。


### 其他部署问题

- `docker-compose up -d` 出现错误

   具体错误日志：`ERROR: The Compose file './docker-compose.yml' is invalid because:`
   原因：`docker-compose` 的版本过低，请检查版本。

- `control-panel` 容器出现 `permission deined`

   具体错误日志: `error info:/usr/local/apisix/conf/nginx.conf: Permission denied`。

   需要用当前 `linux` 的用户重新 `docker rmi` 删除该容器镜像，然后 `docker load -i` 重新加载该镜像。

- `control-panel` 出现找不到 `plugins` 目录下的插件

   需要查看 `plugins` 目录下文件的权限，是不是 `775` 或者 `777`，如果不是，需要修改权限。

- `docker logs -f textin-gateway-postgres` 创建文件夹无权限

   结果：`mkdir: cannot create directory '/var/lib/postgresql/data': Permission denied`

   解决方法：需要给外部挂载目录 `${DB_PREFIX}/data/postgres` 文件夹 `777` 权限

- 使用 `base64` 方式请求调用，返回 `image format error` 错误。

  请检查 `base64` 的内容是否可以反解为图片格式 `base64 -d 身份证base64.txt > 身份证.png`
