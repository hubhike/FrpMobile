#!/bin/bash
set -e  # 遇到错误立即退出，便于定位问题

# 检查 ANDROID_NDK_HOME 环境变量
if [[ -z ${ANDROID_NDK_HOME} ]]; then
    echo "错误：未设置 ANDROID_NDK_HOME 环境变量！"
    exit 1
fi

# 检测当前系统平台（darwin/linux）
get_platform() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" && exit 1 ;;
    esac
}

PLATFORM=$(get_platform)
echo "当前系统平台：$PLATFORM"

# 检查传入的 frp 版本标签参数
TAG=${1}
if [[ -z ${TAG} ]]; then
    echo "使用方式：$0 [frp版本标签，如v0.68.0]"
    exit 1
fi

# 下载 UPX（可选，用于压缩二进制文件）
UPX_VERSION="4.2.4"
UPX_ARCH="amd64_linux"
UPX_FILE="upx-${UPX_VERSION}-${UPX_ARCH}.tar.xz"
if [[ ! -f ./upx ]]; then
    echo "下载 UPX ${UPX_VERSION}..."
    wget "https://github.com/upx/upx/releases/download/v${UPX_VERSION}/${UPX_FILE}" -O ${UPX_FILE}
    tar -xf ${UPX_FILE}
    cp ./upx-${UPX_VERSION}-${UPX_ARCH}/upx ./upx
    chmod +x ./upx
fi

# 克隆 frp 源码并切换到指定版本
if [[ -d frp ]]; then
    rm -rf frp
fi
git clone https://github.com/fatedier/frp.git
cd frp || exit 1
git checkout ${TAG}

# ========== 关键修复：创建空的 dist 目录，绕过 embed 检查 ==========
mkdir -p web/frpc/dist
mkdir -p web/frps/dist
# ================================================================

# 清空旧的构建产物
rm -rf bin
mkdir -p bin

# 构建不同架构的 frpc/frps
build_arch() {
    local arch=$1
    local cc=$2
    local goarch=$3
    local goarm=$4  # 仅 arm 架构需要

    echo "开始构建 ${arch} 架构..."
    mkdir -p bin/${arch}

    # 设置编译参数
    export CC=${cc}
    local go_env="CGO_ENABLED=0 GOOS=android GOARCH=${goarch}"
    if [[ -n ${goarm} ]]; then
        go_env="${go_env} GOARM=${goarm}"
    fi

    # 编译 frpc
    ${go_env} go build -trimpath -ldflags "-s -w" -tags frpc -o bin/${arch}/frpc ./cmd/frpc
    # 编译 frps
    ${go_env} go build -trimpath -ldflags "-s -w" -tags frps -o bin/${arch}/frps ./cmd/frps

    # 用 UPX 压缩（不存在则跳过）
    if [[ -f ../upx ]]; then
        ../upx --best bin/${arch}/frpc -o bin/${arch}/frpc_upx || cp bin/${arch}/frpc bin/${arch}/frpc_upx
        ../upx --best bin/${arch}/frps -o bin/${arch}/frps_upx || cp bin/${arch}/frps bin/${arch}/frps_upx
    else
        cp bin/${arch}/frpc bin/${arch}/frpc_upx
        cp bin/${arch}/frps bin/${arch}/frps_upx
    fi
}

# 1. 构建 arm64 (aarch64)
build_arch "arm64" \
    "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/aarch64-linux-android21-clang" \
    "arm64" ""

# 2. 构建 x86_64 (amd64)
build_arch "x86_64" \
    "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/x86_64-linux-android21-clang" \
    "amd64" ""

# 3. 构建 arm (armeabi-v7a)
build_arch "arm" \
    "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/armv7a-linux-androideabi16-clang" \
    "arm" "7"

# 4. 构建 x86
build_arch "x86" \
    "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/i686-linux-android16-clang" \
    "386" ""

# 整理产物（按 Android ABI 目录结构）
mkdir -p bin/upx
mkdir -p bin/so

# 复制 upx 压缩后的文件到 upx 目录
for arch in arm64 x86_64 arm x86; do
    mkdir -p bin/upx/${arch}
    cp bin/${arch}/frpc_upx bin/upx/${arch}/frpc || true
    cp bin/${arch}/frps_upx bin/upx/${arch}/frps || true
done

# 复制到 so 目录（匹配 Android ABI 命名）
abi_mapping=(
    "arm64:arm64-v8a"
    "arm:armeabi-v7a"
    "x86:x86"
    "x86_64:x86_64"
)
for mapping in "${abi_mapping[@]}"; do
    src_arch=${mapping%%:*}
    dst_abi=${mapping##*:}
    mkdir -p bin/so/${dst_abi}
    cp bin/${src_arch}/frpc_upx bin/so/${dst_abi}/frpc || true
    cp bin/${src_arch}/frps_upx bin/so/${dst_abi}/frps || true
done

echo "构建完成！产物目录：$(pwd)/bin"
exit 0
