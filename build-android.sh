#! /bin/bash
set -euo pipefail

# 1. 环境检查
if [[ -z ${ANDROID_NDK_HOME} ]]; then
    echo "ERROR: ANDROID_NDK_HOME environment variable not set!"
    exit 1
fi

# 2. 定义平台检测函数
get_platform() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

PLATFORM=$(get_platform)
echo "Current platform is: $PLATFORM"

# 3. 检查版本参数
TAG=${1:-v0.68.0}
echo "Building frp version: $TAG"

# 4. 清理旧环境
rm -rf frp
git clone https://github.com/fatedier/frp.git || { echo "ERROR: Clone frp failed!"; exit 1; }
cd frp || { echo "ERROR: Enter frp directory failed!"; exit 1; }
git checkout ${TAG} || { echo "ERROR: Checkout tag $TAG failed!"; exit 1; }

# ==================== 关键修复：删除 Web 相关嵌入文件 ====================
# 彻底移除引用 dist 目录的文件，从源码层面规避编译错误
rm -f web/frpc/embed.go
rm -f web/frps/embed.go
echo "Removed web embed files to avoid dist directory check"

# 5. 创建统一输出目录
rm -rf bin
mkdir -p bin/{arm64,x86_64,arm,x86}

# 6. 编译函数（复用逻辑，减少冗余）
build_frp() {
    local arch=$1
    local goarch=$2
    local goarm=$3
    local cc_prefix=$4
    local android_api=$5

    echo "========================================"
    echo "Building frp for ${arch} (GOARCH=${goarch})"
    echo "========================================"

    # 设置NDK编译器
    export CC=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/${cc_prefix}${android_api}-clang
    
    # 设置GO环境变量
    export GOOS=android
    export GOARCH=${goarch}
    if [[ -n ${goarm} ]]; then
        export GOARM=${goarm}
    fi

    # 编译frpc（强制禁用CGO + 强化标签）
    CGO_ENABLED=0 go build -trimpath \
        -ldflags "-s -w -buildid=" \
        -tags "frpc no_web disable_web" \
        -o bin/${arch}/frpc ./cmd/frpc || { echo "WARN: Build frpc for ${arch} failed, skip"; return 1; }

    # 编译frps
    CGO_ENABLED=0 go build -trimpath \
        -ldflags "-s -w -buildid=" \
        -tags "frps no_web disable_web" \
        -o bin/${arch}/frps ./cmd/frps || { echo "WARN: Build frps for ${arch} failed, skip"; return 1; }

    echo "Success build frp for ${arch}"
    return 0
}

# 7. 分架构编译（按实际需要调整API版本）
build_frp "arm64" "arm64" "" "aarch64-linux-android" "21"
build_frp "x86_64" "amd64" "" "x86_64-linux-android" "21"
build_frp "arm" "arm" "7" "armv7a-linux-androideabi" "16"
build_frp "x86" "386" "" "i686-linux-android" "16"

# 8. UPX压缩（增加文件存在检查）
compress_with_upx() {
    local arch=$1
    local bin_path="bin/${arch}"
    
    if [[ -f ${bin_path}/frpc ]]; then
        upx --best --lzma ${bin_path}/frpc -o ${bin_path}/frpc_upx || cp ${bin_path}/frpc ${bin_path}/frpc_upx
    else
        echo "WARN: ${bin_path}/frpc not found, skip upx"
    fi

    if [[ -f ${bin_path}/frps ]]; then
        upx --best --lzma ${bin_path}/frps -o ${bin_path}/frps_upx || cp ${bin_path}/frps ${bin_path}/frps_upx
    else
        echo "WARN: ${bin_path}/frps not found, skip upx"
    fi
}

# 逐个架构压缩
compress_with_upx "arm64"
compress_with_upx "x86_64"
compress_with_upx "arm"
compress_with_upx "x86"

# 9. 整理输出目录（递归创建 + 存在性检查）
# UPX目录
mkdir -p bin/upx/{arm64,arm,x86,x86_64}
for arch in arm64 arm x86 x86_64; do
    [[ -f bin/${arch}/frpc_upx ]] && cp bin/${arch}/frpc_upx bin/upx/${arch}/frpc
    [[ -f bin/${arch}/frps_upx ]] && cp bin/${arch}/frps_upx bin/upx/${arch}/frps
done

# SO目录（Android习惯命名）
mkdir -p bin/so/{arm64-v8a,armeabi-v7a,x86,x86_64}
[[ -f bin/arm64/frpc_upx ]] && cp bin/arm64/frpc_upx bin/so/arm64-v8a/libfrpc.so
[[ -f bin/arm64/frps_upx ]] && cp bin/arm64/frps_upx bin/so/arm64-v8a/libfrps.so
[[ -f bin/arm/frpc_upx ]] && cp bin/arm/frpc_upx bin/so/armeabi-v7a/libfrpc.so
[[ -f bin/arm/frps_upx ]] && cp bin/arm/frps_upx bin/so/armeabi-v7a/libfrps.so
[[ -f bin/x86/frpc_upx ]] && cp bin/x86/frpc_upx bin/so/x86/libfrpc.so
[[ -f bin/x86/frps_upx ]] && cp bin/x86/frps_upx bin/so/x86/libfrps.so
[[ -f bin/x86_64/frpc_upx ]] && cp bin/x86_64/frpc_upx bin/so/x86_64/libfrpc.so
[[ -f bin/x86_64/frps_upx ]] && cp bin/x86_64/frps_upx bin/so/x86_64/libfrps.so

echo "========================================"
echo "Build completed! Check bin directory."
echo "========================================"
ls -l bin/* || true
