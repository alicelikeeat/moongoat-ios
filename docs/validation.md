# 验收与限制

2026-11-10，Linux / Swift 6.1.2。

## 已执行

- SwiftPM 核心模块实际编译和 XCTest（8 个测试，详见执行输出）。
- 300 个生成牌局按构造路线完整通关，覆盖 100 固定种子 × 三种牌数。
- Swift 编译器解析所有 App Swift 文件（语法检查，不是 iOS 编译）。
- plutil 检查 Xcode project.pbxproj、Info.plist、PrivacyInfo.xcprivacy。
- bash 语法检查构建脚本；工程生成可重复。

## 未执行 / 待接入

- 已确认实际远端仓库为 alicelikeeat/moongoat-ios；正在接入并运行 macOS CI。
- Xcode 26 iOS SDK 类型检查、设备 arm64 编译、真实未签名 IPA 与 artifact。
- Liquid Glass 与材质回退实机外观、交互截图、气泡和飞牌动画检查。
- 各尺寸 iPhone 排版、VoiceOver 顺序、动态字体、低电量与性能测量。
- 照片权限路径、真实 HEIC 图导入、超大图片内存、重启恢复和系统强杀。

## 已知边界

初始有解不等于任意选择有解。提示仅优先槽中已存在的类型。内置牌面使用系统 emoji，视觉会随 iOS 系统字体变化。自定义牌面保留不同类别 ID，用户替换为相同图片时可能难以分辨。撤回历史不跨重启；没有每日挑战、排行榜、付费、广告、音频或云同步。

原生 glassEffect 需要 iOS 26 和相应 SDK；旧系统的材质回退不是 Liquid Glass。当前 UI 尚未通过 iOS 编译/真机验证，不能宣称已交付可安装包。
