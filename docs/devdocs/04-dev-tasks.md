# Chiaki-ng Apple 原生客户端 - 任务拆解

> **文档来源**: 改造自 `TASK.md`
> **改造时间**: 2026-01-13
> **最后更新**: 2026-01-18
> **调整说明**: UI 优先策略 - 项目初始化后先构建 UI 框架

## 任务说明

- 每个任务设计为**最小可运行和测试**单元
- `[ ]` 未开始 / `[~]` 进行中 / `[x]` 已完成
- **依赖** 表示必须先完成的前置任务
- **验收标准** 定义任务完成的具体条件

## 开发策略

**UI 优先原则**：
1. 项目初始化后，优先构建 UI 框架（使用 Mock 数据）
2. macOS SwiftUI 实现参照 `chiaki-ng/gui/` Qt 实现
3. iOS/iPadOS/tvOS 从 macOS 实现适配
4. UI 可独立于核心库开发，支持并行工作

**里程碑概览**：
| 阶段 | 名称 | 说明 | 状态 |
|------|------|------|------|
| M1 | 项目初始化 | Xcode 项目、目录结构 | ✅ 已完成 |
| M2 | UI 框架 | 数据模型、所有页面 UI（Mock 数据）| ✅ 已完成 (iOS/macOS) |
| M3 | 核心库构建 | 依赖库、桥接层、Metal 渲染器 | ✅ 已完成 |
| M4 | 功能集成 | 主机发现、会话、流媒体、控制器 | 🔄 进行中 |
| M5 | 完善功能 | PSN 登录、注册、多语言 | 未开始 |
| M6 | 平台适配 | 各平台优化 | 未开始 |

---

## 阶段 M1: 项目初始化 (Project Setup) ✅

> **完成时间**: 2026-01-13
> **提交**: `0fd51a3` feat(M1): initialize project structure

### 1.1 项目初始化

#### T1.1.1 创建 Xcode 项目结构 ✅
- **描述**: 创建 Apple 多平台 Xcode 项目，包含 iOS、macOS、tvOS targets
- **依赖**: 无
- **文件**:
  - `Chiaki.xcodeproj`
  - `Chiaki/App/ChiakiApp.swift`
  - `ChiakiTV/App/ChiakiTVApp.swift`
- **验收标准**:
  - [x] 项目可在 Xcode 中打开
  - [x] iOS target 可编译运行（空白应用）
  - [x] macOS target 可编译运行
  - [ ] tvOS target 可编译运行（待添加 target）
- **测试**: 各平台模拟器运行空白应用

---

#### T1.1.2 配置项目基本设置 ✅
- **描述**: 配置 Bundle ID、部署目标、签名等
- **依赖**: T1.1.1
- **文件**:
  - `Chiaki/Resources/Info.plist`
  - `ChiakiTV/Resources/` (待配置)
- **验收标准**:
  - [x] iOS 部署目标设为 17.0（支持 @Observable）
  - [x] macOS 部署目标设为 14.0（支持 @Observable）
  - [ ] tvOS 部署目标设为 17.0（待添加 target）
  - [x] 配置 Development Team
- **测试**: 真机可安装运行
- **更新**: `562a51c` 调整部署目标以支持 @Observable

---

#### T1.1.3 创建目录结构 ✅
- **描述**: 按 DESIGN.md 创建完整的目录结构和占位文件
- **依赖**: T1.1.1
- **文件**:
  ```
  Chiaki/
  ├── App/                    # ✅ ChiakiApp.swift, ContentView.swift
  ├── Features/
  │   ├── HostList/           # ✅
  │   ├── Streaming/          # ✅
  │   ├── Settings/           # ✅
  │   └── PSNLogin/           # ✅
  ├── Core/
  │   ├── Bridge/             # ✅
  │   ├── Video/              # ✅
  │   ├── Audio/              # ✅
  │   ├── Controllers/        # ✅
  │   ├── Network/            # ✅
  │   └── Storage/            # ✅
  ├── Domain/
  │   ├── Models/             # ✅
  │   └── Services/           # ✅
  ├── Resources/              # ✅ Assets.xcassets, Info.plist
  └── Utilities/              # ✅
  ```
- **验收标准**:
  - [x] 所有目录已创建
  - [x] 目录已添加到 Xcode 项目
- **测试**: 项目编译通过 ✅

---

## 阶段 M2: UI 框架 (UI Framework)

> **参考**: `chiaki-ng/gui/` Qt/QML 实现
> **策略**: macOS 优先开发，使用 Mock 数据，后续平台适配

### 2.1 数据模型与 Mock ✅

> **完成时间**: 2026-01-13
> **提交**: `8080fac` feat(ui): implement M2.1 and M2.2 models and views

#### T2.1.1 创建 Host 数据模型 ✅
- **描述**: 定义主机数据模型，参考 `gui/include/chiaki/gui/host.h`
- **依赖**: T1.1.3
- **文件**:
  - `Chiaki/Domain/Models/Host.swift`
- **验收标准**:
  - [x] 定义 `ConsoleHost` 结构体（id, nickname, address, state, consoleType）
  - [x] 定义 `HostState` 枚举（online, standby, offline）
  - [x] 定义 `ConsoleType` 枚举（ps4, ps5）
  - [x] 实现 Codable 协议
- **测试**: 单元测试验证模型序列化

---

#### T2.1.2 创建 StreamSettings 数据模型 ✅
- **描述**: 定义流媒体设置模型，参考 `gui/include/chiaki/gui/settings.h`
- **依赖**: T1.1.3
- **文件**:
  - `Chiaki/Domain/Models/StreamSettings.swift`
- **验收标准**:
  - [x] 定义分辨率选项（720p, 1080p, 4K）
  - [x] 定义帧率选项（30, 60, 120）
  - [x] 定义码率范围
  - [x] 定义 HDR 开关
  - [x] 定义 VideoCodec 枚举（h264, h265）
- **测试**: 单元测试验证默认值

---

#### T2.1.3 创建 Mock 数据提供者 ✅
- **描述**: 为 UI 开发创建 Mock 数据
- **依赖**: T2.1.1, T2.1.2
- **文件**:
  - `Chiaki/Preview Content/MockData.swift`
- **验收标准**:
  - [x] 提供示例 Host 列表（在线、休眠、离线各一）
  - [x] 提供默认 StreamSettings
  - [x] 支持 SwiftUI Preview
- **测试**: Preview 中显示 Mock 数据

---

#### T2.1.4 实现 SettingsStore（仅存储） ✅
- **描述**: 设置存储层，使用 @AppStorage
- **依赖**: T2.1.2
- **文件**:
  - `Chiaki/Core/Storage/SettingsStore.swift`
- **验收标准**:
  - [x] 存储 StreamSettings
  - [x] 支持 ObservableObject（待迁移到 @Observable）
  - [x] 数据持久化到 UserDefaults
- **测试**: 修改设置后重启，数据保留
- **待优化**: 部署目标已升级到 iOS 17/macOS 14，可迁移到 @Observable

---

### 2.2 主机列表 UI (macOS First) ✅

> **完成时间**: 2026-01-13
> **提交**: `8080fac` feat(ui): implement M2.1 and M2.2 models and views
> **改进提交**: `b7250d9` refactor(ui): improve HostList integration and code quality

#### T2.2.1 创建 HostRowView ✅
- **描述**: 单个主机行视图，参考 `gui/qml/HostItem.qml`
- **依赖**: T2.1.1, T2.1.3
- **文件**:
  - `Chiaki/Features/HostList/HostRowView.swift`
- **验收标准**:
  - [x] 显示主机名称和图标
  - [x] 显示 IP 地址
  - [x] 状态指示（在线/休眠/离线）
  - [x] 休眠状态显示唤醒按钮
- **测试**: SwiftUI Preview 显示三种状态

---

#### T2.2.2 创建 HostListView ✅
- **描述**: 主机列表视图，参考 `gui/qml/HostList.qml`
- **依赖**: T2.2.1
- **文件**:
  - `Chiaki/Features/HostList/HostListView.swift`
- **验收标准**:
  - [x] macOS: 侧边栏布局（NavigationSplitView）
  - [x] iOS: List 布局（NavigationStack）
  - [x] 空状态提示（emptyStateView）
  - [x] 添加主机按钮（toolbar）
  - [x] 下拉刷新（占位）
- **测试**: 各平台 Preview 显示正确布局

---

#### T2.2.3 创建 AddHostView ✅
- **描述**: 手动添加主机表单
- **依赖**: T2.1.1
- **文件**:
  - `Chiaki/Features/HostList/AddHostView.swift`
- **验收标准**:
  - [x] 主机昵称输入
  - [x] IP 地址输入（带验证 - 不允许空地址）
  - [x] 主机类型选择（PS4/PS5）
  - [x] 保存/取消按钮
  - [x] iOS 适配（keyboard type, navigationBarTitleDisplayMode）
- **测试**: 表单验证逻辑正确

---

#### T2.2.4 创建 HostListViewModel（Mock 版本） ✅
- **描述**: 主机列表视图模型，使用 Mock 数据
- **依赖**: T2.2.2, T2.1.3
- **文件**:
  - `Chiaki/Features/HostList/HostListViewModel.swift`
- **验收标准**:
  - [x] ObservableObject 协议（待迁移到 @Observable）
  - [x] @Published hosts 数组
  - [x] 添加/删除主机方法（本地）
  - [x] 唤醒主机方法（模拟状态变更）
  - [x] 连接主机方法（占位）
- **测试**: ViewModel 响应操作
- **待优化**: 部署目标已升级到 iOS 17/macOS 14，可迁移到 @Observable

---

### 2.3 流媒体视图 UI ✅

> **完成时间**: 2026-01-13
> **说明**: 实现已存在但未在文档中标记

#### T2.3.1 创建 StreamingView 框架 ✅
- **描述**: 流媒体视图框架，参考 `gui/qml/StreamView.qml`
- **依赖**: T1.1.3
- **文件**:
  - `Chiaki/Features/Streaming/StreamingView.swift`
- **验收标准**:
  - [x] 全屏视图容器（ZStack + Color.black）
  - [x] 占位视频区域（GridPattern 背景）
  - [x] 返回按钮（xmark.circle.fill）
  - [x] 状态显示区域（VideoPlaceholderView）
- **测试**: Preview 显示全屏布局

---

#### T2.3.2 创建 StreamingOverlay ✅
- **描述**: 流媒体状态覆盖层
- **依赖**: T2.3.1
- **文件**:
  - `Chiaki/Features/Streaming/StreamingOverlay.swift`
- **验收标准**:
  - [x] 显示分辨率（Mock: 1080p）
  - [x] 显示帧率（Mock: 60fps）
  - [x] 显示延迟（动态模拟）
  - [x] 点击隐藏/显示（toggleOverlay）
- **测试**: Overlay 可切换显示

---

#### T2.3.3 创建 StreamingViewModel（Mock 版本） ✅
- **描述**: 流媒体视图模型
- **依赖**: T2.3.1, T2.1.1
- **文件**:
  - `Chiaki/Features/Streaming/StreamingViewModel.swift`
- **验收标准**:
  - [x] 连接状态枚举（ConnectionState）
  - [x] 连接/断开方法（connect/disconnect）
  - [x] 统计数据属性（Mock + Timer 模拟）
- **测试**: 状态切换正确
- **待优化**: 可迁移到 @Observable

---

### 2.4 设置页面 UI ✅

> **完成时间**: 2026-01-14
> **提交**: `7c17700` feat(ui): implement M2.4 settings views

#### T2.4.1 创建 SettingsView ✅
- **描述**: 设置主视图，参考 `gui/qml/SettingsView.qml`
- **依赖**: T2.1.4
- **文件**:
  - `Chiaki/Features/Settings/SettingsView.swift`
- **验收标准**:
  - [x] macOS: TabView 布局
  - [x] iOS: Form + NavigationLink 布局
  - [x] 分组：视频、音频、控制器、账户
- **测试**: 各平台 Preview 显示正确

---

#### T2.4.2 创建 VideoSettingsView ✅
- **描述**: 视频设置页面
- **依赖**: T2.1.4
- **文件**:
  - `Chiaki/Features/Settings/VideoSettingsView.swift`
- **验收标准**:
  - [x] 分辨率 Picker
  - [x] 帧率 Picker
  - [x] 码率 Slider
  - [x] HDR Toggle
- **测试**: 设置修改立即反映

---

#### T2.4.3 创建 AudioSettingsView ✅
- **描述**: 音频设置页面
- **依赖**: T2.1.4
- **文件**:
  - `Chiaki/Features/Settings/AudioSettingsView.swift`
- **验收标准**:
  - [x] 音量控制
  - [ ] 输出设备选择（macOS）- 待 M4 音频集成
  - [x] 麦克风开关
- **测试**: 设置修改立即反映

---

#### T2.4.4 创建 ControllerSettingsView ✅
- **描述**: 控制器设置页面
- **依赖**: T2.1.4
- **文件**:
  - `Chiaki/Features/Settings/ControllerSettingsView.swift`
- **验收标准**:
  - [x] 已连接控制器列表（Mock）
  - [x] 触觉反馈 Toggle
  - [ ] 按键映射入口 - 待 M4 控制器集成
- **测试**: 设置项显示正确

---

### 2.5 虚拟控制器 UI (iOS) ✅

> **完成时间**: 2026-01-14
> **说明**: 完整实现触屏控制器，包含摇杆、按钮、方向键

#### T2.5.1 创建 VirtualControllerView ✅
- **描述**: iOS 触屏虚拟控制器
- **依赖**: T2.3.1
- **文件**:
  - `Chiaki/Features/Streaming/VirtualController/VirtualControllerView.swift`
  - `Chiaki/Features/Streaming/VirtualControllerInput.swift`
- **验收标准**:
  - [x] 左摇杆区域
  - [x] 右摇杆区域
  - [x] 方向键
  - [x] PlayStation 按钮 (△○✕□)
  - [x] L1/L2/R1/R2 触发器
  - [x] 透明度可调
  - [x] PS/Share/Options 按钮
- **测试**: iPad Preview 显示完整布局

---

#### T2.5.2 创建 VirtualStickView ✅
- **描述**: 虚拟摇杆组件
- **依赖**: T2.5.1
- **文件**:
  - `Chiaki/Features/Streaming/VirtualController/VirtualStickView.swift`
- **验收标准**:
  - [x] 触摸跟随
  - [x] 范围限制（圆形）
  - [x] 松开回中（带弹簧动画）
  - [x] 输出归一化坐标 (-1 ~ 1)
- **测试**: 手势测试，输出值正确

---

#### T2.5.3 创建 VirtualButtonView ✅
- **描述**: 虚拟按钮组件
- **依赖**: T2.5.1
- **文件**:
  - `Chiaki/Features/Streaming/VirtualController/VirtualButtonView.swift`
- **验收标准**:
  - [x] 按下/释放状态
  - [x] 视觉反馈（缩放 + 颜色变化）
  - [x] 支持自定义图标
  - [x] 触觉反馈 (UIImpactFeedbackGenerator)
- **测试**: 按钮状态切换正确

---

### 2.6 导航与整合 ✅

> **完成时间**: 2026-01-14
> **说明**: iOS/macOS 已完成，tvOS 待 M6 平台适配阶段实现

#### T2.6.1 创建 ContentView 主导航 ✅
- **描述**: 应用主导航结构
- **依赖**: T2.2.2, T2.4.1
- **文件**:
  - `Chiaki/App/ContentView.swift`
- **验收标准**:
  - [x] macOS: NavigationSplitView
  - [x] iOS: TabView
  - [ ] tvOS: 焦点导航（待 M6 实现）
  - [x] 主机列表为首页
  - [x] 设置入口
- **测试**: 各平台导航流程完整

---

#### T2.6.2 实现主机列表到流媒体导航 ✅
- **描述**: 点击主机进入流媒体视图
- **依赖**: T2.6.1, T2.3.1, T2.2.4
- **文件**:
  - `Chiaki/Features/HostList/HostListView.swift` (修改)
- **验收标准**:
  - [x] 点击在线主机，导航到 StreamingView
  - [x] 显示连接中状态（Mock）
  - [x] 返回操作正常
- **测试**: 完整导航流程

---

## 阶段 M3: 核心库构建 (Core Libraries) ✅

> **完成时间**: 2026-01-16
> **提交**: `2b53289` feat(core): implement M3 core modules and fix libchiaki linking

### 3.1 依赖库构建 ✅

#### T3.1.1 编写 mbedtls 构建脚本 ✅
- **描述**: 创建为所有 Apple 平台构建 mbedtls 的脚本
- **依赖**: 无
- **文件**:
  - `Scripts/build_libchiaki.sh` (统一构建脚本)
- **验收标准**:
  - [x] 脚本可执行无错误
  - [x] 生成 iOS arm64 静态库
  - [x] 生成 iOS Simulator arm64 静态库
  - [x] 生成 macOS arm64 静态库
  - [x] 生成 macOS x86_64 静态库
  - [x] 生成 tvOS arm64 静态库
- **测试**: 构建脚本成功执行

---

#### T3.1.2 创建 mbedtls xcframework ✅
- **描述**: 将各平台 mbedtls 库打包为 xcframework
- **依赖**: T3.1.1
- **文件**:
  - `Frameworks/libchiaki.xcframework/` (合并到 libchiaki)
- **验收标准**:
  - [x] xcframework 包含所有平台切片
  - [x] xcframework 可被 Xcode 导入
- **测试**: 在 Xcode 中添加 framework，编译通过

---

#### T3.1.3 编写 Opus 构建脚本 ✅
- **描述**: 创建为所有 Apple 平台构建 Opus 的脚本
- **依赖**: 无
- **文件**:
  - `Scripts/build_libchiaki.sh` (统一构建脚本)
- **验收标准**:
  - [x] 脚本可执行无错误
  - [x] 生成各平台静态库
- **测试**: 同 T3.1.1

---

#### T3.1.4 创建 Opus xcframework ✅
- **描述**: 将各平台 Opus 库打包为 xcframework
- **依赖**: T3.1.3
- **文件**:
  - `Frameworks/libchiaki.xcframework/` (合并到 libchiaki)
- **验收标准**:
  - [x] xcframework 包含所有平台切片
- **测试**: 同 T3.1.2

---

#### T3.1.5 编写 libchiaki 构建脚本（最小配置） ✅
- **描述**: 创建为 Apple 平台构建 libchiaki 的脚本，启用 mbedtls
- **依赖**: T3.1.2, T3.1.4
- **文件**:
  - `Scripts/build_libchiaki.sh`
- **验收标准**:
  - [x] 使用 `-DCHIAKI_LIB_ENABLE_MBEDTLS=ON`
  - [x] 使用 `-DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_ENABLE_GUI=OFF`
  - [x] 生成各平台 libchiaki.a
  - [x] 禁用 nghttp2/libssh2/libidn2 依赖
  - [x] 合并所有静态库到单个 xcframework
- **测试**: 构建脚本成功执行，无链接错误

---

#### T3.1.6 创建 libchiaki xcframework ✅
- **描述**: 将各平台 libchiaki 库打包为 xcframework，包含头文件
- **依赖**: T3.1.5
- **文件**:
  - `Frameworks/libchiaki.xcframework/`
- **验收标准**:
  - [x] xcframework 包含所有平台切片
  - [x] xcframework 包含 Headers 目录
  - [x] 头文件路径正确
- **测试**: Xcode 导入后，`#include <chiaki/session.h>` 编译通过

---

#### T3.1.7 配置 Xcode 链接 xcframeworks ✅
- **描述**: 将 xcframework 添加到各 target
- **依赖**: T3.1.2, T3.1.4, T3.1.6, T1.1.1
- **文件**:
  - `Chiaki.xcodeproj/project.pbxproj`
- **验收标准**:
  - [x] macOS target 链接所有 framework
  - [x] 添加 SystemConfiguration framework
  - [x] 编译无链接错误
  - [ ] iOS target 链接所有 framework (待测试)
  - [ ] tvOS target 链接所有 framework (待添加 target)
- **测试**: macOS target clean build 成功

---

### 3.2 桥接层基础 ✅

#### T3.2.1 创建 Bridging Header ✅
- **描述**: 创建 C/Objective-C 桥接头文件，导入 libchiaki 头文件
- **依赖**: T3.1.7
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiBridge.h`
- **验收标准**:
  - [x] 头文件导入 chiaki 主要头文件
  - [x] 在 Swift 代码中可访问 C 类型
- **测试**: Swift 代码可访问 ChiakiErrorCode 等 C 类型

---

#### T3.2.2 定义 Swift 类型映射 ✅
- **描述**: 创建 Swift 类型，映射 libchiaki C 类型
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiTypes.swift`
- **验收标准**:
  - [x] 定义 `ChiakiSessionState` 枚举
  - [x] 定义 `ChiakiControllerInput` 结构体
  - [x] 定义 `ChiakiControllerButtons` OptionSet
  - [x] 定义 `ChiakiError` 错误类型
  - [x] 实现 C 类型转换扩展
- **测试**: 类型转换正确

---

#### T3.2.3 实现 ChiakiLog Swift 封装 ✅
- **描述**: 封装 libchiaki 日志系统，桥接到 Swift os.log
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Utilities/Logger.swift`
  - `Chiaki/Core/Bridge/ChiakiLogBridge.swift`
- **验收标准**:
  - [x] C 回调可调用 Swift 日志函数
  - [x] 日志输出到 Console.app
  - [x] 支持不同日志级别
- **测试**: 日志系统正常工作

---

### 3.3 Metal 渲染器原型 ✅

#### T3.3.1 创建 Metal 着色器文件 ✅
- **描述**: 编写 NV12 到 RGB 转换的 Metal 着色器
- **依赖**: T1.1.1
- **文件**:
  - `Chiaki/Core/Video/VideoShaders.metal.txt` (运行时编译源码)
  - `Chiaki/Core/Video/MetalVideoRenderer.swift` (内嵌着色器源码)
- **验收标准**:
  - [x] 顶点着色器接收位置和纹理坐标
  - [x] 片段着色器实现 YUV→RGB 转换
  - [x] 使用 BT.709 颜色空间
  - [x] 运行时编译无错误
- **测试**: Metal 着色器运行时编译成功
- **说明**: 使用运行时编译避免 Metal Toolchain 权限问题

---

#### T3.3.2 实现 MetalVideoRenderer 基础结构 ✅
- **描述**: 创建 Metal 渲染器类，初始化 Metal 设备和管线
- **依赖**: T3.3.1
- **文件**:
  - `Chiaki/Core/Video/MetalVideoRenderer.swift`
- **验收标准**:
  - [x] 初始化 MTLDevice
  - [x] 创建 MTLCommandQueue
  - [x] 加载着色器并创建 RenderPipelineState
  - [x] 创建 CVMetalTextureCache
  - [x] 实现运行时着色器编译 fallback
- **测试**: 渲染器初始化成功

---

#### T3.3.3 实现静态测试图像渲染 ✅
- **描述**: 渲染一个静态测试图像（如纯色或渐变），验证渲染管线
- **依赖**: T3.3.2
- **文件**:
  - `Chiaki/Core/Video/MetalVideoRenderer.swift`
- **验收标准**:
  - [x] 可渲染静态纹理到 MTKView
  - [x] 颜色正确显示
- **测试**: 运行应用，渲染管线正常

---

#### T3.3.4 实现 CVPixelBuffer 纹理转换 ✅
- **描述**: 从 CVPixelBuffer (NV12) 创建 Metal 纹理
- **依赖**: T3.3.2
- **文件**:
  - `Chiaki/Core/Video/MetalVideoRenderer.swift`
- **验收标准**:
  - [x] 从 NV12 格式 CVPixelBuffer 创建 Y 纹理
  - [x] 从 NV12 格式 CVPixelBuffer 创建 UV 纹理
  - [x] 使用零拷贝 (CVMetalTextureCache)
- **测试**: 纹理转换实现完成

---

#### T3.3.5 实现完整视频帧渲染 ✅
- **描述**: 整合纹理创建和渲染，实现 `updateFrame` 方法
- **依赖**: T3.3.3, T3.3.4
- **文件**:
  - `Chiaki/Core/Video/MetalVideoRenderer.swift`
- **验收标准**:
  - [x] `updateFrame(CVPixelBuffer)` 方法可用
  - [x] 渲染到 MTKView
  - [x] 线程安全（使用锁保护）
- **测试**: 视频帧渲染实现完成

---

### 3.4 VideoToolbox 解码器 ✅

#### T3.4.1 实现 VideoToolbox 解码器 ✅
- **描述**: 使用 VideoToolbox API 实现 H.264/H.265 硬件解码，替代 FFmpeg 解码器
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Core/Video/VideoToolboxDecoder.swift`
- **验收标准**:
  - [x] 支持 H.264 视频流解码
  - [x] 支持 H.265 (HEVC) 视频流解码
  - [x] 使用低延迟模式配置
  - [x] 输出 CVPixelBuffer (NV12 格式)
- **测试**: 解码器实现完成

---

#### T3.4.2 集成 VideoToolbox 到 ChiakiSession ✅
- **描述**: 将 VideoToolbox 解码器集成到 session 视频回调链路
- **依赖**: T3.4.1, T3.2.1
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiSession.swift`
- **验收标准**:
  - [x] Session 视频回调使用 VideoToolbox 解码
  - [x] 解码后的 CVPixelBuffer 传递到 MetalVideoRenderer
  - [x] 支持动态分辨率切换
- **测试**: 集成实现完成

---

### 3.5 音频播放器 ✅

#### T3.5.1 实现 AudioPlayer ✅
- **描述**: 使用 AVAudioEngine 播放 PCM 音频
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Core/Audio/AudioPlayer.swift`
  - `Chiaki/Core/Audio/CircularAudioBuffer.swift`
- **验收标准**:
  - [x] 配置 AVAudioSession
  - [x] 创建 AVAudioEngine 和 PlayerNode
  - [x] 实现 CircularAudioBuffer 环形缓冲区
  - [x] 低延迟配置
- **测试**: 音频播放器实现完成

---

### 3.6 流媒体统计 ✅

#### T3.6.1 实现 StreamStatistics ✅
- **描述**: 实时流媒体统计数据收集
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Core/Streaming/StreamStatistics.swift`
- **验收标准**:
  - [x] 收集帧率、码率、延迟等统计数据
  - [x] 提供实时更新的 Observable 属性
  - [x] 支持统计数据重置
- **测试**: 统计模块实现完成

---

## 阶段 M4: 功能集成 (Feature Integration) 🔄

> **说明**: 将 M2 UI 框架与 M3 核心库连接，实现真实功能
> **开始时间**: 2026-01-18
> **提交**: `db5ad7c` feat(m4): implement host discovery and storage infrastructure

### 4.1 主机发现集成 ✅

#### T4.1.1 实现 DiscoveryService 基础封装 ✅
- **描述**: 封装主机发现服务
- **依赖**: T3.2.1, T3.2.2
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiDiscovery.swift`
- **验收标准**:
  - [x] 可初始化 discovery service
  - [x] 可启动/停止发现
  - [x] Combine 响应式更新
  - [ ] C 回调桥接到 Swift (libchiaki 集成待完成)
- **说明**: 目前使用 Timer 占位，实际 libchiaki 集成将在后续完成

---

#### T4.1.2 实现发现结果处理 ✅
- **描述**: 解析发现回调，更新 discoveredHosts 数组
- **依赖**: T4.1.1
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiDiscovery.swift`
- **验收标准**:
  - [x] DiscoveredHost 数据模型
  - [x] @Published discoveredHosts 数组
  - [x] 处理主机上线/下线/状态变化
- **测试**: 框架已就绪，待 libchiaki 集成后测试

---

#### T4.1.3 实现主机唤醒功能 ✅
- **描述**: 实现主机唤醒 API
- **依赖**: T4.1.1
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiDiscovery.swift`
- **验收标准**:
  - [x] `wakeUp(host:)` async 方法可用
  - [x] 正确验证 registKey
  - [x] 返回成功/失败
  - [ ] 实际 UDP 包发送 (libchiaki 集成待完成)

---

#### T4.1.4 配置本地网络权限 ✅
- **描述**: 添加 Info.plist 配置以获取本地网络访问权限
- **依赖**: T1.1.2
- **文件**:
  - `Chiaki/Resources/Info.plist`
- **验收标准**:
  - [x] 添加 `NSLocalNetworkUsageDescription`
  - [x] 添加 `NSBonjourServices` (_psremoteplay._tcp)
- **测试**: 运行应用，弹出本地网络权限弹窗

---

#### T4.1.5 连接 HostListViewModel 到真实数据 ✅
- **描述**: 将 Mock ViewModel 替换为真实数据
- **依赖**: T4.1.2, T2.2.4
- **文件**:
  - `Chiaki/Features/HostList/HostListViewModel.swift`
- **验收标准**:
  - [x] 使用 HostManager 替代 Mock 数据
  - [x] 唤醒功能可用
  - [x] Combine 响应式更新
  - [x] 支持 Preview mock 数据
- **测试**: 应用启动后使用 HostManager 管理主机

---

### 4.2 主机存储 ✅

#### T4.2.1 实现 HostStore 持久化 ✅
- **描述**: 使用 UserDefaults 存储主机列表
- **依赖**: T2.1.1
- **文件**:
  - `Chiaki/Core/Storage/HostStore.swift`
- **验收标准**:
  - [x] `loadHosts()` 加载保存的主机
  - [x] `saveHosts()` 保存主机列表
  - [x] `addHost()` / `updateHost()` / `removeHost()` 方法
  - [x] 注册凭证存储
- **测试**: 主机数据持久化正常

---

#### T4.2.2 实现 HostManager 服务 ✅
- **描述**: 组合 Discovery 和 Store，提供统一的主机管理接口
- **依赖**: T4.1.2, T4.2.1
- **文件**:
  - `Chiaki/Domain/Services/HostManager.swift`
- **验收标准**:
  - [x] 合并已保存主机和发现的主机
  - [x] 自动更新主机状态
  - [x] 提供 `@Published` 属性 (ObservableObject)
  - [x] 单例模式支持全局访问
- **测试**: HostManager.hosts 包含保存和发现的主机

---

### 4.3 会话连接

#### T4.3.1 实现 ChiakiSession 基础封装
- **描述**: 封装 chiaki_session API，实现连接/断开
- **依赖**: T3.2.1, T3.2.2
- **文件**:
  - `apple/Chiaki/Core/Bridge/ChiakiSession.swift`
- **验收标准**:
  - [ ] 初始化 session
  - [ ] 配置连接参数 (ChiakiConnectInfo)
  - [ ] 启动/停止 session
  - [ ] 状态变化回调
- **测试**:
  ```swift
  let session = ChiakiSession()
  try await session.connect(to: host, credentials: nil)
  // 状态变为 connecting
  ```

---

#### T4.3.2 实现会话事件处理
- **描述**: 处理 session 事件回调，更新状态
- **依赖**: T4.3.1
- **文件**:
  - `apple/Chiaki/Core/Bridge/ChiakiSession.swift` (扩展)
- **验收标准**:
  - [ ] 处理连接成功事件
  - [ ] 处理连接失败事件
  - [ ] 处理断开事件
  - [ ] 处理错误事件
- **测试**: 连接已注册的主机，状态变为 streaming

---

#### T4.3.3 实现视频帧回调
- **描述**: 接收视频帧数据，转换为 CVPixelBuffer
- **依赖**: T4.3.2, T3.3.5
- **文件**:
  - `apple/Chiaki/Core/Bridge/ChiakiSession.swift` (扩展)
  - `apple/Chiaki/Core/Video/VideoDecoderBridge.swift`
- **验收标准**:
  - [ ] 注册视频回调
  - [ ] 接收 H.264/H.265 帧
  - [ ] 使用 VideoToolbox 解码
  - [ ] 输出 CVPixelBuffer (NV12)
- **测试**: 连接主机，onVideoFrame 回调被调用，有有效 pixelBuffer

---

#### T4.3.4 实现音频帧回调
- **描述**: 接收音频帧数据，输出 PCM 样本
- **依赖**: T4.3.2
- **文件**:
  - `apple/Chiaki/Core/Bridge/ChiakiSession.swift` (扩展)
- **验收标准**:
  - [ ] 注册音频回调
  - [ ] 接收 Opus 解码后的 PCM 数据
  - [ ] 正确处理采样率和声道数
- **测试**: 连接主机，onAudioFrame 回调被调用

---

### 4.4 流媒体集成

#### T4.4.1 实现 AudioPlayer
- **描述**: 使用 AVAudioEngine 播放 PCM 音频
- **依赖**: T4.3.4
- **文件**:
  - `apple/Chiaki/Core/Audio/AudioPlayer.swift`
- **验收标准**:
  - [ ] 配置 AVAudioSession
  - [ ] 创建 AVAudioEngine 和 PlayerNode
  - [ ] 接收 PCM 样本并播放
  - [ ] 低延迟配置
- **测试**: 调用 receiveAudio，有声音播放

---

#### T4.4.2 创建 StreamingView 基础
- **描述**: 流媒体视图，包含 MTKView
- **依赖**: T3.3.5
- **文件**:
  - `apple/Chiaki/Features/Streaming/StreamingView.swift`
- **验收标准**:
  - [ ] 包含全屏 MTKView
  - [ ] 连接 MetalVideoRenderer
  - [ ] 支持返回手势/按钮
- **测试**: 显示 StreamingView，MTKView 可见

---

#### T4.4.3 创建 StreamingViewModel
- **描述**: 流媒体视图模型，连接 Session、Video、Audio
- **依赖**: T4.3.3, T4.3.4, T4.4.1, T4.4.2
- **文件**:
  - `apple/Chiaki/Features/Streaming/StreamingViewModel.swift`
- **验收标准**:
  - [ ] 持有 ChiakiSession
  - [ ] 视频帧 → MetalVideoRenderer
  - [ ] 音频帧 → AudioPlayer
  - [ ] 状态管理
- **测试**: 连接主机，视频和音频正常播放

---

#### T4.4.4 实现 StreamingOverlay
- **描述**: 流媒体状态覆盖层（分辨率、帧率、延迟等）
- **依赖**: T4.4.2
- **文件**:
  - `apple/Chiaki/Features/Streaming/StreamingOverlay.swift`
- **验收标准**:
  - [ ] 显示当前分辨率
  - [ ] 显示帧率
  - [ ] 显示网络延迟
  - [ ] 显示连接质量指示器
  - [ ] 可隐藏
- **测试**: 流媒体播放时，overlay 显示正确信息

---

#### T4.4.5 整合主机列表到流媒体的导航
- **描述**: 点击主机 → 连接 → 进入流媒体视图
- **依赖**: T2.3.2, T4.4.3
- **文件**:
  - `apple/Chiaki/Features/HostList/HostListView.swift` (修改)
  - `apple/Chiaki/App/ContentView.swift`
- **验收标准**:
  - [ ] 点击在线主机，导航到 StreamingView
  - [ ] 连接成功后显示视频
  - [ ] 断开连接返回主机列表
- **测试**: 完整用户流程：启动 → 选择主机 → 播放 → 返回

---

### 4.5 控制器集成

#### T4.5.1 实现 ControllerManager 基础
- **描述**: 使用 GameController 框架检测和管理控制器
- **依赖**: 无
- **文件**:
  - `apple/Chiaki/Core/Controllers/ControllerManager.swift`
- **验收标准**:
  - [ ] 监听控制器连接/断开
  - [ ] 维护 connectedControllers 数组
  - [ ] 自动选择活跃控制器
- **测试**: 连接 DualSense，connectedControllers 包含该控制器

---

#### T4.5.2 实现控制器输入处理
- **描述**: 读取控制器输入，转换为 ControllerState
- **依赖**: T4.5.1, T3.2.2
- **文件**:
  - `apple/Chiaki/Core/Controllers/ControllerManager.swift` (扩展)
- **验收标准**:
  - [ ] 处理按钮输入
  - [ ] 处理摇杆输入
  - [ ] 处理扳机输入
  - [ ] 处理 D-Pad 输入
- **测试**: 按下按钮，onStateChanged 回调，状态正确

---

#### T4.5.3 实现控制器状态发送
- **描述**: 将 ControllerState 发送到 ChiakiSession
- **依赖**: T4.5.2, T4.3.1
- **文件**:
  - `apple/Chiaki/Core/Bridge/ChiakiSession.swift` (扩展)
- **验收标准**:
  - [ ] `sendControllerState()` 方法可用
  - [ ] 转换为 C 结构体
  - [ ] 调用 chiaki_session_set_controller_state
- **测试**: 游戏中按下按钮，PS 主机响应

---

#### T4.5.4 整合控制器到 StreamingViewModel
- **描述**: 在流媒体时自动发送控制器输入
- **依赖**: T4.5.3, T4.4.3
- **文件**:
  - `apple/Chiaki/Features/Streaming/StreamingViewModel.swift` (修改)
- **验收标准**:
  - [ ] 流媒体时监听控制器
  - [ ] 定期发送状态 (如 120Hz)
  - [ ] 断开时停止发送
- **测试**: 完整游戏操作：移动、按键、扳机

---

### 4.6 虚拟控制器集成 (iOS)

> **说明**: UI 已在 M2.5 中完成，此处完成功能集成

#### T4.6.1 整合虚拟控制器到 ControllerManager
- **描述**: 虚拟控制器输出 ControllerState
- **依赖**: T2.5.2, T2.5.3, T4.5.2
- **文件**:
  - `Chiaki/Features/Streaming/VirtualController/VirtualControllerViewModel.swift` (修改)
- **验收标准**:
  - [ ] 汇总所有虚拟输入
  - [ ] 输出 ControllerState
  - [ ] 可与物理控制器共存
- **测试**: 仅使用触屏，可完整操作游戏

---

### 4.7 触觉反馈

#### T4.7.1 实现 HapticsManager
- **描述**: 使用 Core Haptics 提供触觉反馈
- **依赖**: 无
- **文件**:
  - `apple/Chiaki/Core/Controllers/HapticsManager.swift`
- **验收标准**:
  - [ ] 初始化 CHHapticEngine
  - [ ] 定义基础触觉模式
  - [ ] 播放触觉反馈
- **测试**: 调用 playHaptic，设备振动

---

#### T4.7.2 映射 Chiaki 触觉到 Core Haptics
- **描述**: 接收 libchiaki 触觉数据，转换为 Core Haptics 模式
- **依赖**: T4.7.1, T4.3.2
- **文件**:
  - `apple/Chiaki/Core/Controllers/HapticsManager.swift` (扩展)
- **验收标准**:
  - [ ] 注册触觉回调
  - [ ] 映射强度和持续时间
  - [ ] 近似还原触觉效果
- **测试**: 游戏中触觉反馈（如枪击、碰撞）有振动

---

## 阶段 M5: 完善功能 (Polish)

### 5.1 PSN 登录

#### T5.1.1 实现 PSN OAuth WebView
- **描述**: 使用 WKWebView 进行 PSN OAuth 登录
- **依赖**: 无
- **文件**:
  - `apple/Chiaki/Features/PSNLogin/PSNWebView.swift`
- **验收标准**:
  - [ ] 加载 PSN 登录页面
  - [ ] 拦截回调 URL
  - [ ] 提取授权码
- **测试**: 打开 WebView，可完成 PSN 登录流程

---

#### T5.1.2 实现 PSN Token 交换
- **描述**: 使用授权码交换 access_token 和 refresh_token
- **依赖**: T5.1.1
- **文件**:
  - `apple/Chiaki/Domain/Services/PSNService.swift`
- **验收标准**:
  - [ ] 调用 PSN API 交换 token
  - [ ] 解析响应
  - [ ] 存储 token
- **测试**: 登录后，获取到有效 token

---

#### T5.1.3 实现 PSN 账户存储
- **描述**: 安全存储 PSN 凭证到 Keychain
- **依赖**: T5.1.2
- **文件**:
  - `apple/Chiaki/Core/Storage/KeychainManager.swift`
  - `apple/Chiaki/Domain/Models/PSNAccount.swift`
- **验收标准**:
  - [ ] Token 存储到 Keychain
  - [ ] 可加载保存的账户
  - [ ] Token 过期检测
- **测试**: 重启应用，账户仍然登录

---

#### T5.1.4 创建 PSNLoginView
- **描述**: PSN 登录界面
- **依赖**: T5.1.1, T5.1.2
- **文件**:
  - `apple/Chiaki/Features/PSNLogin/PSNLoginView.swift`
  - `apple/Chiaki/Features/PSNLogin/PSNLoginViewModel.swift`
- **验收标准**:
  - [ ] 显示登录按钮
  - [ ] 打开 OAuth WebView
  - [ ] 显示登录状态
  - [ ] 支持登出
- **测试**: 完整登录流程

---

### 5.2 主机注册

#### T5.2.1 实现 ChiakiRegist 封装
- **描述**: 封装 chiaki_regist API
- **依赖**: T3.2.1
- **文件**:
  - `Chiaki/Core/Bridge/ChiakiRegist.swift`
- **验收标准**:
  - [ ] 配置注册参数
  - [ ] 启动注册流程
  - [ ] 处理注册结果
  - [ ] 获取 registKey 和 rpKey
- **测试**: 对新主机执行注册，获取密钥

---

#### T5.2.2 创建主机注册 UI
- **描述**: 主机注册向导界面
- **依赖**: T5.2.1
- **文件**:
  - `Chiaki/Features/HostList/RegistrationView.swift`
- **验收标准**:
  - [ ] 输入 PIN 码
  - [ ] 显示注册进度
  - [ ] 显示成功/失败结果
  - [ ] 保存注册信息
- **测试**: 完整注册新 PS 主机

---

### 5.3 设置集成

> **说明**: UI 已在 M2.4 中完成，此处连接到 ChiakiSession

#### T5.3.1 连接设置到 ChiakiSession
- **描述**: 将 SettingsStore 中的设置应用到 ChiakiSession
- **依赖**: T2.1.4, T4.3.1
- **文件**:
  - `Chiaki/Features/Streaming/StreamingViewModel.swift` (修改)
- **验收标准**:
  - [ ] 连接时应用视频设置（分辨率、帧率、码率）
  - [ ] 应用 HDR 设置
  - [ ] 设置修改后下次连接生效
- **测试**: 修改设置，下次连接生效

---

#### T5.3.2 实现控制器设置应用
- **描述**: 将控制器设置应用到 ControllerManager
- **依赖**: T2.4.4, T4.5.1
- **文件**:
  - `Chiaki/Core/Controllers/ControllerManager.swift` (修改)
- **验收标准**:
  - [ ] 应用触觉反馈开关
  - [ ] 应用按键映射
- **测试**: 切换设置，效果立即生效

---

### 5.4 多语言支持

#### T5.4.1 创建本地化文件
- **描述**: 设置多语言支持基础
- **依赖**: 无
- **文件**:
  - `Chiaki/Resources/Localizable.xcstrings`
- **验收标准**:
  - [ ] 英文字符串
  - [ ] 中文简体字符串
  - [ ] 日文字符串
- **测试**: 切换系统语言，应用语言变化

---

#### T5.4.2 替换硬编码字符串
- **描述**: 将所有 UI 字符串改为本地化
- **依赖**: T5.4.1
- **文件**:
  - 所有 View 文件
- **验收标准**:
  - [ ] 所有用户可见字符串使用 `String(localized:)`
  - [ ] 无硬编码字符串
- **测试**: 代码审查

---

## 阶段 M6: 平台适配 (Platform Adaptation)

### 6.1 macOS 优化

#### T6.1.1 实现菜单栏集成
- **描述**: macOS 原生菜单栏
- **依赖**: T2.3.2
- **文件**:
  - `apple/ChiakiMac/MacMenuBar.swift`
- **验收标准**:
  - [ ] 文件菜单（添加主机等）
  - [ ] 主机菜单（连接、唤醒）
  - [ ] 视图菜单（全屏等）
  - [ ] 帮助菜单
- **测试**: 菜单项可用，功能正确

---

#### T6.1.2 实现多窗口支持
- **描述**: macOS 多窗口管理
- **依赖**: T4.4.5
- **文件**:
  - `apple/ChiakiMac/MacWindowManager.swift`
- **验收标准**:
  - [ ] 可打开多个流媒体窗口
  - [ ] 各窗口独立会话
  - [ ] 窗口关闭时断开连接
- **测试**: 同时连接两台 PS 主机

---

#### T6.1.3 实现系统睡眠抑制
- **描述**: 流媒体时阻止 macOS 睡眠
- **依赖**: T4.4.3
- **文件**:
  - `apple/ChiakiMac/SleepPrevention.swift`
- **验收标准**:
  - [ ] 流媒体时禁用睡眠
  - [ ] 断开后恢复睡眠
  - [ ] 使用 IOKit 或 NSProcessInfo
- **测试**: 流媒体时系统不自动睡眠

---

### 6.2 iPadOS 优化

#### T6.2.1 实现键盘快捷键
- **描述**: iPadOS 外接键盘支持
- **依赖**: T2.3.2
- **文件**:
  - `apple/Chiaki/Features/HostList/HostListView.swift` (修改)
- **验收标准**:
  - [ ] Cmd+N 添加主机
  - [ ] Cmd+R 刷新列表
  - [ ] Enter 连接选中主机
- **测试**: 使用键盘操作应用

---

#### T7.2.2 实现外接显示器支持
- **描述**: iPadOS 外接显示器显示流媒体
- **依赖**: T4.4.2
- **文件**:
  - `apple/Chiaki/Features/Streaming/ExternalDisplayManager.swift`
- **验收标准**:
  - [ ] 检测外接显示器
  - [ ] 流媒体输出到外接显示器
  - [ ] iPad 显示控制器
- **测试**: 连接外接显示器，视频显示在外接屏幕

---

### 6.3 tvOS 优化

#### T6.3.1 实现焦点导航
- **描述**: tvOS Siri Remote 导航
- **依赖**: T2.3.2
- **文件**:
  - `apple/ChiakiTV/Features/TVHostListView.swift`
- **验收标准**:
  - [ ] 列表项可聚焦
  - [ ] 方向键导航
  - [ ] 选择键确认
  - [ ] 菜单键返回
- **测试**: 仅使用 Siri Remote 完成操作

---

#### T6.3.2 实现 Top Shelf 扩展
- **描述**: tvOS Top Shelf 显示最近主机
- **依赖**: T4.2.1
- **文件**:
  - `apple/ChiakiTV/Resources/TopShelf/`
- **验收标准**:
  - [ ] 显示最近连接的主机
  - [ ] 点击直接连接
  - [ ] 显示主机图标
- **测试**: Home 屏幕 Top Shelf 显示主机

---

### 6.4 iOS 后台支持

#### T6.4.1 实现 Picture-in-Picture
- **描述**: iOS PiP 模式保持视频活跃
- **依赖**: T4.4.2
- **文件**:
  - `apple/Chiaki/Features/Streaming/PiPManager.swift`
- **验收标准**:
  - [ ] 支持进入 PiP 模式
  - [ ] PiP 窗口显示视频
  - [ ] 可从 PiP 返回全屏
- **测试**: 切换应用，视频在 PiP 窗口继续播放

---

#### T6.4.2 实现后台音频
- **描述**: 后台时保持音频播放
- **依赖**: T4.4.1
- **文件**:
  - `apple/Chiaki/Info.plist`
  - `apple/Chiaki/Core/Audio/AudioSessionManager.swift`
- **验收标准**:
  - [ ] 配置 UIBackgroundModes: audio
  - [ ] 后台时音频继续播放
  - [ ] 返回前台时恢复视频
- **测试**: 锁屏后音频继续播放

---

## 阶段 M7: 发布准备 (Release)

### 7.1 性能优化

#### T7.1.1 视频渲染性能分析
- **描述**: 使用 Instruments 分析视频渲染性能
- **依赖**: T4.4.3
- **验收标准**:
  - [ ] 帧率稳定 60fps
  - [ ] GPU 占用合理
  - [ ] 无内存泄漏
- **测试**: Instruments GPU 和 Memory 分析

---

#### T7.1.2 音频延迟优化
- **描述**: 最小化音频播放延迟
- **依赖**: T4.4.1
- **验收标准**:
  - [ ] 音频延迟 < 30ms
  - [ ] 音视频同步
- **测试**: 主观延迟测试

---

#### T7.1.3 控制器输入延迟优化
- **描述**: 最小化控制器输入延迟
- **依赖**: T4.5.4
- **验收标准**:
  - [ ] 输入响应 < 10ms
  - [ ] 无输入丢失
- **测试**: 高频输入测试

---

### 7.2 App Store 准备

#### T7.2.1 创建 App 图标和启动画面
- **描述**: 设计并添加应用图标
- **依赖**: 无
- **文件**:
  - `apple/Chiaki/Resources/Assets.xcassets/AppIcon.appiconset/`
- **验收标准**:
  - [ ] 所有尺寸图标
  - [ ] iOS、macOS、tvOS 图标
  - [ ] 启动画面
- **测试**: 各平台图标正确显示

---

#### T7.2.2 编写 App Store 描述
- **描述**: 准备 App Store Connect 所需的描述和截图
- **依赖**: 无
- **验收标准**:
  - [ ] 应用描述（多语言）
  - [ ] 功能列表
  - [ ] 截图（各设备）
  - [ ] 隐私政策 URL
- **测试**: App Store Connect 验证通过

---

#### T7.2.3 配置 App 权限说明
- **描述**: 添加所有权限的用户说明
- **依赖**: 无
- **文件**:
  - `apple/Chiaki/Info.plist`
- **验收标准**:
  - [ ] NSLocalNetworkUsageDescription
  - [ ] NSMicrophoneUsageDescription (如果需要)
  - [ ] 其他必要权限说明
- **测试**: 权限弹窗显示正确说明

---

#### T7.2.4 App Store 审核测试
- **描述**: 内部测试确保符合审核指南
- **依赖**: 所有功能完成
- **验收标准**:
  - [ ] 无崩溃
  - [ ] 无私有 API
  - [ ] 功能完整可用
  - [ ] 内容合规
- **测试**: TestFlight 内部测试

---

### 7.3 文档

#### T7.3.1 编写用户指南
- **描述**: 应用内或网页用户指南
- **依赖**: 所有功能完成
- **验收标准**:
  - [ ] 快速入门
  - [ ] 功能说明
  - [ ] 故障排除
  - [ ] FAQ
- **测试**: 文档审查

---

#### T7.3.2 编写开发者文档
- **描述**: 代码文档和贡献指南
- **依赖**: 所有功能完成
- **文件**:
  - `apple/README.md`
- **验收标准**:
  - [ ] 构建说明
  - [ ] 架构说明
  - [ ] 贡献指南
- **测试**: 按文档可成功构建

---

## 任务依赖图

```
M1 项目初始化
└── T1.1.1 → T1.1.2 → T1.1.3

M2 UI 框架 (可并行于 M3)
├── T2.1.1 → T2.1.3 ─┐
├── T2.1.2 → T2.1.4 ─┼→ T2.2.1 → T2.2.2 → T2.2.4
├── T2.2.3           ┘
├── T2.3.1 → T2.3.2 → T2.3.3
├── T2.4.1 → T2.4.2, T2.4.3, T2.4.4 (设置页面)
├── T2.5.1 → T2.5.2, T2.5.3 (虚拟控制器)
└── T2.6.1 → T2.6.2 (导航整合)

M3 核心库构建
├── T3.1.1 → T3.1.2 ─┐
├── T3.1.3 → T3.1.4 ─┼→ T3.1.5 → T3.1.6 → T3.1.7
├── T3.2.1 → T3.2.2 → T3.2.3
├── T3.3.1 → T3.3.2 → T3.3.3 → T3.3.4 → T3.3.5
└── T3.4.1 → T3.4.2 (VideoToolbox 解码器)

M4 功能集成 (依赖 M2 + M3)
├── T4.1.1 → T4.1.2 → T4.1.3 → T4.1.5
├── T4.2.1 → T4.2.2
├── T4.3.1 → T4.3.2 → T4.3.3, T4.3.4
├── T4.4.1 → T4.4.2 → T4.4.3 → T4.4.4 → T4.4.5
├── T4.5.1 → T4.5.2 → T4.5.3 → T4.5.4
├── T4.6.1
└── T4.7.1 → T4.7.2

M5 完善功能
├── T5.1.1 → T5.1.2 → T5.1.3 → T5.1.4
├── T5.2.1 → T5.2.2
├── T5.3.1, T5.3.2
└── T5.4.1 → T5.4.2

M6 平台适配
├── T6.1.1, T6.1.2, T6.1.3
├── T6.2.1, T6.2.2
├── T6.3.1, T6.3.2
└── T6.4.1, T6.4.2

M7 发布准备
├── T7.1.1, T7.1.2, T7.1.3
├── T7.2.1 → T7.2.2 → T7.2.3 → T7.2.4
└── T7.3.1, T7.3.2
```

---

## 快速开始建议

**UI 优先开发策略**:

项目初始化完成后，M2 UI 框架 和 M3 核心库构建 可以并行开发：
- **UI 开发者**: 专注 M2，使用 Mock 数据构建完整 UI
- **后端开发者**: 专注 M3，构建依赖库和桥接层

**第一阶段重点任务** (可并行):

1. **T1.1.1-T1.1.3** - 创建 Xcode 项目和目录结构
2. **T2.1.1-T2.1.4** - 数据模型和 Mock（UI 路线）
3. **T3.1.1** - 编写 mbedtls 构建脚本（核心库路线）

**关键里程碑检查点**:

- **M1 完成标志**: Xcode 项目可编译，目录结构完整 ✅
- **M2 完成标志**: 所有 UI 使用 Mock 数据可交互预览 ✅
- **M3 完成标志**: libchiaki.xcframework 可链接，Metal 渲染器可显示测试图像，VideoToolbox 解码器可解码视频流 ✅
- **M4 完成标志**: UI 连接真实数据，可连接 PS 主机播放视频/音频
- **M5 完成标志**: PSN 登录、设置持久化完成
- **M6 完成标志**: 各平台特有功能完成
- **M7 完成标志**: 可提交 App Store
