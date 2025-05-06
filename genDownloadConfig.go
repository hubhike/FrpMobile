package main

import (
    "crypto/md5"
    "encoding/json"
    "flag"
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
)

// VersionInfo 定义版本信息结构体
type VersionInfo struct {
    Version         string `json:"version"`
    DownloadBaseUrl string `json:"downloadBaseUrl"`
    Arm64FrpcMd5    string `json:"arm64_frpc_md5"`
    Arm64FrpsMd5    string `json:"arm64_frps_md5"`
    ArmFrpcMd5      string `json:"arm_frpc_md5"`
    ArmFrpsMd5      string `json:"arm_frps_md5"`
    X8664FrpcMd5    string `json:"x86_64_frpc_md5"`
    X8664FrpsMd5    string `json:"x86_64_frps_md5"`
    X86FrpcMd5      string `json:"x86_frpc_md5"`
    X86FrpsMd5      string `json:"x86_frps_md5"`
}

// Config 定义下载配置结构体
type Config struct {
    Versions []VersionInfo `json:"versions"`
}

var scanDir string
var version string

func calculateFileMD5(filePath string) (string, error) {
    // 打开文件
    file, err := os.Open(filePath)
    if err != nil {
        return "", fmt.Errorf("error opening file: %v", err)
    }
    defer file.Close()

    // 创建一个MD5哈希对象
    hash := md5.New()

    // 将文件内容拷贝到哈希对象中
    _, err = io.Copy(hash, file)
    if err != nil {
        return "", fmt.Errorf("error copying file to hash: %v", err)
    }

    // 计算MD5值
    hashInBytes := hash.Sum(nil)
    // 将MD5值转换为16进制字符串
    md5String := fmt.Sprintf("%x", hashInBytes)

    return md5String, nil
}

func main() {
    flag.StringVar(&scanDir, "d", "dir", "frp build dir")
    flag.StringVar(&version, "v", "v0.0.0", "frp version")
    flag.Parse()

    files, err := os.ReadDir(scanDir)
    if err != nil {
        fmt.Println("Error reading directory:", err, scanDir)
        return
    }

    var info VersionInfo
    info.Version = version
    info.DownloadBaseUrl = fmt.Sprintf("https://github.com/hubhike/FrpMobile/releases/download/%s/", version)

    for _, file := range files {
        if!file.IsDir() && file.Name()[0] != '.' {
            hash, err := calculateFileMD5(filepath.Join(scanDir, file.Name()))
            if err != nil {
                log.Printf("md5 failed: %s", err.Error())
                continue
            }
            switch file.Name() {
            case "arm64_frpc":
                info.Arm64FrpcMd5 = hash
            case "arm64_frps":
                info.Arm64FrpsMd5 = hash
            case "arm_frpc":
                info.ArmFrpcMd5 = hash
            case "arm_frps":
                info.ArmFrpsMd5 = hash
            case "x86_64_frpc":
                info.X8664FrpcMd5 = hash
            case "x86_64_frps":
                info.X8664FrpsMd5 = hash
            case "x86_frpc":
                info.X86FrpcMd5 = hash
            case "x86_frps":
                info.X86FrpsMd5 = hash
            }
        }
    }

    config := Config{
        Versions: []VersionInfo{info},
    }

    // 将 Config 结构体转换为 JSON 格式
    jsonData, err := json.MarshalIndent(config, "", "    ")
    if err != nil {
        fmt.Println("Error encoding JSON:", err)
        return
    }

    fmt.Println(string(jsonData))
}
