# 管理平台部署文档

## 组件依赖

1. `textin-gateway-postgres`: 管理平台后端用户创建的数据。
2. `textin-gateway-control-panel`: `apisix` 管理端
3. `textin-gateway-data-panel`: 管理平台后台
4. `textin-gateway-web`: 管理平台前端

## 项目版本命令
项目发布的部署外链，以及内部版本 `git tag` 都沿用改标准，便于自动化构建。

`1.1.1.230523_RC`：主版本号.子版本号.阶段版本号.日期版本号.希腊字母版本号（希腊字母版本号共有5种：base、alpha、beta、RC、release）

`Base`版 - 假页面链接，具备基础架构，但没有完成功能实现。
`Alpha`版 - 软件初级版本，仅用于开发者内部交流，存在较多bug和需要改进的地方。
`Beta`版 - 相较于Alpha版有很大改进，消除了严重错误，但仍存在缺陷。主要目标是UI的修改。
`RC`版 - 最终测试版，成熟度高，bug相对较少。可能成为最终产品的候选版本。
`Release`版 - 最终版本，交付给用户使用的版本。也称为标准版本。

若有多个客户发布标准为：主版本号.子版本号.阶段版本号.日期版本号.希腊字母版本号.字母

* 北部湾(a)：`1.1.1.230523_base_a`
* 江西银行(b)：`1.1.1.230523_base_b`
* 黄河农商(c)：`1.1.1.230523_base_c`
* 长安汽车(d)：`1.1.1.230523_base_d`

### 项目目录

```shell
├── build                          // Dockerfile 文件
├── gateway_deploy                 // 管理平台部署文档
├── pack                           // 自动化打包部署
├── README.md
```

## 项目打包

当前版本打 `tag` 然后执行 `ci`

* `pack-all-image`：全量镜像，和 `gateway_deploy`
* `pack-bulk-image`：相对于上个 `tag` 的增量镜像，和 `gateway_deploy`
* `pack-deploy`：只打包 `gateway_deploy`
