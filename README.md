# BackApp - 懒猫应用

基于 SSH 的备份自动化工具，替代自定义 Shell 脚本和 Cron 配置，二进制文件小于 50 MB。

## 📦 应用信息

- **名称**: BackApp
- **包名**: cloud.lazycat.app.backapp
- **版本**: 1.0.0
- **描述**: UI for Backup automation over SSH, replacing custom shell scripts and cron configurations
- **原始镜像**: ghcr.io/dennis960/backapp:latest

## 🚀 快速开始

### 1. 准备工作

确保已安装:
- [lzc-cli](https://developer.lazycat.cloud)
- Docker (用于本地测试)

### 2. 获取应用文件

```bash
# 下载或克隆此目录
cd backapp-lzcapp

# 确保所有文件存在
ls -la
# 应包含:
# - lzc-manifest.yml
# - lzc-build.yml
# - build.sh
# - icon.png (需要您提供 512x512 PNG 图标)
```

### 3. 查看应用信息

```bash
./build.sh
# 选择 5 - 查看应用信息
```

### 4. 本地构建和测试

```bash
# 构建应用
./build.sh
# 选择 1 - 构建应用

# 或直接执行
lzc-cli project build -o backapp-1.0.0.lpk

# 本地安装测试
lzc-cli app install backapp-1.0.0.lpk
```

### 5. 发布到懒猫应用商店

#### 方式一：一键发布（推荐）

```bash
./build.sh
# 选择 4 - 一键构建+镜像复制+发布
```

**一键发布流程：**
1. ✅ 初始构建（使用原始镜像）
2. ✅ 镜像复制到懒猫仓库
3. ✅ 自动更新 manifest
4. ✅ 重新构建（使用新镜像）
5. ✅ 发布到应用商店

#### 方式二：分步发布

```bash
# 步骤 1: 登录
lzc-cli appstore login

# 步骤 2: 构建
./build.sh
# 选择 1 - 构建应用

# 步骤 3: 复制镜像
./build.sh
# 选择 2 - 镜像复制

# 步骤 4: 手动更新 manifest
# 编辑 lzc-manifest.yml，将 image 更新为懒猫仓库地址

# 步骤 5: 重新构建
./build.sh
# 选择 1 - 构建应用

# 步骤 6: 发布
./build.sh
# 选择 3 - 发布到应用商店
```

## 📋 配置说明

### 服务配置

**单服务应用**: backapp

| 配置项 | 值 |
|--------|-----|
| 镜像 | ghcr.io/dennis960/backapp:latest |
| 端口 | 8080 (HTTP) |
| 工作目录 | /data |
| 重启策略 | unless-stopped |
| 健康检查 | /health 端点 |

### 持久化存储

| 容器路径 | 映射路径 | 用途 |
|---------|---------|------|
| /data | /lzcapp/var/backapp-data | 应用数据 |
| /var/backups/app | /lzcapp/var/backups/app | 备份数据 |
| /var/backups/archive | /lzcapp/var/backups/archive | 备份归档 |

### 访问方式

- **子域名**: `backapp.your-box.lazycat.cloud`
- **内部地址**: `http://backapp:8080`
- **健康检查**: `http://backapp:8080/health`

## 🔧 高级配置

### 修改端口

编辑 `lzc-manifest.yml`:

```yaml
application:
  subdomain: backapp
  upstreams:
    - location: /
      backend: http://backapp:8080/  # 修改此处

services:
  backapp:
    command: "-port=8080"  # 修改此处
```

### 调整资源限制

编辑 `lzc-manifest.yml`:

```yaml
services:
  backapp:
    cpu_shares: 512  # CPU 权重 (默认 512)
    mem_limit: 512M  # 内存限制 (默认 512M)
```

### 添加环境变量

如果 BackApp 支持环境变量配置：

```yaml
services:
  backapp:
    environment:
      - BACKUP_INTERVAL=3600
      - LOG_LEVEL=info
```

## 📁 文件结构

```
backapp-lzcapp/
├── lzc-manifest.yml      # 主配置文件
├── lzc-build.yml         # 构建配置
├── build.sh              # 自动化脚本
├── icon.png              # 应用图标 (512x512 PNG)
└── README.md             # 本说明文件
```

## 🎯 智能优化说明

### 简单应用优化

根据智能分析，BackApp 是一个**简单应用**，因此：
- ✅ **跳过** `lzc-deploy-params.yml` 生成
- ✅ **无需**用户配置参数
- ✅ **直接安装**即可使用

### v1.4.1+ 特性

- ✅ 使用 `healthcheck` 格式（兼容 Docker Compose）
- ✅ 使用 `upstreams` 配置路由（推荐）
- ✅ 包含 `min_os_version: 1.3.8`

## 🐛 常见问题

### Q: 镜像拷贝失败
A: 确保镜像 `ghcr.io/dennis960/backapp:latest` 可公开访问

### Q: 发布审核需要多久？
A: 通常 1-3 个工作日

### Q: 如何更新应用？
A:
1. 修改 `lzc-manifest.yml` 中的 `version`
2. 执行完整发布流程
3. 系统会自动更新现有应用

### Q: 本地测试找不到 lzc-cli？
A: 请先安装 LazyCat 开发工具包：https://developer.lazycat.cloud

## 📚 参考资料

- [LazyCat 开发者文档](https://developer.lazycat.cloud)
- [应用发布指南](https://developer.lazycat.cloud/docs/publish-app.html)
- [lzc-cli 使用说明](https://developer.lazycat.cloud/docs/lzc-cli.html)

## 📞 支持

如有问题，请参考：
- [LazyCat 官方论坛](https://forum.lazycat.cloud)
- [GitHub Issues](https://github.com/dennis960/backapp)

---

**生成时间**: 2025-12-28
**工具**: LazyCat App Publisher Skill v1.0
