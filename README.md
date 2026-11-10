# MoonGoat · 月下消消羊

离线 iOS 层叠三消游戏，使用独立 Swift 规则模块和原生 SwiftUI。

## 当前功能

- 三层遮挡、七格收集槽、同类三张自动消除、胜负状态。
- 36 / 48 / 60 张牌，确定性种子；初始牌局构造保证至少一条通关路线。
- 撤回（含消除和洗牌）、每局两次洗牌、优先匹配已有槽牌的提示。
- iOS 26 / Xcode 26 原生 Liquid Glass；iOS 17–18 使用 ultraThinMaterial 回退。
- 深色月光配色、浮动气泡、牌飞入槽和消除过渡、触感反馈。
- 三套内置牌面，可逐类从系统照片选择器导入图片；缩略图和牌局仅保存在设备。
- 减少动态效果、降低透明度偏好适配；牌面工作室、规则说明和新局难度选择。

玩法采用层叠三消规则，MoonGoat 名称、代码和图标独立制作；不包含《羊了个羊》原作商标、美术、音频或关卡素材。

## Xcode 运行

使用 **Xcode 26+ / iOS SDK 26+** 打开 `MoonGoat.xcodeproj`，选择 MoonGoat Scheme 和 iPhone 模拟器运行。最低部署 iOS 17，当前仅配置 iPhone 竖屏。

工程已生成并包含共享 Scheme。无需 CocoaPods、XcodeGen 或远程 Swift Package。
修改源码文件清单后运行：

```sh
python3 tools/generate_project.py
```

SwiftUI iOS 26 API 放在 `compiler(>=6.2)` 与 `#available(iOS 26.0, *)` 分支，旧工具链仅编译材质回退。

## 未签名 IPA

在安装 Xcode 26 的 **Mac** 上：

```sh
./tools/build_unsigned.sh
```

输出：`build/MoonGoat-unsigned.ipa` 和 SHA-256 校验文件。脚本先跑核心测试，再以 `CODE_SIGNING_ALLOWED=NO` 构建设备 arm64 应用，检查 Mach-O 和 iPhoneOS 平台后才放入 `Payload/MoonGoat.app` 打包。

也可将本项目接入 GitHub 后运行 `.github/workflows/ios.yml`；macOS 26 runner 构建并上传 `MoonGoat-unsigned` artifact。

**未签名 IPA 需要使用自己的证书签名才能在普通 iPhone 安装；不代表 App Store 或 TestFlight 包。**

当前开发环境为 Linux，尚未执行 Xcode 构建、生成真实 IPA 或完成模拟器/真机验收。CI 工作流已编写，尚未在远端运行。不会将源码或空目录伪装成 IPA。

## 测试

```sh
swift test
```

8 项 XCTest 覆盖：100 Seed 确定性、100 Seed × 3 种大小的完整通关路线、遮挡失败零修改、三张消除/撤回/胜利、七格失败恢复、第七张先消除再判负、洗牌守恒与次数、存档序列化和非法数据拒绝。

UI 代码仅在 Linux 通过 Swift 语法解析，尚未经 iOS SDK 类型检查。完整状态和风险见 [验收记录](docs/validation.md)。

## 换牌

右上角调色板 → 选择类别 → 从照片选择。图片优先于主题符号；恢复默认会删除该类自定义图片。支持单帧、10 MB / 4000 万像素以内图片，降采样到最大边 256 像素；拒绝动画输入。照片选择器无需申请整个相册读取权限。

## 存档与结构

- `Sources/MoonGoatCore`：纯 Swift 规则、可复现随机数、状态校验。
- `App`：SwiftUI 场景、玻璃材质、气泡、工作室与设备本地存储。
- `Resources`：图标、Info.plist、隐私清单。
- `Tests`：规则回归测试。
- `tools`：工程生成、未签名构建与验证打包。

Documents/MoonGoat/session.json 使用版本 1 的 JSON、原子替换。损坏存档保留原文件并暂停写入；明确开始新局前备份损坏文件。撤销历史仅在本次会话有效，不跨重启保存。提示不是自动解法，洗牌后不保证有解。无广告、账号、服务器或数据上传。
