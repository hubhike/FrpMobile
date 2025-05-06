#!/bin/bash

# 检查 Android NDK 环境变量
if [[ -z "${ANDROID_NDK_HOME}" ]]; then
    echo "错误: 未找到环境变量 ANDROID_NDK_HOME"
    exit 1
fi

# 获取当前平台（用于 NDK 工具链路径）
get_platform() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

PLATFORM=$(get_platform)
echo "当前平台: $PLATFORM"

# 检查输入的 TAG 参数（frp 版本号）
TAG="$1"
if [[ -z "${TAG}" ]]; then
    echo "错误: 需传入 frp 构建标签（如 v0.62.1）"
    exit 1
fi

# 清理旧目录（避免残留文件干扰）
rm -rf ./frp
mkdir -p ./frp

# 克隆 frp 仓库并检出指定标签
echo "克隆 frp 仓库..."
git clone https://github.com/fatedier/frp.git ./frp || {
    echo "错误: 克隆 frp 仓库失败"
    exit 1
}

cd ./frp || {
    echo "错误: 进入 frp 目录失败"
    exit 1
}

echo "检出标签: $TAG"
git checkout "${TAG}" || {
    echo "错误: 检出标签 $TAG 失败（请检查标签是否存在于 frp 仓库）"
    exit 1
}

# 清理旧构建产物
rm -rf ./bin
mkdir -p ./bin/{arm64,arm,x86,x86_64}

# 构建函数
build_arch() {
    local arch="$1"
    local cc="$2"
    local cgo_enabled="$3"
    local go_arch="$4"
    local go_arm="${5:-}"

    echo "构建 $arch 架构..."
    export CC="$cc"
    if [[ -n "$go_arm" ]]; then
        env CGO_ENABLED="$cgo_enabled" GOOS=android GOARCH="$go_arch" GOARM="$go_arm" go build -trimpath -ldflags "-s -w" -tags frpc -o "./bin/$arch/frpc" ./cmd/frpc || {
            echo "错误: 构建 $arch frpc 失败"
            exit 1
        }
        env CGO_ENABLED="$cgo_enabled" GOOS=android GOARCH="$go_arch" GOARM="$go_arm" go build -trimpath -ldflags "-s -w" -tags frps -o "./bin/$arch/frps" ./cmd/frps || {
            echo "错误: 构建 $arch frps 失败"
            exit 1
        }
    else
        env CGO_ENABLED="$cgo_enabled" GOOS=android GOARCH="$go_arch" go build -trimpath -ldflags "-s -w" -tags frpc -o "./bin/$arch/frpc" ./cmd/frpc || {
            echo "错误: 构建 $arch frpc 失败"
            exit 1
        }
        env CGO_ENABLED="$cgo_enabled" GOOS=android GOARCH="$go_arch" go build -trimpath -ldflags "-s -w" -tags frps -o "./bin/$arch/frps" ./cmd/frps || {
            echo "错误: 构建 $arch frps 失败"
            exit 1
        }
    fi
}

# 构建 arm64-v8a 架构
build_arch "arm64" "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/aarch64-linux-android21-clang" 0 "arm64"

# 构建 x86_64（amd64）架构
build_arch "x86_64" "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/x86_64-linux-android21-clang" 1 "amd64"

# 构建 armv7a（armeabi-v7a）架构
build_arch "arm" "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/armv7a-linux-androideabi16-clang" 1 "arm" 7

# 构建 x86 架构
build_arch "x86" "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/i686-linux-android16-clang" 1 "386"

# 压缩函数
compress_and_copy() {
    local arch="$1"
    local output_dir="$2"

    echo "压缩 $arch 二进制文件..."
    upx --best "./bin/$arch/frpc" -o "./bin/$arch/frpc_upx" || cp "./bin/$arch/frpc" "./bin/$arch/frpc_upx"
    upx --best "./bin/$arch/frps" -o "./bin/$arch/frps_upx" || cp "./bin/$arch/frps" "./bin/$arch/frps_upx"

    mkdir -p "./bin/upx"
    cp "./bin/$arch/frpc_upx" "./bin/upx/${arch}_frpc"
    cp "./bin/$arch/frps_upx" "./bin/upx/${arch}_frps"

    mkdir -p "./bin/so/${output_dir}"
    cp "./bin/$arch/frpc_upx" "./bin/so/${output_dir}/libfrpc.so"
    cp "./bin/$arch/frps_upx" "./bin/so/${output_dir}/libfrps.so"
}

# 压缩并复制文件
compress_and_copy "arm64" "arm64-v8a"
compress_and_copy "arm" "armeabi-v7a"
compress_and_copy "x86" "x86"
compress_and_copy "x86_64" "x86_64"

echo "构建完成！输出目录: $(pwd)/bin"
