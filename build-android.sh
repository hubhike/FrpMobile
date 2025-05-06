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
INPUT_TAG="$1"
if [[ -z "${INPUT_TAG}" ]]; then
    echo "错误: 需传入 frp 构建标签（如 v0.62.1）"
    exit 1
fi

# 强制为 TAG 添加 v 前缀（兼容用户传递带/不带 v 的场景）
if [[ "${INPUT_TAG:0:1}" != "v" ]]; then
    TAG="v${INPUT_TAG}"
else
    TAG="${INPUT_TAG}"
fi
echo "将构建 frp 标签: $TAG"

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

# 构建 arm64-v8a 架构
echo "构建 arm64 架构..."
export CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/aarch64-linux-android21-clang"
env CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -trimpath -ldflags "-s -w" -tags frpc -o ./bin/arm64/frpc ./cmd/frpc || {
    echo "错误: 构建 arm64 frpc 失败"
    exit 1
}
env CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -trimpath -ldflags "-s -w" -tags frps -o ./bin/arm64/frps ./cmd/frps || {
    echo "错误: 构建 arm64 frps 失败"
    exit 1
}

# 构建 x86_64（amd64）架构
echo "构建 amd64 架构..."
export CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/x86_64-linux-android21-clang"
env CGO_ENABLED=1 GOOS=android GOARCH=amd64 go build -trimpath -ldflags "-s -w" -tags frpc -o ./bin/x86_64/frpc ./cmd/frpc || {
    echo "错误: 构建 amd64 frpc 失败"
    exit 1
}
env CGO_ENABLED=1 GOOS=android GOARCH=amd64 go build -trimpath -ldflags "-s -w" -tags frps -o ./bin/x86_64/frps ./cmd/frps || {
    echo "错误: 构建 amd64 frps 失败"
    exit 1
}

# 构建 armv7a（armeabi-v7a）架构
echo "构建 arm 架构..."
export CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/armv7a-linux-androideabi16-clang"
env CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 go build -trimpath -ldflags "-s -w" -tags frpc -o ./bin/arm/frpc ./cmd/frpc || {
    echo "错误: 构建 arm frpc 失败"
    exit 1
}
env CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 go build -trimpath -ldflags "-s -w" -tags frps -o ./bin/arm/frps ./cmd/frps || {
    echo "错误: 构建 arm frps 失败"
    exit 1
}

# 构建 x86 架构
echo "构建 x86 架构..."
export CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin/i686-linux-android16-clang"
env CGO_ENABLED=1 GOOS=android GOARCH=386 go build -trimpath -ldflags "-s -w" -tags frpc -o ./bin/x86/frpc ./cmd/frpc || {
    echo "错误: 构建 x86 frpc 失败"
    exit 1
}
env CGO_ENABLED=1 GOOS=android GOARCH=386 go build -trimpath -ldflags "-s -w" -tags frps -o ./bin/x86/frps ./cmd/frps || {
    echo "错误: 构建 x86 frps 失败"
    exit 1
}

# 使用 UPX 压缩（失败时保留原文件）
echo "压缩 arm64 二进制文件..."
upx --best ./bin/arm64/frpc -o ./bin/arm64/frpc_upx || cp ./bin/arm64/frpc ./bin/arm64/frpc_upx
upx --best ./bin/arm64/frps -o ./bin/arm64/frps_upx || cp ./bin/arm64/frps ./bin/arm64/frps_upx

echo "压缩 arm 二进制文件..."
upx --best ./bin/arm/frpc -o ./bin/arm/frpc_upx || cp ./bin/arm/frpc ./bin/arm/frpc_upx
upx --best ./bin/arm/frps -o ./bin/arm/frps_upx || cp ./bin/arm/frps ./bin/arm/frps_upx

echo "压缩 x86 二进制文件..."
upx --best ./bin/x86/frpc -o ./bin/x86/frpc_upx || cp ./bin/x86/frpc ./bin/x86/frpc_upx
upx --best ./bin/x86/frps -o ./bin/x86/frps_upx || cp ./bin/x86/frps ./bin/x86/frps_upx

echo "压缩 x86_64 二进制文件..."
upx --best ./bin/x86_64/frpc -o ./bin/x86_64/frpc_upx || cp ./bin/x86_64/frpc ./bin/x86_64/frpc_upx
upx --best ./bin/x86_64/frps -o ./bin/x86_64/frps_upx || cp ./bin/x86_64/frps ./bin/x86_64/frps_upx

# 整理输出目录（UPX 压缩后文件）
echo "整理 UPX 压缩文件..."
mkdir -p ./bin/upx
cp ./bin/arm64/frpc_upx ./bin/upx/arm64_frpc
cp ./bin/arm64/frps_upx ./bin/upx/arm64_frps
cp ./bin/arm/frpc_upx ./bin/upx/arm_frpc
cp ./bin/arm/frps_upx ./bin/upx/arm_frps
cp ./bin/x86/frpc_upx ./bin/upx/x86_frpc
cp ./bin/x86/frps_upx ./bin/upx/x86_frps
cp ./bin/x86_64/frpc_upx ./bin/upx/x86_64_frpc
cp ./bin/x86_64/frps_upx ./bin/upx/x86_64_frps

# 整理输出目录（SO 文件）
echo "整理 SO 文件..."
mkdir -p ./bin/so/{arm64-v8a,armeabi-v7a,x86,x86_64}
cp ./bin/arm64/frpc_upx ./bin/so/arm64-v8a/libfrpc.so
cp ./bin/arm64/frps_upx ./bin/so/arm64-v8a/libfrps.so
cp ./bin/arm/frpc_upx ./bin/so/armeabi-v7a/libfrpc.so
cp ./bin/arm/frps_upx ./bin/so/armeabi-v7a/libfrps.so
cp ./bin/x86/frpc_upx ./bin/so/x86/libfrpc.so
cp ./bin/x86/frps_upx ./bin/so/x86/libfrps.so
cp ./bin/x86_64/frpc_upx ./bin/so/x86_64/libfrpc.so
cp ./bin/x86_64/frps_upx ./bin/so/x86_64/libfrps.so

echo "构建完成！输出目录: $(pwd)/bin"
