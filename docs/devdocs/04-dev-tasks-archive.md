# 已完成开发任务归档

本文件归档了 Chiaki-ng Apple 原生客户端项目已完成的历史开发任务。

## M1: 项目初始化 ✅
- **目标**: 搭建多平台 Xcode 项目环境。
- **涉及文件**: `Chiaki.xcodeproj`, `Chiaki/App/`, `Chiaki/Core/Bridge/`
- **成果**: 确立了独立仓库 + 子模块的架构，完成了 libchiaki 基础集成。

## M2: UI 框架 ✅
- **目标**: 使用 SwiftUI 构建原生 UI 骨架。
- **涉及文件**: `HostListView.swift`, `StreamingView.swift`, `SettingsView.swift`
- **成果**: 实现了响应式的主机列表、流媒体占位图和分级设置页面。

## M3: 核心库构建 ✅
- **目标**: libchiaki 及依赖库的交叉编译与桥接。
- **涉及文件**: `ChiakiBridge.swift`, `MetalVideoRenderer.swift`, `VideoToolboxDecoder.swift`
- **成果**: 完成了 mbedtls/opus 静态库链接，实现了基于 Metal 的 YUV 渲染。

## M4: 功能集成 ✅
- **目标**: 打通发现、连接与流媒体播放闭环。
- **涉及文件**: `ChiakiDiscovery.swift`, `ChiakiSession.swift`, `AudioPlayer.swift`
- **成果**: 实现了局域网自动发现、Takion 协议连接和低延迟音频播放。

## M5: 完善功能 ✅
- **目标**: 补全 PSN 登录与主机注册。
- **涉及文件**: `PSNLoginView.swift`, `RegistrationView.swift`, `KeychainManager.swift`
- **成果**: 支持 OAuth 登录获取 Token，实现了安全凭据的 Keychain 存储。

## M6: 平台适配 ✅
- **目标**: 各平台深度交互优化。
- **涉及文件**: `ChiakiTVApp.swift`, `MacMenuBar.swift`, `PiPManager.swift`
- **成果**: 实现了 macOS 原生菜单栏、tvOS 焦点引擎适配以及 iOS 画中画功能。

## M7: 发布准备 ✅
- **目标**: 文档、构建验证与最终磨合。
- **涉及文件**: `README.md`, `progress-report.md`
- **成果**: 完成了 Release 模式构建验证，建立了 DevDocs 自动化同步流程。

---
> 更多任务记录详见 [04-dev-tasks.md](04-dev-tasks.md)
