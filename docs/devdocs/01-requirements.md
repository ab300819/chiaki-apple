# Chiaki-ng Apple 原生客户端 - 产品需求规格书

> **文档来源**: 改造自 `PRD.md`
> **创建时间**: 2026-01-13
> **迁移时间**: 2026-01-19
> **迁移内容**: DevDocs 编号规范化 (F-XXX/US-XXX/AC-XXX)

## 1. 项目概述

### 1.1 背景

Chiaki-ng 是一个开源的 PlayStation 4/5 远程游玩客户端，支持多平台部署。当前项目使用 C 核心库（libchiaki）+ Qt6 GUI 实现，支持 Linux、Windows、macOS、Android、Nintendo Switch 等平台。

现有 macOS 版本基于 Qt6 实现，虽然功能完整，但存在以下问题：
- Qt 框架体积较大，增加应用体积
- 非原生 UI 体验，与 Apple 设计规范不一致
- 无法复用到 iOS/iPadOS/tvOS 平台
- 缺乏 Apple 生态系统深度集成

### 1.2 目标

开发 Apple 原生客户端，统一覆盖 macOS、iOS、iPadOS 和 tvOS 平台：
- 使用 SwiftUI 实现原生 UI，符合各平台设计规范
- 使用 Metal 进行高效视频渲染
- 复用现有 libchiaki 核心库，保证协议兼容性
- 支持各平台特有功能（如 tvOS 遥控器、iPad 多任务等）

### 1.3 功能范围

| 编号 | 功能模块 | 优先级 | 说明 |
|------|---------|--------|------|
| **F-001** | 核心流媒体 | P0 | 视频/音频流接收与渲染 |
| **F-002** | PS 主机发现 | P0 | 局域网自动发现 PS4/PS5 |
| **F-003** | 主机唤醒 | P0 | Wake-on-LAN 功能 |
| **F-004** | 控制器支持 | P0 | DualShock 4 / DualSense 支持 |
| **F-005** | PSN 账户登录 | P1 | 远程连接所需的账户认证 |
| **F-006** | 远程连接 | P1 | 通过互联网连接 PS 主机 |
| **F-007** | 触觉反馈 | P2 | DualSense 触觉反馈支持 |
| **F-008** | 麦克风支持 | P2 | 语音聊天功能 |
| **F-009** | 虚拟输入 | P3 | 键盘/触摸板支持 |
| **F-010** | API 现代化与规范化 | P1 | 迁移至 iOS 17+ 标准 API [优化] |
| **F-011** | 状态管理统一化 | P1 | 全面迁移至 `@Observable` 框架 [优化] |
| **F-012** | 架构解耦与重构 | P2 | 核心 ViewModel 逻辑拆分 [优化] |
| **F-013** | 交互体验精致化 | P2 | 优化动画曲线与反馈 [优化] |
| **F-014** | 未来特性适配 | P3 | Liquid Glass (iOS 26+) 适配 [优化] |
| **F-015** | 深度本地化与多语言支持 | P0 | 100% i18n 覆盖 [生产准备] |
| **F-016** | 网络弹性与自动重连 | P0 | 增强网络波动下的恢复能力 [稳定性] |
| **F-017** | 能效管理与渲染优化 | P1 | Variable Refresh Rate 与功耗调优 [性能] |
| **F-018** | 应用分发元数据配置 | P1 | 隐私描述、Icon 与版本号 [生产准备] |
| **F-019** | 完善日志系统 | P0 | 日志持久化、诊断包导出、崩溃捕获 [排查能力] |
| **F-020** | 手柄操作友好化 | P0 | 焦点管理、快捷键、无触控操作 [体验优化] |

---

## 2. 用户故事

> 编号规范: US-XXX (三位数)，关联功能点 F-XXX

### US-001: 主机发现和连接
> 关联功能: F-002

**作为** iOS/macOS 用户
**我希望** 应用能自动发现局域网内的 PlayStation 主机
**以便** 我可以快速开始远程游戏，无需手动输入 IP 地址

**验收标准**:
- **AC-001**: 应用启动后 5 秒内显示在线主机列表
- **AC-002**: 显示主机名称、IP 地址、在线/休眠状态
- **AC-003**: 支持 PS4 和 PS5 主机识别
- **AC-004**: 网络变化时自动刷新列表

---

### US-002: 主机唤醒
> 关联功能: F-003

**作为** 用户
**我希望** 能够从应用中唤醒处于休眠状态的 PlayStation 主机
**以便** 我无需走到主机旁边按电源按钮

**验收标准**:
- **AC-005**: 休眠状态的主机显示"唤醒"按钮
- **AC-006**: 点击唤醒后 10 秒内主机启动
- **AC-007**: 唤醒失败时显示错误提示
- **AC-008**: 支持 Wake-on-LAN 协议

---

### US-003: 远程游戏流媒体
> 关联功能: F-001

**作为** 用户
**我希望** 能够通过 WiFi 或互联网连接 PlayStation 主机进行远程游戏
**以便** 我可以在任何地方玩 PlayStation 游戏

**验收标准**:
- **AC-009**: 视频端到端延迟 < 50ms（局域网）
- **AC-010**: 音频与视频同步，无明显偏差
- **AC-011**: 支持 720p/1080p 分辨率
- **AC-012**: 支持 30fps/60fps 帧率
- **AC-013**: 支持 H.264/H.265 视频编码

---

### US-004: 控制器支持
> 关联功能: F-004

**作为** 用户
**我希望** 能够使用 DualSense 或 DualShock 4 控制器玩游戏
**以便** 我可以获得与在 PlayStation 上相同的游戏体验

**验收标准**:
- **AC-014**: 支持蓝牙和 USB 连接
- **AC-015**: 所有按键映射正确
- **AC-016**: 摇杆和扳机响应准确
- **AC-017**: DualSense 触觉反馈可用（iOS/macOS）
- **AC-018**: 支持多控制器连接

---

### US-005: iOS 触屏控制
> 关联功能: F-009

**作为** iPhone/iPad 用户
**我希望** 在没有实体控制器时能使用触屏虚拟控制器
**以便** 我可以随时随地玩游戏

**验收标准**:
- **AC-019**: 虚拟摇杆响应灵敏
- **AC-020**: 虚拟按钮布局合理
- **AC-021**: 支持自定义布局 [待补充]
- **AC-022**: 不遮挡关键游戏画面

---

### US-006: tvOS 大屏体验
> 关联功能: F-001, F-004

**作为** Apple TV 用户
**我希望** 能够使用 Siri Remote 导航应用并使用控制器玩游戏
**以便** 我可以在客厅大屏幕上享受 PlayStation 游戏

**验收标准**:
- **AC-023**: Siri Remote 可导航所有界面
- **AC-024**: 焦点状态清晰可见
- **AC-025**: 支持 Top Shelf 快速启动
- **AC-026**: 自动连接上次使用的主机

---

### US-007: PSN 账户登录
> 关联功能: F-005

**作为** 用户
**我希望** 能够登录我的 PSN 账户
**以便** 我可以进行远程连接和访问我的游戏库

**验收标准**:
- **AC-027**: OAuth 登录流程完整
- **AC-028**: 凭证安全存储在 Keychain
- **AC-029**: 支持 Token 自动刷新
- **AC-030**: 可安全登出

---

### US-008: 设置持久化
> 关联功能: F-001, F-004

**作为** 用户
**我希望** 我的视频、音频和控制器设置能够保存
**以便** 我不需要每次使用都重新配置

**验收标准**:
- **AC-031**: 分辨率、帧率、码率设置保存
- **AC-032**: 音量设置保存
- **AC-033**: 控制器映射设置保存
- **AC-034**: 设置跨设备同步 [待补充]

---

### US-009: API 现代化与规范化 [优化]
> 关联功能: F-010

**作为** 开发者
**我希望** 代码库使用 Apple 最新的推荐 API
**以便** 提高渲染性能并支持未来的系统特性

**验收标准**:
- **AC-035**: 所有 `.foregroundColor()` 替换为 `.foregroundStyle()`
- **AC-036**: 所有 `.cornerRadius()` 替换为 `.clipShape(.rect(cornerRadius:))`
- **AC-037**: 视图样式逻辑与 iOS 17/18+ 设计规范对齐

---

### US-010: 架构重构与解耦 [优化]
> 关联功能: F-011, F-012

**作为** 开发者
**我希望** 将核心业务逻辑从大型 ViewModel 中拆分出来
**以便** 提高代码的可读性、可测试性并减少视图的不必要刷新

**验收标准**:
- **AC-038**: 所有的 `ObservableObject` 迁移至 `@Observable` 框架
- **AC-039**: `StreamingViewModel` 拆分为 `StatsManager` 和 `InputMapper` 等子模块
- **AC-040**: 子视图仅接收必要的原子属性而非整个 ViewModel 对象

---

### US-011: 交互与动画精致化 [优化]
> 关联功能: F-013, F-014

**作为** 用户
**我希望** 应用的动画和反馈更加自然、流畅
**以便** 获得与系统原生应用一致的精致感

**验收标准**:
- **AC-041**: 叠加层和菜单切换使用 `.spring()` 或 `.snappy` 动画曲线
- **AC-042**: (iOS 26+) 在支持的设备上为流媒体控制菜单启用 `glassEffect`
- **AC-043**: 所有的按钮反馈符合各平台的主流交互习惯

---

### US-012: 生产就绪与体验打磨 [生产准备]
> 关联功能: F-015, F-016, F-017, F-018

**作为** 终端用户
**我希望** 应用运行稳定、省电，且在我的母语环境下显示正常
**以便** 我可以放心地在生产环境中使用

**验收标准**:
- **AC-044**: 所有 UI 文本通过 `Localizable.xcstrings` 管理，无硬编码中文/英文
- **AC-045**: 当 WiFi 断开并切换到 5G 时，应用在 5 秒内自动尝试重连
- **AC-046**: 静态画面下 GPU 功耗降低至少 20% (通过 Instruments 验证)
- **AC-047**: 所有的隐私访问（麦克风、局域网）均有清晰、合规的解释文案
- **AC-048**: 提供符合 Apple 规范的多尺寸 App Icon

---

### US-013: 完善日志系统 [排查能力]
> 关联功能: F-019
> 来源: INS-001 ~ INS-005 (💡 内部反馈)

**作为** 开发者/技术支持
**我希望** 应用具备完善的日志记录和导出能力
**以便** 在用户遇到问题时能够快速定位和修复，即使问题无法复现

**验收标准**:
- **AC-049**: 日志实时写入文件，应用重启后仍可查看历史日志
- **AC-050**: 实现日志轮换策略（5MB/文件，保留最近 7 个文件，总上限约 35MB）
- **AC-051**: 提供"导出诊断包"功能，包含：所有日志文件 + 设备信息 + 网络状态 + 配置快照（不含敏感凭证）
- **AC-052**: 应用崩溃时自动捕获异常信息，下次启动可查看
- **AC-053**: 导出日志时自动脱敏敏感信息（IP 部分遮蔽、令牌截断、用户 ID 哈希化）
- **AC-054**: 核心流程（连接、流媒体、控制器、发现、认证）有充足的日志覆盖，确保问题可追溯

---

### US-014: 手柄操作友好化 [体验优化]
> 关联功能: F-020
> 来源: INS-011 ~ INS-016 (💡 内部反馈 + 🎨 UI/UX 审查)

**作为** 使用手柄的用户
**我希望** 在流媒体过程中可以完全使用手柄操作应用 UI
**以便** 我不需要放下手柄去触摸屏幕或使用遥控器

**验收标准**:
- **AC-055**: 流媒体控制菜单支持手柄方向键导航，焦点在控件间移动
- **AC-056**: tvOS 上所有可交互元素有明确的焦点状态视觉反馈（边框/缩放）
- **AC-057**: 控制菜单打开时实现焦点陷阱，防止焦点跳转到背景视频
- **AC-058**: tvOS 支持完整方向键导航命令（上/下/左/右/选择）
- **AC-059**: 支持手柄组合键快捷操作：PS+Options 打开菜单，L1+R1+PS 断开连接
- **AC-060**: 控制菜单关闭后焦点正确恢复到触发位置

---

## 3. 目标平台需求

### 3.1 macOS

| 项目 | 需求 |
|------|------|
| 最低版本 | macOS 13.0 (Ventura) |
| 架构支持 | Apple Silicon (ARM64) + Intel (x86_64) |
| 分发方式 | DMG 直接分发 / Mac App Store |
| 特有功能 | 全屏模式、触控栏支持、菜单栏集成 |
| 控制器 | MFi 控制器 + DualShock 4 + DualSense |
| 网络 | 局域网 + 远程连接 |

**macOS 特有需求：**
- 支持多窗口（同时连接多台 PS 主机）
- 系统睡眠抑制（流媒体期间）
- Dock 图标进度指示
- 通知中心集成

### 3.2 iOS

| 项目 | 需求 |
|------|------|
| 最低版本 | iOS 16.0 |
| 设备支持 | iPhone 8 及更新机型 |
| 分发方式 | App Store |
| 特有功能 | 触屏虚拟控制器、陀螺仪输入 |
| 控制器 | MFi 控制器 + DualShock 4 + DualSense |
| 网络 | WiFi + 蜂窝网络 |

**iOS 特有需求：**
- 触屏虚拟控制器（可自定义布局）
- 陀螺仪作为运动传感器输入
- 后台音频继续播放
- 低功耗模式检测与提示
- 3D Touch / Haptic Touch 快捷操作

### 3.3 iPadOS

| 项目 | 需求 |
|------|------|
| 最低版本 | iPadOS 16.0 |
| 设备支持 | iPad Air 3 及更新机型 |
| 分发方式 | App Store |
| 特有功能 | 分屏多任务、外接键盘/鼠标、Apple Pencil |
| 控制器 | MFi 控制器 + DualShock 4 + DualSense + 键鼠 |

**iPadOS 特有需求：**
- Stage Manager 支持（多窗口）
- 分屏/侧拉多任务支持
- 外接显示器支持
- 键盘快捷键
- 可调整窗口尺寸

### 3.4 tvOS

| 项目 | 需求 |
|------|------|
| 最低版本 | tvOS 16.0 |
| 设备支持 | Apple TV HD / Apple TV 4K |
| 分发方式 | App Store |
| 特有功能 | Siri Remote 导航、大屏优化 UI |
| 控制器 | MFi 控制器 + DualShock 4 + DualSense |

**tvOS 特有需求：**
- Siri Remote 导航支持（焦点引擎）
- 10-foot UI 设计（大屏适配）
- Top Shelf 扩展（快速启动常用主机）
- 自动连接上次使用的主机

---

## 4. 技术架构

### 4.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI 界面层                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │   主机列表   │ │  流媒体视图  │ │  设置页面   │ │  登录页面   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Swift 业务逻辑层                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ HostManager │ │SessionManager│ │ SettingsStore│ │ PSNService │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    Swift-C 桥接层 (ChiakiBridge)                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ChiakiSession│ │ChiakiDiscovery│ │ChiakiController│ │ChiakiAudio│ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    libchiaki (C 核心库)                          │
│  ┌──────┐ ┌───────┐ ┌────────┐ ┌────────┐ ┌───────┐ ┌────────┐ │
│  │Session│ │Takion │ │Discovery│ │Regist  │ │RUDP   │ │Opus    │ │
│  └──────┘ └───────┘ └────────┘ └────────┘ └───────┘ └────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    Metal 渲染层                                  │
│  ┌────────────────────┐ ┌────────────────────────────────────┐  │
│  │  VideoRenderer     │ │  HapticEngine (Core Haptics)       │  │
│  │  (Metal Shaders)   │ │                                    │  │
│  └────────────────────┘ └────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 模块设计

#### 4.2.1 ChiakiBridge (Swift-C 桥接)

将 libchiaki C API 封装为 Swift 友好的接口：

```swift
// ChiakiSession.swift
@Observable
class ChiakiSession {
    var state: SessionState
    var videoFrame: CVPixelBuffer?
    var audioBuffer: AVAudioPCMBuffer?

    func connect(to host: ChiakiHost, credentials: PSNCredentials) async throws
    func disconnect()
    func sendControllerState(_ state: ControllerState)
}

// ChiakiDiscovery.swift
@Observable
class ChiakiDiscovery {
    var discoveredHosts: [ChiakiHost]

    func startDiscovery()
    func stopDiscovery()
    func wakeUp(host: ChiakiHost) async throws
}
```

#### 4.2.2 Metal 视频渲染器

```swift
// MetalVideoRenderer.swift
class MetalVideoRenderer: MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // 支持的像素格式
    // - NV12 (YUV 4:2:0, 硬件解码输出)
    // - BGRA (回退格式)

    func render(pixelBuffer: CVPixelBuffer, to view: MTKView)
}
```

#### 4.2.3 控制器管理

```swift
// ControllerManager.swift
@Observable
class ControllerManager {
    var connectedControllers: [GCController]
    var activeController: GCController?

    // 支持的控制器类型
    // - GCController (MFi)
    // - DualShock 4 (通过 GCController)
    // - DualSense (通过 GCController + 触觉反馈)
    // - 虚拟触屏控制器 (iOS)

    func mapToChiakiInput(_ input: GCControllerInput) -> ChiakiControllerState
}
```

### 4.3 数据流

```
视频流:
PS Console → libchiaki (H.264/H.265 解码) → CVPixelBuffer → Metal Renderer → MTKView

音频流:
PS Console → libchiaki (Opus 解码) → PCM Buffer → AVAudioEngine → Speaker

控制器输入:
GCController → ControllerManager → ChiakiControllerState → libchiaki → PS Console
```

---

## 5. UI/UX 设计规范

### 5.1 设计原则

- **平台一致性**: 遵循各平台 Human Interface Guidelines
- **简洁高效**: 最少步骤完成连接
- **游戏优先**: 流媒体界面无干扰
- **可访问性**: 支持 VoiceOver、动态字体

### 5.2 核心页面

#### 5.2.1 主机列表页

```
┌────────────────────────────────────────┐
│ Chiaki                        [设置]   │
├────────────────────────────────────────┤
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🟢 PS5 - 客厅                    │  │
│  │    192.168.1.100 | 在线          │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🔴 PS4 - 卧室                    │  │
│  │    192.168.1.101 | 休眠    [唤醒] │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ ➕ 添加主机                       │  │
│  └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

#### 5.2.2 流媒体页面

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│          [全屏视频流画面]               │
│                                        │
│                                        │
├────────────────────────────────────────┤
│ [返回]  状态: 1080p60 | 15ms | ████▓  │
└────────────────────────────────────────┘
```

#### 5.2.3 设置页面

```
┌────────────────────────────────────────┐
│ ← 设置                                 │
├────────────────────────────────────────┤
│ 视频                                   │
│   分辨率        [1080p ▼]              │
│   帧率          [60 FPS ▼]             │
│   码率          [15 Mbps ────●──]      │
│   HDR           [开关]                 │
├────────────────────────────────────────┤
│ 音频                                   │
│   音量          [────────●──]          │
│   麦克风        [开关]                 │
├────────────────────────────────────────┤
│ 控制器                                 │
│   触觉反馈      [开关]                 │
│   按键映射      [自定义 >]             │
├────────────────────────────────────────┤
│ 账户                                   │
│   PSN 登录      [已登录: user@psn >]   │
└────────────────────────────────────────┘
```

### 5.3 平台适配

| 平台 | 导航模式 | 特殊考虑 |
|------|---------|---------|
| macOS | 侧边栏 + 详情 | 菜单栏、触控栏 |
| iOS | TabBar / NavigationStack | 安全区域、刘海屏 |
| iPadOS | 侧边栏 + 详情 (Regular) / Stack (Compact) | 多任务、键盘 |
| tvOS | 焦点导航 | 大字体、高对比度 |

---

## 6. 项目结构方案

### 6.1 确定方案

**采用方案：独立仓库 + 子模块模式**

**决策理由**：

1. **GPL 协议合规**：Apple 原生客户端作为独立项目开源，chiaki-ng 作为 git submodule 引入，清晰划分代码边界
2. **独立发布周期**：Apple 版本可独立迭代发布，不受上游 chiaki-ng 更新节奏限制
3. **构建系统隔离**：Xcode 项目与 CMake 构建系统完全分离，避免复杂的跨构建系统集成
4. **核心库同步**：通过 git submodule 可选择性同步 chiaki-ng 更新，保持稳定性

**决策确认**：创建独立仓库 `chiaki-apple`，通过 git submodule 依赖 `chiaki-ng`

### 6.2 构建集成方案

```
chiaki-apple/                   # 独立 Apple 原生客户端仓库
├── chiaki-ng/                  # git submodule (libchiaki 核心库)
├── Chiaki.xcodeproj
├── Chiaki/                     # 共享代码 (macOS, iOS, iPadOS)
│   ├── App/
│   ├── Features/
│   ├── Core/
│   └── Resources/
├── ChiakiTV/                   # tvOS 特定代码
├── ChiakiMac/                  # macOS 特定代码
├── libchiaki.xcframework/      # 预编译的 libchiaki
└── Scripts/
    └── build_libchiaki.sh      # 从 submodule 构建 libchiaki 脚本
```

### 6.3 UI 实现策略

**开发顺序**：macOS 优先，其他平台适配

| 阶段 | 平台 | 参考来源 | 说明 |
|------|------|----------|------|
| 1 | macOS | `chiaki-ng/gui/` (Qt/QML) | SwiftUI 实现参照 Qt 版本的功能和交互逻辑 |
| 2 | iOS/iPadOS | macOS SwiftUI 实现 | 适配移动端交互模式，复用共享代码 |
| 3 | tvOS | macOS SwiftUI 实现 | 适配焦点导航和大屏交互 |

**Qt 参考文件对照**：

| Qt 实现 (`gui/`) | SwiftUI 对应 | 功能 |
|------------------|--------------|------|
| `discoverymanager.cpp` | `ChiakiDiscovery.swift` | 主机发现 |
| `host.cpp` | `Host.swift` | 主机模型 |
| `streamsession.cpp` | `ChiakiSession.swift` | 流媒体会话 |
| `qmlbackend.cpp` | `HostListViewModel.swift` | 主机列表逻辑 |
| `settings.cpp` | `SettingsStore.swift` | 设置管理 |
| `controllermanager.cpp` | `ControllerManager.swift` | 控制器管理 |

---

## 7. 依赖管理

### 7.1 核心依赖

| 依赖 | 用途 | 集成方式 |
|------|------|---------|
| libchiaki | PS 远程游玩协议实现 | 预编译 xcframework |
| FFmpeg | 视频解码 | 预编译 xcframework 或系统 VideoToolbox |
| Opus | 音频解码 | 预编译静态库 |
| OpenSSL | 加密通信 | 预编译静态库或 BoringSSL |

### 7.2 系统框架

| 框架 | 用途 | 平台 |
|------|------|------|
| SwiftUI | 用户界面 | 全平台 |
| Metal | 视频渲染 | 全平台 |
| AVFoundation | 音频播放 | 全平台 |
| VideoToolbox | 硬件视频解码 | 全平台 |
| GameController | 控制器支持 | 全平台 |
| CoreHaptics | 触觉反馈 | iOS/macOS |
| Network | 网络通信 | 全平台 |

### 7.3 第三方 Swift 包

| 包 | 用途 | 必要性 |
|---|------|-------|
| swift-async-algorithms | 异步序列处理 | 推荐 |
| KeychainAccess | 安全存储凭证 | 推荐 |

---

## 8. 开发计划

### 8.1 里程碑

> **策略调整**: 采用 UI 优先策略，项目初始化后先构建 UI 框架（使用 Mock 数据），支持 UI 和核心库并行开发

#### M1: 项目初始化 (Project Setup)
- [ ] 创建 Xcode 多平台项目
- [ ] 配置项目基本设置
- [ ] 创建目录结构

#### M2: UI 框架 (UI Framework) *可与 M3 并行*
- [ ] 数据模型和 Mock 数据
- [ ] 主机列表 UI（macOS 优先）
- [ ] 流媒体视图 UI 框架
- [ ] 设置页面 UI
- [ ] 虚拟控制器 UI (iOS)
- [ ] 导航与整合

#### M3: 核心库构建 (Core Libraries) *可与 M2 并行*
- [ ] 依赖库构建（mbedtls, opus, libchiaki）
- [ ] 桥接层基础实现
- [ ] Metal 渲染器原型

#### M4: 功能集成 (Feature Integration)
- [ ] 主机发现集成
- [ ] 会话连接
- [ ] 流媒体播放
- [ ] 控制器集成
- [ ] 触觉反馈

#### M5: 完善功能 (Polish)
- [ ] PSN 账户登录
- [ ] 主机注册
- [ ] 设置集成
- [ ] 多语言支持

#### M6: 平台适配 (Platform Adaptation)
- [ ] macOS 特有功能（菜单栏、多窗口）
- [ ] iPadOS 特有功能（键盘、外接显示器）
- [ ] tvOS 适配（焦点导航、Top Shelf）
- [ ] iOS 后台支持（PiP、后台音频）

#### M7: 发布准备 (Release)
- [ ] 性能优化
- [ ] App Store 审核准备
- [ ] 文档编写
- [ ] Beta 测试

### 8.2 技术风险评估

#### 8.2.1 高风险 (需重点关注)

| 风险 | 严重性 | 可能性 | 影响描述 | 缓解措施 |
|------|--------|--------|----------|----------|
| **libchiaki 依赖库交叉编译** | 高 | 高 | libchiaki 依赖 OpenSSL、Opus、json-c、miniupnpc、CURL 等库，需为 iOS/tvOS 交叉编译 | 1. 优先使用 vcpkg 或预编译的 xcframework<br>2. OpenSSL 可替换为 BoringSSL 或系统 Security.framework<br>3. 编写自动化构建脚本 |
| **视频解码器适配** | 高 | 中 | 现有 FFmpeg 解码器不适合 iOS，需实现 VideoToolbox 解码器 | 1. 新增 `vtdecoder.c` 模块使用 VideoToolbox API<br>2. 参考现有 `ffmpegdecoder.c` 和 `pidecoder.c` 实现模式<br>3. 使用 `kVTDecodeFrame_EnableAsynchronousDecompression` 低延迟模式 |
| **App Store 审核** | 高 | 中 | 远程游玩类应用可能面临审核挑战 | 1. 确保应用有独立价值<br>2. 提供清晰的用户指南<br>3. 准备详细的审核说明文档<br>4. 考虑先在 TestFlight 充分测试 |

#### 8.2.2 中等风险

| 风险 | 严重性 | 可能性 | 缓解措施 |
|------|--------|--------|----------|
| iOS 后台运行限制 | 中 | 高 | 实现 PiP 模式、后台音频模式 |
| DualSense 触觉反馈受限 | 中 | 高 | 使用 Core Haptics 基础触觉反馈 |
| 网络权限和 ATS | 中 | 中 | 添加必要的 ATS 例外配置 |
| Swift-C 桥接复杂性 | 中 | 中 | 使用 `@convention(c)` 和 `Unmanaged` |

---

## 9. 质量要求

### 9.1 性能指标

| 指标 | 目标值 |
|------|-------|
| 端到端延迟 | < 50ms (局域网) |
| 视频帧率 | 稳定 60 FPS |
| 音频延迟 | < 30ms |
| 内存占用 | < 200MB (流媒体中) |
| 电池影响 | < 20% 每小时 (iPad) |

### 9.2 兼容性测试

- PS4 Pro / PS4 Slim
- PS5 / PS5 Digital Edition
- 各目标平台最低支持版本
- 各类型控制器

### 9.3 可访问性

- VoiceOver 完整支持
- 动态字体 (Dynamic Type)
- 增强对比度模式
- 减少动态效果选项

---

## 10. 附录

### 10.1 参考资料

- [Chiaki-ng 官方文档](https://streetpea.github.io/chiaki-ng/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Metal Best Practices Guide](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/)
- [GameController Framework](https://developer.apple.com/documentation/gamecontroller)

### 10.2 术语表

| 术语 | 定义 |
|------|------|
| Remote Play | PlayStation 远程游玩功能 |
| PSN | PlayStation Network |
| DualSense | PS5 控制器 |
| DualShock 4 | PS4 控制器 |
| Takion | PS Remote Play 协议名称 |
| RUDP | 可靠 UDP，用于远程连接 |
