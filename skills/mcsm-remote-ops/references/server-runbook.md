# 服务器运维参考

## 连接与对象槽位

```bash
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -p SSH_PORT ACCOUNT@HOST)
INSTANCE_DIR='INSTANCE_DIR'
DAEMON_CONTAINER='MCSM_DAEMON_CONTAINER'
MINECRAFT_CONTAINER='MINECRAFT_CONTAINER'
```

把值从当前会话或用户声明绑定一次。所有后续命令复用同一组槽位，避免连接错实例。MCSManager 节点密钥只允许由现有配置和进程消费，不输出到终端报告。

## 低停机设计

维护窗口前完成：

- 查版本、读 Wiki、分析源码和 ABI。
- 下载、编译、配置迁移、中文化和静态测试。
- 建立原始 JAR/配置/Paper 缓存备份。
- 把最终产物预上传到 `backups/<maintenance>/incoming/`。
- 校验 SHA1、ZIP/JAR 和 YAML。
- 写好并执行回滚 `--check`。

维护窗口内只允许：通知、保存、停止、移动旧文件、安装最终文件、启动、验收或立即回滚。

不要为了“看看能否加载”重启。插件依赖图、`plugin.yml`、类签名和配置应先离线确认。

## MCSManager 与 Docker

### Daemon 配置损坏

已观察到的故障链：Daemon 在覆盖 `data/Config/global.json` 时被退出码 137 强制终止，留下 0 字节文件；后续进程在 `JSON.parse` 阶段持续退出。

处理原则：

- 保留 0 字节原件作为证据。
- 用同版本 Daemon 生成默认结构，再恢复既有节点身份字段。
- 让守护脚本验证非空 JSON、必要字段类型和有效备份。
- 有效配置变化时用同目录临时文件加 `mv` 原子刷新备份。
- 当前配置损坏时先原子恢复，再尝试启动容器。
- 不在守护日志中打印 JSON 内容或节点密钥。

### 自动恢复冲突

宿主机可能同时存在：

- Docker `restart=always`。
- systemd MCSM 守护定时器。
- MCSManager 实例自动启动。
- Minecraft 容器 `AutoRemove=true`。

计划停服时必须暂时关闭会把 Daemon 拉起的守护，并把 Daemon 改为 `restart=no`。Minecraft 正常 `stop` 后可能直接消失，不能假定还能执行 `docker start MINECRAFT_CONTAINER`；应启动 Daemon，让它根据实例配置重建容器。

### 控制台输入

优先使用 MCSManager 的实例控制面。必须使用 `docker attach` 时：

- 始终使用 `--sig-proxy=false`，避免客户端信号传递给 Java。
- 普通 `timeout` 可能无法结束 attach 客户端；需要限时时使用明确的强制终止并核对残留进程。
- 发送 `stop` 后按容器消失或退出状态判断完成，不按 attach 的退出码判断。
- 收尾检查并结束残留 attach/SSH 客户端。

## Paper 插件升级

Paper 的 `.paper-remapped` 可能继续加载旧映射 JAR。替换源 JAR时同步移动同名映射缓存，只处理目标插件，不清空整个缓存目录。

检查四层事实：

1. 运行目录只有一个目标版本。
2. `.paper-remapped` 对应文件来自当前源 JAR。
3. 启动日志显示预期版本。
4. 真实依赖调用成功。

## 经济插件升级

### 数据不变量

- 保持货币 ID 不变，例如主货币、点券和绑定点券各自的既有 ID。
- 保持持久化键、Vault 服务、PAPI 标识和命令别名不变。
- 保持默认值、小数位、上限、可支付属性和格式不变。
- 不因价格工厂重名而改货币 ID；改 ID 会产生新的余额键。

### ABI 兼容

UltimateShop 等插件可能直接链接 EcoBits 的静态方法。升级前对消费方运行：

```bash
javap -classpath CONSUMER.jar -c -p CONSUMER_CLASS
javap -classpath PROVIDER.jar -p PROVIDER_CLASS
```

重点检查 descriptor，而不是只看方法名。Kotlin 增加默认参数后可能只生成四参数方法和 `$default` 帮助方法，旧 Java 插件仍会寻找三参数 JVM 签名并抛 `NoSuchMethodError`。使用最小兼容重载，并同时保留新版 API。

### 真实验证

插件显示 `Enabled` 只能证明生命周期入口没有立即退出。还要检查：

- UltimateShop 的 EcoBits hook。
- QuickShop 的 Vault 经济实现。
- Jobs、MyPet、ServiceIO 等消费者。
- 玩家实际买入和卖出。
- 可逆余额测试。

控制台读取旧 EcoBits 余额时，使用管理子命令 `ecobits get PLAYER CURRENCY`，而不是只允许玩家执行的 `balance`。旧语言文件可能让 `take` 只显示空前缀，因此必须再次读取余额确认实际扣款。

## 回滚要求

回滚必须：

- 有 `--check` 和 `--apply`。
- `--check` 在线验证原件、配置和 JAR 完整性，不修改运行状态。
- `--apply` 先确认 Daemon 和 Minecraft 都已停止。
- 把被撤回文件移动到时间戳快照，不直接删除。
- 恢复原始 JAR、配置和 Paper 缓存状态。
- 恢复 Daemon 重启策略和守护定时器。
- 等待完整启动并重复业务验证。

最终同时报告修改后行为和回滚行为；不要把备份目录当作已验证回滚，必须至少执行 `--check`。
