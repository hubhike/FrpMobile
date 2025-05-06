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

var (
	scanDir string
	version string // 新增：接收版本号参数
)

// Version 对应JSON中的单个版本信息
type Version struct {
	Version          string `json:"version"`
	DownloadBaseUrl  string `json:"downloadBaseUrl"`
	Arm64FrpcMd5     string `json:"arm64_frpc_md5"`
	Arm64FrpsMd5     string `json:"arm64_frps_md5"`
	ArmFrpcMd5       string `json:"arm_frpc_md5"`
	ArmFrpsMd5       string `json:"arm_frps_md5"`
	X8664FrpcMd5     string `json:"x86_64_frpc_md5"`
	X8664FrpsMd5     string `json:"x86_64_frps_md5"`
	X86FrpcMd5       string `json:"x86_frpc_md5"`
	X86FrpsMd5       string `json:"x86_frps_md5"`
}

// Config 最终输出的JSON结构
type Config struct {
	Versions []Version `json:"versions"`
}

func calculateFileMD5(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", fmt.Errorf("error opening file: %v", err)
	}
	defer file.Close()

	hash := md5.New()
	_, err = io.Copy(hash, file)
	if err != nil {
		return "", fmt.Errorf("error copying file to hash: %v", err)
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func main() {
	flag.StringVar(&scanDir, "d", "dir", "frp build dir")
	flag.StringVar(&version, "version", "", "frp version (required)") // 新增版本号参数
	flag.Parse()

	if version == "" {
		log.Fatal("version parameter is required")
	}

	files, err := os.ReadDir(scanDir)
	if err != nil {
		log.Fatalf("Error reading directory: %v %s", err, scanDir)
	}

	// 初始化版本信息
	verInfo := Version{
		Version:         version,
		DownloadBaseUrl: fmt.Sprintf("https://github.com/hubhike/FrpMobile/releases/download/v%s/", version),
	}

	// 遍历文件并填充MD5
	for _, file := range files {
		if file.IsDir() || file.Name()[0] == '.' { // 跳过目录和隐藏文件
			continue
		}

		hash, err := calculateFileMD5(filepath.Join(scanDir, file.Name()))
		if err != nil {
			log.Printf("md5 failed for %s: %v", file.Name(), err)
			continue
		}

		// 根据文件名匹配MD5字段
		switch file.Name() {
		case "arm64_frpc":
			verInfo.Arm64FrpcMd5 = hash
		case "arm64_frps":
			verInfo.Arm64FrpsMd5 = hash
		case "arm_frpc":
			verInfo.ArmFrpcMd5 = hash
		case "arm_frps":
			verInfo.ArmFrpsMd5 = hash
		case "x86_64_frpc":
			verInfo.X8664FrpcMd5 = hash
		case "x86_64_frps":
			verInfo.X8664FrpsMd5 = hash
		case "x86_frpc":
			verInfo.X86FrpcMd5 = hash
		case "x86_frps":
			verInfo.X86FrpsMd5 = hash
		default:
			log.Printf("ignored unknown file: %s", file.Name())
		}
	}

	// 构造最终JSON结构
	config := Config{
		Versions: []Version{verInfo},
	}

	jsonData, err := json.MarshalIndent(config, "", "    ")
	if err != nil {
		log.Fatalf("Error encoding JSON: %v", err)
	}

	// 输出到标准输出（后续重定向到文件）
	fmt.Println(string(jsonData))
}
