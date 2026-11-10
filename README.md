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

已在 GitHub Actions 的 macOS / Xcode 26.6 / iOS SDK 26.5 上编译成功并生成真实未签名 IPA；8 项核心测试通过。安装包见 [成功构建](https://github.com/alicelikeeat/moongoat-ios/actions/runs/42743534742) 的 MoonGoat-unsigned artifact。模拟器交互及真机验收尚未完成。

## 测试

```sh
swift test
```

11 项 XCTest 覆盖：100 Seed 确定性、100 Seed × 3 种大小的完整通关路线、遮挡失败零修改、三张消除/撤回/胜利、七格失败恢复、第七张先消除再判负、洗牌守恒与次数、存档序列化和非法数据拒绝；合并临时表现、反向分离数据、通关结算时机。

UI 代码已通过 Xcode 26.6 的 arm64 iPhoneOS Release 编译。完整状态和风险见 [验收记录](docs/validation.md)。

## 换牌

右上角调色板 → 选择类别 → 从照片选择。图片优先于主题符号；恢复默认会删除该类自定义图片。支持单帧、10 MB / 4000 万像素以内图片，降采样到最大边 256 像素；拒绝动画输入。照片选择器无需申请整个相册读取权限。

## 存档与结构

- `Sources/MoonGoatCore`：纯 Swift 规则、可复现随机数、状态校验。
- `App`：SwiftUI 场景、玻璃材质、气泡、工作室与设备本地存储。
- `Resources`：图标、Info.plist、隐私清单。
- `Tests`：规则回归测试。
- `tools`：工程生成、未签名构建与验证打包。

Documents/MoonGoat/session.json 使用版本 1 的 JSON、原子替换。损坏存档保留原文件并暂停写入；明确开始新局前备份损坏文件。撤销历史仅在本次会话有效，不跨重启保存。提示不是自动解法，洗牌后不保证有解。无广告、账号、服务器或数据上传。

## 0.1.1 原生动效

`GlassEffectContainer`、`glassEffectID`、`glassEffectUnion`、`glassEffectTransition(.matchedGeometry)` 和 `Glass.interactive()` 在 iOS 26 / Swift 6.2+ 分支启用。背景气泡使用原生玻璃圆形，靠近时由系统融合；iOS 17–18 使用 SwiftUI 形状、材质和弹簧动画回退。

`PickPresentation` 只用于 UI 的瞬时画面：规则与存档即时完成，画面随后播放入槽、合并和消散。动画期间防止重复操作；开始新局、退到后台或改变“减少动态效果”偏好时取消表现任务，显示已完成状态。开启减少动态效果会跳过合并/分离并暂停漂浮气泡。存档格式仍为 1，兼容已有牌局。
