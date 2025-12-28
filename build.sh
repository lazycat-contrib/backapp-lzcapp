#!/bin/bash
# BackApp 自动化构建和发布脚本
# 完整工作流：构建 → 镜像复制 → 发布

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 应用信息
APP_NAME="BackApp"
APP_PACKAGE="cloud.lazycat.app.backapp"
APP_VERSION="1.0.0"
IMAGE_ORIGINAL="ghcr.io/dennis960/backapp:latest"

# 文件检查
check_files() {
    echo -e "${BLUE}📁 检查必要文件...${NC}"

    local missing_files=()

    for file in "lzc-manifest.yml" "lzc-build.yml" "icon.png"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -ne 0 ]; then
        echo -e "${RED}❌ 缺少必要文件:${NC}"
        for file in "${missing_files[@]}"; do
            echo "   - $file"
        done
        exit 1
    fi

    echo -e "${GREEN}✅ 所有必要文件存在${NC}"
}

# 验证配置
validate_config() {
    echo -e "${BLUE}🔍 验证配置文件...${NC}"

    # 检查 manifest 格式
    if ! command -v yq &> /dev/null && ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}⚠️  跳过 YAML 语法验证（未安装 yq 或 python3）${NC}"
        return 0
    fi

    # 使用 yq 或 python 验证 YAML
    if command -v yq &> /dev/null; then
        if yq eval 'true' lzc-manifest.yml > /dev/null 2>&1; then
            echo -e "${GREEN}✅ lzc-manifest.yml 语法正确${NC}"
        else
            echo -e "${RED}❌ lzc-manifest.yml 语法错误${NC}"
            exit 1
        fi

        if yq eval 'true' lzc-build.yml > /dev/null 2>&1; then
            echo -e "${GREEN}✅ lzc-build.yml 语法正确${NC}"
        else
            echo -e "${RED}❌ lzc-build.yml 语法错误${NC}"
            exit 1
        fi
    elif command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('lzc-manifest.yml'))" 2>/dev/null && \
            echo -e "${GREEN}✅ lzc-manifest.yml 语法正确${NC}" || \
            echo -e "${YELLOW}⚠️  无法验证 lzc-manifest.yml 语法${NC}"

        python3 -c "import yaml; yaml.safe_load(open('lzc-build.yml'))" 2>/dev/null && \
            echo -e "${GREEN}✅ lzc-build.yml 语法正确${NC}" || \
            echo -e "${YELLOW}⚠️  无法验证 lzc-build.yml 语法${NC}"
    fi

    # 检查 v1.4.1+ 格式合规性
    echo -e "${BLUE}📋 检查 v1.4.1+ 格式...${NC}"

    if grep -q "lzc-sdk-version:" lzc-manifest.yml 2>/dev/null; then
        echo -e "${YELLOW}⚠️  发现旧格式字段 'lzc-sdk-version'，建议移除${NC}"
    fi

    if grep -q "min_os_version:" lzc-manifest.yml 2>/dev/null; then
        echo -e "${GREEN}✅ 包含 min_os_version 字段${NC}"
    else
        echo -e "${YELLOW}⚠️  建议添加 min_os_version: 1.3.8${NC}"
    fi

    if grep -q "healthcheck:" lzc-manifest.yml 2>/dev/null; then
        echo -e "${GREEN}✅ 使用 v1.4.1+ healthcheck 格式${NC}"
    fi
}

# 显示应用信息
show_info() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 应用信息${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "名称: ${GREEN}${APP_NAME}${NC}"
    echo -e "包名: ${GREEN}${APP_PACKAGE}${NC}"
    echo -e "版本: ${GREEN}${APP_VERSION}${NC}"
    echo -e "原始镜像: ${YELLOW}${IMAGE_ORIGINAL}${NC}"

    echo -e "\n${BLUE}📋 配置文件:${NC}"
    echo "  - lzc-manifest.yml (主配置)"
    echo "  - lzc-build.yml (构建配置)"
    echo "  - icon.png (应用图标)"

    echo -e "\n${BLUE}🔧 服务配置:${NC}"
    echo "  - 单服务应用: backapp"
    echo "  - 端口: 8080 (HTTP)"
    echo "  - 健康检查: /health"
    echo "  - 持久化存储: 3 个卷"

    echo -e "\n${BLUE}💾 存储路径:${NC}"
    echo "  - /lzcapp/var/backapp-data → /data"
    echo "  - /lzcapp/var/backups/app → /var/backups/app"
    echo "  - /lzcapp/var/backups/archive → /var/backups/archive"

    echo -e "\n${BLUE}📊 参数分析:${NC}"
    echo -e "  ${GREEN}✅${NC} 无敏感环境变量"
    echo -e "  ${GREEN}✅${NC} 无内部服务依赖"
    echo -e "  ${GREEN}✅${NC} 简单应用优化 - 跳过 lzc-deploy-params.yml"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 构建应用
build_app() {
    echo -e "${BLUE}🔨 构建应用...${NC}"

    # 检查 lzc-cli
    if ! command -v lzc-cli &> /dev/null; then
        echo -e "${RED}❌ 未找到 lzc-cli，请先安装${NC}"
        echo -e "${YELLOW}💡 安装参考: https://developer.lazycat.cloud${NC}"
        return 1
    fi

    # 执行构建
    local output_file="${APP_NAME,,}-${APP_VERSION}.lpk"
    echo -e "${YELLOW}执行: lzc-cli project build -o ${output_file}${NC}"

    if lzc-cli project build -o "$output_file"; then
        echo -e "${GREEN}✅ 构建成功!${NC}"
        echo -e "${GREEN}📦 输出文件: ${output_file}${NC}"

        if [ -f "$output_file" ]; then
            local size=$(ls -lh "$output_file" | awk '{print $5}')
            echo -e "${GREEN}📁 文件大小: ${size}${NC}"
        fi

        return 0
    else
        echo -e "${RED}❌ 构建失败${NC}"
        return 1
    fi
}

# 检查登录状态
check_login() {
    echo -e "${BLUE}🔐 检查登录状态...${NC}"

    if ! command -v lzc-cli &> /dev/null; then
        echo -e "${RED}❌ 未找到 lzc-cli${NC}"
        return 1
    fi

    # 使用 my-images 命令检查登录状态
    if lzc-cli appstore my-images &> /dev/null 2>&1; then
        echo -e "${GREEN}✅ 已登录懒猫应用商店${NC}"
        return 0
    else
        echo -e "${RED}❌ 未登录懒猫应用商店${NC}"
        echo -e "${YELLOW}💡 请先执行: lzc-cli appstore login${NC}"
        return 1
    fi
}

# 拷贝镜像到懒猫仓库
copy_image() {
    echo -e "\n${BLUE}📤 拷贝镜像到懒猫仓库...${NC}"

    if ! check_login; then
        return 1
    fi

    echo -e "${YELLOW}原始镜像: ${IMAGE_ORIGINAL}${NC}"
    echo -e "${YELLOW}执行: lzc-cli appstore copy-image ${IMAGE_ORIGINAL}${NC}"
    echo ""

    # 执行镜像拷贝
    if lzc-cli appstore copy-image "$IMAGE_ORIGINAL"; then
        echo -e "${GREEN}✅ 镜像拷贝成功${NC}"

        # 从输出中提取新镜像地址
        # 实际执行时会显示类似:
        # uploaded:  registry.lazycat.cloud/czyt/dennis960/backapp:HASH

        echo -e "${YELLOW}💡 请手动更新 lzc-manifest.yml 中的镜像地址${NC}"
        echo -e "${YELLOW}   将 image: ${IMAGE_ORIGINAL}${NC}"
        echo -e "${YELLOW}   更新为 image: registry.lazycat.cloud/你的用户名/...${NC}"

        return 0
    else
        echo -e "${RED}❌ 镜像拷贝失败${NC}"
        return 1
    fi
}

# 自动更新 manifest 中的镜像
update_manifest_image() {
    echo -e "${BLUE}🔄 自动更新 manifest 镜像...${NC}"

    if [ ! -f "lzc-manifest.yml" ]; then
        echo -e "${RED}❌ 未找到 lzc-manifest.yml${NC}"
        return 1
    fi

    # 检查是否需要更新
    if grep -q "ghcr.io/dennis960/backapp:latest" lzc-manifest.yml; then
        echo -e "${YELLOW}⚠️  Manifest 仍使用原始镜像${NC}"
        echo -e "${YELLOW}   请先执行镜像拷贝，然后手动更新${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Manifest 已更新为懒猫仓库镜像${NC}"
    return 0
}

# 发布到应用商店
publish_app() {
    echo -e "\n${BLUE}📤 发布到应用商店...${NC}"

    if ! check_login; then
        return 1
    fi

    # 检查镜像是否已更新
    if grep -q "ghcr.io/dennis960/backapp:latest" lzc-manifest.yml; then
        echo -e "${RED}❌ 请先更新镜像到懒猫仓库${NC}"
        echo -e "${YELLOW}   1. 执行镜像拷贝${NC}"
        echo -e "${YELLOW}   2. 手动更新 lzc-manifest.yml${NC}"
        echo -e "${YELLOW}   3. 重新构建${NC}"
        return 1
    fi

    local lpk_file="${APP_NAME,,}-${APP_VERSION}.lpk"

    if [ ! -f "$lpk_file" ]; then
        echo -e "${RED}❌ 未找到构建文件: ${lpk_file}${NC}"
        echo -e "${YELLOW}💡 请先执行构建${NC}"
        return 1
    fi

    echo -e "${YELLOW}执行: lzc-cli appstore publish ${lpk_file}${NC}"
    echo ""

    if lzc-cli appstore publish "$lpk_file"; then
        echo -e "${GREEN}✅ 发布成功!${NC}"
        echo -e "${GREEN}📝 等待审核 (1-3 天)${NC}"
        return 0
    else
        echo -e "${RED}❌ 发布失败${NC}"
        return 1
    fi
}

# 一键发布流程
one_click_publish() {
    echo -e "\n${BLUE}🚀 一键构建+镜像复制+发布${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # 阶段 1: 初始构建
    echo -e "${BLUE}阶段 1: 初始构建（原始镜像）${NC}"
    if ! build_app; then
        echo -e "${RED}❌ 阶段 1 失败${NC}"
        return 1
    fi

    # 阶段 2: 镜像复制
    echo -e "\n${BLUE}阶段 2: 镜像复制（需要手动更新 manifest）${NC}"
    if ! copy_image; then
        echo -e "${RED}❌ 阶段 2 失败${NC}"
        return 1
    fi

    echo -e "\n${YELLOW}⚠️  重要: 请手动编辑 lzc-manifest.yml，将镜像地址更新为懒猫仓库地址${NC}"
    echo -e "${YELLOW}   更新后保存文件，然后按 Enter 继续...${NC}"
    read -r

    # 阶段 3: 重新构建
    echo -e "\n${BLUE}阶段 3: 重新构建（新镜像）${NC}"
    if ! build_app; then
        echo -e "${RED}❌ 阶段 3 失败${NC}"
        return 1
    fi

    # 阶段 4: 发布
    echo -e "\n${BLUE}阶段 4: 发布审核${NC}"
    if ! publish_app; then
        echo -e "${RED}❌ 阶段 4 失败${NC}"
        return 1
    fi

    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ 一键发布完成!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 主菜单
main_menu() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  BackApp 发布工具${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "1. 📦 构建应用 (Build)"
    echo -e "2. 🔧 镜像复制到懒猫仓库 (Copy Image)"
    echo -e "3. 📤 发布到应用商店 (Publish)"
    echo -e "4. 🚀 一键构建+镜像复制+发布 (One-Click)"
    echo -e "5. 📋 查看应用信息 (Info)"
    echo -e "6. ❌ 退出"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -n "请选择操作 [1-6]: "
}

# 主程序
main() {
    # 检查必要文件
    check_files

    while true; do
        main_menu
        read -r choice

        case $choice in
            1)
                validate_config
                show_info
                build_app
                ;;
            2)
                validate_config
                copy_image
                ;;
            3)
                validate_config
                publish_app
                ;;
            4)
                validate_config
                show_info
                one_click_publish
                ;;
            5)
                validate_config
                show_info
                ;;
            6)
                echo -e "${GREEN}再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 无效选择${NC}"
                ;;
        esac

        echo ""
        echo -n "按 Enter 继续..."
        read -r
    done
}

# 如果带参数运行，直接执行对应操作
if [ $# -eq 1 ]; then
    case $1 in
        "build")
            check_files
            validate_config
            build_app
            ;;
        "copy")
            check_files
            copy_image
            ;;
        "publish")
            check_files
            validate_config
            publish_app
            ;;
        "info")
            check_files
            validate_config
            show_info
            ;;
        "oneclick")
            check_files
            validate_config
            show_info
            one_click_publish
            ;;
        *)
            echo "用法: $0 [build|copy|publish|info|oneclick]"
            exit 1
            ;;
    esac
else
    main
fi
