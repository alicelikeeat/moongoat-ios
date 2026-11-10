# 验收与限制

2026-11-10，Linux / Swift 6.1.2。

## 已执行

- SwiftPM 核心模块实际编译和 XCTest（8 个测试，详见执行输出）。
- 300 个生成牌局按构造路线完整通关，覆盖 100 固定种子 × 三种牌数。
- Swift 编译器解析所有 App Swift 文件（语法检查，不是 iOS 编译）。
- plutil 检查 Xcode project.pbxproj、Info.plist、PrivacyInfo.xcprivacy。
- bash 语法检查构建脚本；工程生成可重复。

## CI 已执行及设备待验收

- 已接入远端仓库 alicelikeeat/moongoat-ios。
- 已通过 Xcode 26.6 / iOS SDK 26.5 的 arm64 Release 编译与未签名打包；8 项 macOS 核心测试通过。构建：https://github.com/alicelikeeat/moongoat-ios/actions/runs/42743534742 。
- Liquid Glass 与材质回退实机外观、交互截图、气泡和飞牌动画检查。
- 各尺寸 iPhone 排版、VoiceOver 顺序、动态字体、低电量与性能测量。
- 照片权限路径、真实 HEIC 图导入、超大图片内存、重启恢复和系统强杀。

## 已知边界

初始有解不等于任意选择有解。提示仅优先槽中已存在的类型。内置牌面使用系统 emoji，视觉会随 iOS 系统字体变化。自定义牌面保留不同类别 ID，用户替换为相同图片时可能难以分辨。撤回历史不跨重启；没有每日挑战、排行榜、付费、广告、音频或云同步。

原生 glassEffect 需要 iOS 26 和相应 SDK；旧系统的材质回退不是 Liquid Glass。当前 UI 已通过 iOS 编译并生成未签名设备包；尚未完成模拟器交互与真机验证。普通设备安装仍需签名。

## 0.1.1 验证增量

Linux / Swift 6.1.2：11 项测试通过。新增 `PickPresentation` 的三张收集/合并、撤回反向数据、普通入槽和最后一组消除时机测试。`PickPresentation.collected` 明确为不可存储的临时帧，保存始终使用规则引擎完整结果。

iOS 26 原生玻璃容器、气泡和形变已接入，已通过 Xcode 26.6 的 arm64 iPhoneOS Release 编译及 11 项 macOS 测试（构建 42746968587）；真实设备性能、视觉与系统无障碍设置仍需验收。旧版本 v0.1.0 的已发布附件保持不变。

## 0.1.2 验证增量

Linux Swift 6.1.2：14 项测试通过，包含 100 Seed × 三种新规模的完整构造路线通关；另对每档 20 个种子检查牌数、全部类型覆盖、三张成组、类型数量差不超过一组、同层不重叠、固定边界、储备顶牌可选及下方牌不可选。36/48/60 张旧快照和扩大牌池的 JSON 恢复测试通过。

生成器采用遮挡依赖图规划合法顺序，避免在每次规划移除后重复扫描全部牌对。保留 iOS 26 原生动效；新牌局已通过 Xcode 26.6 的 arm64 Release 编译和 14 项 macOS 测试（构建 42748564833）；密集牌局在真实设备的排版和性能尚待验证。旧已发布版本保持不变。
