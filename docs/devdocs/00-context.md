# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-04
**生成工具**：/devdocs-onboard --update

---

## 1. 项目概述

### 1.1 项目目标
开发 Apple 生态的原生客户端（macOS, iOS, iPadOS, tvOS），提供高性能、原生体验且深度集成 Apple 特性的 PlayStation 4/5 远程游玩体验。

### 1.2 核心功能
| 编号 | 功能 | 状态 |
|------|------|------|
| F-001 | 核心流媒体 (Video/Audio) | ✅ 已完成 |
| F-002 | PS 主机发现 (Local Network) | ✅ 已完成 |
| F-003 | 主机唤醒 (Wake-on-LAN) | ✅ 已完成 |
| F-004 | 控制器支持 (DualSense/MFi) | ✅ 已完成 |
| F-005 | PSN 账户登录 | ✅ 已完成 |
| F-011 | 状态管理统一化 (@Observable) | ✅ 已完成 |
| F-015 | 深度本地化与多语言支持 | ✅ 已完成 |
| F-016 | 网络弹性与自动重连 | ✅ 已完成 |
| F-017 | 能效管理与渲染优化 (VRR) | ✅ 已完成 |
| F-019 | 完善日志系统 | ✅ 已完成 |
| F-020 | 手柄操作友好化 | ✅ 已完成 |
| F-022 | 手柄操控 UI/UX 优化 | ✅ 已完成 |
| F-023 | iPad 触摸操作友好化 | ✅ 已完成 |
| F-025 | HDR 渲染管线优化 | 🔄 进行中 (M12) |
| F-026 | 渲染模块解耦重构 | 🔜 待开发 (M12) |
| F-027 | UI 层 MVVM 合规重构 | 🔜 待开发 (M12) |

### 1.3 技术栈
- **UI 框架**：SwiftUI (Modern APIs, @Observable)
- **图形渲染**：Metal (Zero-copy CVPixelBuffer, HDR/EDR)
- **视频解码**：VideoToolbox (H.264/H.265, HDR10/PQ)
- **音频处理**：AVAudioEngine (Lock-free circular buffer)
- **底层通讯**：libchiaki (C 核心库桥接)
- **数据安全**：KeychainManager (CryptoKit)
- **控制器**：GameController framework (DualSense/MFi)

---

## 2. 系统架构

### 2.1 架构概览
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
│                    Metal 渲染层                                  │
│  ┌────────────────────┐ ┌────────────────────────────────────┐  │
│  │  MetalVideoRenderer│ │  VideoToolboxDecoder               │  │
│  │  (HDR/EDR Shaders) │ │  (H.264/H.265 Hardware Decode)     │  │
│  └────────────────────┘ └────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 核心模块
| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **Streaming** | 流媒体状态与生命周期 | `StreamingViewModel.swift` |
| **Renderer** | Metal HDR/EDR 渲染 | `MetalVideoRenderer.swift`, `VideoShaders.metal` |
| **HDR** | HDR 配置与元数据 | `HDRConfiguration.swift` |
| **Session** | C 库会话状态桥接 | `ChiakiSession.swift` |
| **Logging** | 日志持久化与脱敏 | `FileLogHandler.swift`, `DiagnosticsExporter.swift` |
| **Controller** | 手柄输入与触觉反馈 | `ControllerManager.swift`, `HapticsManager.swift` |
| **VirtualController** | 虚拟触摸控制器 | `VirtualControllerView.swift`, `VirtualButtonView.swift` |

### 2.3 核心接口
- `ChiakiSessionWrapper`: 连接、断开、发送输入
- `VideoDecoderBridge`: 解码器配置与数据分发
- `AudioPlayerBridge`: 音频同步与音量控制
- `HDRConfiguration`: HDR 统一配置结构
- `ControllerShortcutDetector`: 手柄快捷键检测

---

## 3. 代码结构

### 3.1 目录结构
```
Chiaki/
├── App/                # 全平台入口与导航
├── Features/           # 业务功能模块
│   ├── HostList/       # 主机列表与添加
│   ├── PSNLogin/       # PSN 身份认证
│   ├── Settings/       # 全局设置与日志查看
│   ├── Streaming/      # 流媒体核心视图
│   │   ├── VirtualController/  # 虚拟控制器组件
│   │   └── Controls/           # 流媒体控制组件
│   ├── Common/         # 共享 UI 组件
│   └── AutoConnect/    # 自动连接功能
├── Core/               # 底层基础设施
│   ├── Audio/          # 音频引擎
│   ├── Bridge/         # C 库桥接
│   ├── Controllers/    # 控制器与触觉
│   ├── Network/        # 网络状态监控
│   ├── Video/          # Metal 渲染、解码、HDR
│   │   ├── MetalVideoRenderer.swift
│   │   ├── VideoToolboxDecoder.swift
│   │   ├── VideoStreamView.swift
│   │   └── HDRConfiguration.swift  # [M12 新增]
│   ├── Streaming/      # 流媒体核心逻辑
│   └── Storage/        # 持久化存储
├── Domain/             # 业务逻辑模型
│   ├── Models/         # 数据模型
│   └── Services/       # 服务层 (PSNService)
├── Platforms/          # 平台特定代码 (macOS/tvOS)
├── Shared/             # 共享组件与样式
│   └── Styles/         # 样式定义
└── Utilities/          # 工具类与扩展
    └── Extensions/     # Swift 扩展

ChiakiTests/            # 单元测试与集成测试 (28 个测试文件)
```

### 3.2 关键文件说明
| 文件 | 用途 |
|------|------|
| `ChiakiApp.swift` | App 启动集成，初始化崩溃捕获 |
| `MetalVideoRenderer.swift` | Metal 视频渲染器 (HDR/EDR) |
| `HDRConfiguration.swift` | HDR 统一配置结构 [M12 T-147] |
| `VideoToolboxDecoder.swift` | 硬件视频解码 |
| `Logger.swift` | 统一日志入口，集成文件持久化 |
| `DiagnosticsExporter.swift` | 诊断数据脱敏打包 (ZIP) |
| `Localizable.xcstrings` | 100% 覆盖的中英文本地化 |
| `StreamingOverlay.swift` | 流媒体状态覆盖层（含 HDR 徽章） |

### 3.3 代码统计
- **Swift 源文件**: 70+ 个 (~17,500 行)
- **测试文件**: 28 个

---

## 4. 当前进度

### 4.1 里程碑状态
| 里程碑 | 目标 | 完成率 | 状态 |
|--------|------|--------|------|
| M11 | Beta 1 发布冲刺 | 97% (35/36) | ✅ 基本完成 |
| M12 | HDR 优化 + 架构重构 | 4% (1/24) | 🔄 进行中 |

### 4.2 M12 当前进度
| 指标 | 数值 |
|------|------|
| 总任务数 | 24 |
| 已完成 | 1 |
| 进行中 | 0 |
| 待处理 | 23 |
| **完成率** | **4%** |

### 4.3 最近完成
- **T-147**: HDRConfiguration 统一配置结构 (2026-02-04) `11af485`
- **BUG-001**: HDR 设置失效修复 (2026-02-03)
  - `8a11629` apply HDR codec setting
  - `2fe16a3` implement proper HDR rendering with PQ EOTF
  - `0ee6542` pass HDR setting to video view

### 4.4 M12 功能点状态
| 功能 | 任务数 | 已完成 | 状态 |
|------|--------|--------|------|
| F-025 HDR 渲染管线优化 | 9 | 1 | 🔄 进行中 |
| F-026 渲染模块解耦 | 3 | 0 | 🔜 待开始 |
| F-027 UI 层 MVVM 重构 | 12 | 0 | 🔜 待开始 |

### 4.5 Git 状态
- **当前分支**: dev
- **最新提交**: `182fd05` docs: mark T-147 as completed
- **工作区**: 干净

---

## 5. 待办任务

### 5.1 下一步可执行任务 (依赖已解除)
| 优先级 | 任务 | 名称 | TDD | 关联需求 |
|--------|------|------|-----|----------|
| P0 | **T-148** | HDRMetadataCache 抖动抑制 | 🔴 强制 | F-025, AC-083 |
| P0 | **T-149** | EDRHeadroomMonitor 动态监听 | 🔴 强制 | F-025, AC-081 |
| P0 | **T-150** | Shader 色域映射 (Rec.2020→P3) | 🔴 强制 | F-025, AC-080 |
| P0 | **T-156** | VideoRenderer 协议抽象 | 🔴 强制 | F-026, AC-086 |
| P0 | **T-159** | PinManaging 协议定义 | 🔴 强制 | F-027, AC-095 |
| P0 | **T-160** | PSNServicing 协议定义 | 🔴 强制 | F-027, AC-095 |
| P1 | **T-164** | VideoSettingsViewModel | 🔴 强制 | F-027, AC-093 |

### 5.2 M12 建议执行顺序
```
阶段 1: 基础定义 (并行)
├── T-148: HDRMetadataCache
├── T-149: EDRHeadroomMonitor
├── T-150: Shader 色域映射
├── T-156: VideoRenderer 协议
├── T-159: PinManaging 协议
└── T-160: PSNServicing 协议

阶段 2: Shader 完善 + 协议实现
├── T-151: ACES Tone Mapping
├── T-152: Shader Uniform 扩展
├── T-161: ConsolePinManager 实现
└── T-162: PSNService 实现

阶段 3: 集成与 ViewModel
├── T-153: MetalVideoRenderer 集成
├── T-154: VideoStreamView EDR 集成
├── T-163: AccountSettingsViewModel
├── T-164: VideoSettingsViewModel
└── T-165: ConsolesSettingsViewModel

阶段 4: View 重构
├── T-157/T-158: Renderer 协议实现 + Coordinator 分离
└── T-166~T-170: Settings View 重构
```

### 5.3 遗留任务
| 任务 | 名称 | 状态 | 说明 |
|------|------|------|------|
| **T-115** | App Icon 资产准备 | ⏳ | 等待设计师提供图像资产 |

---

## 6. 重要约定

### 6.1 编码规范
- 使用 `@Observable` 宏进行状态管理
- 强制 TDD：🔴 标记的任务必须先写测试
- 日志规范：所有核心路径必须有日志覆盖
- MTE 原则：可维护、可测试、可扩展

### 6.2 测试约束
- 单元测试覆盖率目标 ≥ 80%
- 禁止弱断言
- Mock 只用于外部依赖

### 6.3 提交规范
- 格式：`<type>(scope): <subject> (T-XXX)`
- 示例：`feat(video): add HDRConfiguration unified structure (T-147)`

### 6.4 代码追溯
项目使用代码标注追溯系统：
- `@requirement F-XXX` - 关联功能点
- `@satisfies AC-XXX` - 满足验收标准
- `@verifies AC-XXX` - 测试验证验收标准
- `@testcase UT-XXX` - 测试用例编号

---

## 7. 快速开始

### 7.1 环境准备
```bash
make build-deps  # 构建 C 库依赖 (mbedtls, opus, libchiaki)
```

### 7.2 运行测试
```bash
xcodebuild test -scheme Chiaki -destination 'platform=macOS'
# 或指定测试
swift test --filter HDRConfigurationTests
```

### 7.3 执行开发任务
```bash
# 使用 DevDocs 工作流开发
/devdocs-dev-workflow T-148
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 上下文 | `docs/devdocs/00-context.md` | 项目全貌与接手指南 (本文件) |
| 进度报告 | `docs/devdocs/00-progress-report.md` | M12 进度统计 |
| 需求文档 | `docs/devdocs/01-requirements.md` | F-001~027 功能点、AC-001~096 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构设计 v1.5.0 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | UT/IT/E2E 测试用例 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | M12 活跃任务 T-147~170 |
| 任务归档 | `docs/devdocs/archive/04-dev-tasks-archive.md` | 已完成任务归档 (M1~M11) |
| 洞察记录 | `docs/devdocs/05-insights.md` | 改进建议收集 |
| Bug 修复 | `docs/devdocs/05-bugfix-log.md` | Bug 修复记录 |

---

**接手建议**：
1. 阅读本文档了解项目全貌
2. M12 当前阶段：HDR 渲染优化 + 架构重构
3. T-147 已完成，可从 T-148/T-149/T-150 或 T-159/T-160 继续
4. 使用 `/devdocs-dev-workflow T-XXX` 执行任务
5. 遇到细节问题查阅对应 DevDocs 文档

---

## 9. M12 关键技术点

### 9.1 HDRConfiguration 结构 (T-147 ✅)
```swift
struct HDRConfiguration: Codable, Equatable, Sendable {
    var enabled: Bool
    var edrIntensity: Float        // 0.5 - 2.0
    var colorSpace: HDRColorSpace  // bt709/bt601/bt2020
    var colorRange: HDRColorRange  // video/full
    var tonemapMode: TonemapMode   // passthrough/aces
    var gamutMappingEnabled: Bool

    var isHDR: Bool { enabled && colorSpace == .bt2020 }

    static let sdr = HDRConfiguration(...)
    static let hdr = HDRConfiguration(...)
}
```

### 9.2 待实现的 HDR 组件
- **HDRMetadataCache** (T-148): 抑制 HDR/SDR 状态抖动（连续 5 帧确认）
- **EDRHeadroomMonitor** (T-149): 监听屏幕 EDR Headroom 变化
- **Shader 色域映射** (T-150): Rec.2020 → Display P3 转换矩阵
- **ACES Tone Mapping** (T-151): HDR→SDR 降级路径

### 9.3 待实现的协议抽象
- **VideoRenderer** (T-156): 渲染器协议，解耦 Metal 实现细节
- **PinManaging** (T-159): PIN 管理协议，支持 Mock 测试
- **PSNServicing** (T-160): PSN 服务协议，支持 Mock 测试

---

*报告由 /devdocs-onboard 生成 (2026-02-04)*
