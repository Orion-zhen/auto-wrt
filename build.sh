#!/bin/bash

#=======================================#
#                                                                                                  #
#               ImmortalWrt Firmware Auto-Build Script                 #
#                                                                                                  #
#=======================================#

# 当任何命令执行失败时立即退出脚本
# 'pipefail' 选项确保管道中的命令失败也会被捕获
set -eo pipefail

# --- 全局变量和颜色定义 ---
CLONE_DIR="openwrt"
CONFIG_FILE=".config"
REPO_URL="https://github.com/openwrt/openwrt.git"
REPO_BRANCH="main"

# 终端颜色代码
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# --- 辅助函数 ---

# 打印步骤标题
# 参数1: 步骤标题
function print_step() {
    echo -e "\n${BLUE}▶ $1${RESET}"
    echo -e "${BLUE}======================================================================${RESET}"
}

# 打印成功信息
# 参数1: 成功消息
function print_ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

# 打印警告信息
# 参数1: 警告消息
function print_warn() {
    echo -e "${YELLOW}ℹ $1${RESET}"
}

# 打印错误信息并退出
# 参数1: 错误消息
function print_error() {
    echo -e "${RED}✖ $1${RESET}" >&2
    exit 1
}

# 计算并格式化时间
# 参数1: 开始时间 (秒)
# 参数2: 结束时间 (秒)
function format_time() {
    local start_time=$1
    local end_time=$2
    local duration=$((end_time - start_time))
    if ((duration > 3600)); then
        printf "%dh %dm %ds" $((duration / 3600)) $(( (duration % 3600) / 60 )) $((duration % 60))
    elif ((duration > 60)); then
        printf "%dm %ds" $((duration / 60)) $((duration % 60))
    else
        printf "%ds" $duration
    fi
}

# --- 脚本退出时的清理和总结 ---
# 使用 trap 捕获退出信号, 无论成功或失败都会执行
function final_summary() {
    local exit_code=$?
    local total_end_time=$(date +%s)
    local total_duration
    total_duration=$(format_time "$total_start_time" "$total_end_time")

    echo -e "${BLUE}======================================================================${RESET}"
    if [ $exit_code -eq 0 ]; then
        print_ok "ImmortalWrt 构建流程成功结束!"
        print_warn "固件及相关文件位于 '${CLONE_DIR}/bin/targets' 目录下."
    else
        print_error "构建流程因错误而中止 (退出码: $exit_code)."
    fi
    echo -e "\n总耗时: ${YELLOW}${total_duration}${RESET}"
}
trap final_summary EXIT

# --- 主流程开始 ---
total_start_time=$(date +%s)

print_step "步骤 1: 环境准备与配置"
export FORCE_UNSAFE_CONFIGURE=1
print_warn "已设置 FORCE_UNSAFE_CONFIGURE=1 (允许在 CI/CD 等 root 环境中运行 configure)."
CORES=$(nproc)
print_ok "将使用 ${CORES} 个 CPU 核心进行编译."

print_step "步骤 2: 克隆 ImmortalWrt 源码"
if [ -d "$CLONE_DIR" ]; then
    print_warn "源码目录 '${CLONE_DIR}' 已存在, 跳过克隆."
else
    clone_start_time=$(date +%s)
    git clone -b "$REPO_BRANCH" --single-branch "$REPO_URL" "$CLONE_DIR"
    clone_end_time=$(date +%s)
    clone_duration=$(format_time "$clone_start_time" "$clone_end_time")
    print_ok "源码克隆完成, 耗时 ${clone_duration}."
fi

# 进入源码目录
cd "$CLONE_DIR"

print_step "步骤 3: 应用自定义配置并更新 Feeds"
# 检查 .config 文件是否存在
if [ ! -f "../$CONFIG_FILE" ]; then
    print_error "自定义配置文件 '${CONFIG_FILE}' 在项目根目录未找到!"
fi

cp "../$CONFIG_FILE" .
sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default
print_ok "已将自定义配置文件 '${CONFIG_FILE}' 复制到源码目录."

feeds_start_time=$(date +%s)
./scripts/feeds update -a
./scripts/feeds install -a
feeds_end_time=$(date +%s)
feeds_duration=$(format_time "$feeds_start_time" "$feeds_end_time")
make download
print_ok "Feeds 更新与安装完成, 耗时 ${feeds_duration}."

print_step "步骤 4: 开始编译固件 (这将花费很长时间...)"
print_warn "编译日志将实时输出. 冲杯咖啡, 耐心等待吧. ☕"
make_start_time=$(date +%s)
# make "-j${CORES}"
make -j1 V=s
make_end_time=$(date +%s)
make_duration=$(format_time "$make_start_time" "$make_end_time")
print_ok "固件编译完成, 耗时 ${make_duration}."

# 脚本正常结束, EXIT trap 会被触发以打印最终总结
exit 0