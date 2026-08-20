#!/bin/bash
# iOS Project Setup Script
# 使用方法: chmod +x setup.sh && ./setup.sh
# 
# 此脚本创建一个新的 Xcode SwiftUI 项目，并将所有源文件链接进去

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Seeker"
BUNDLE_ID="com.seeker.ios"

echo "========================================="
echo "  Seeker - iOS 项目初始化"
echo "========================================="
echo ""

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "[错误] 未找到 Xcode，请确保已安装 Xcode 15+"
    exit 1
fi

echo "[1/3] 创建 Xcode 项目..."

# 创建一个临时的 SwiftUI 项目骨架
mkdir -p "${PROJECT_DIR}/${APP_NAME}.xcodeproj"

# 生成 Package.swift 用于描述项目（SPM 格式便于管理）
cat > "${PROJECT_DIR}/Package.swift" << 'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Seeker",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Seeker", targets: ["Seeker"])
    ],
    targets: [
        .target(
            name: "Seeker",
            path: "BountyApp"
        )
    ]
)
PACKAGE

# 生成 project.yml (XcodeGen 格式)
cat > "${PROJECT_DIR}/project.yml" << 'YML'
name: Seeker
options:
  bundleIdPrefix: com.seeker
  deploymentTarget:
    iOS: "16.0"
settings:
  MARKETING_VERSION: "1.0.0"
  CURRENT_PROJECT_VERSION: "1"
  
targets:
  Seeker:
    type: application
    platform: iOS
    sources:
      - path: BountyApp
    settings:
      base:
        INFOPLIST_FILE: BountyApp/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.seeker.ios
        SWIFT_VERSION: "5.9"
    info:
      path: BountyApp/Info.plist
    preBuildScripts:
      - name: "SwiftLint"
        script: |
          if which swiftlint > /dev/null; then
            swiftlint
          fi
        basedOnDependencyAnalysis: false
YML

echo "[2/3] 项目文件已生成"
echo ""
echo "源文件结构:"
echo "  BountyApp/"
find "${PROJECT_DIR}/BountyApp" -name "*.swift" | sort | while read f; do
    echo "    $(echo $f | sed "s|${PROJECT_DIR}/||")"
done

echo ""
echo "[3/3] 初始化完成！"
echo ""
echo "========================================="
echo "  使用方式:"
echo "========================================="
echo ""
echo "方式一 (推荐): 使用 XcodeGen 生成 Xcode 项目"
echo "  1. brew install xcodegen"
echo "  2. cd ${PROJECT_DIR}"
echo "  3. xcodegen generate"
echo "  4. open BountyApp.xcodeproj"
echo ""
echo "方式二: 手动创建 Xcode 项目"
echo "  1. 打开 Xcode → New Project → iOS → App"
echo "  2. 填写 Product Name: Seeker"
echo "  3. Interface: SwiftUI, Language: Swift"
echo "  4. 将 BountyApp/ 下所有文件拖入项目"
echo "  5. 添加 Info.plist 中的相机和定位权限"
echo ""
echo "方式三: Xcode 命令行创建"
echo "  xcodebuild -create-xcworkspace ..."

echo ""
echo "========================================="
echo "  别忘了先启动后端服务:"
echo "  cd ${PROJECT_DIR}/../../backend"
echo "  docker compose up -d"
echo "  cd cmd/server && go run main.go"
echo "========================================="
