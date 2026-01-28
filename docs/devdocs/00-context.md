# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-01-28 23:45
**生成工具**：/devdocs-onboard

---

## 1. 项目概述

### 1.1 项目目标

Chiaki-ng Apple 原生客户端是 PlayStation 4/5 远程游玩的跨平台应用，使用 SwiftUI + Metal 重新实现，覆盖 macOS、iOS、iPadOS 和 tvOS。核心目标是提供原生体验、高性能渲染和深度 Apple 生态集成。

### 1.2 核心功能

| 编号 | 功能 | 优先级 | 状态 |
|------|------|--------|------|
| F-001 | 核心流媒体 | P0 | ✅ 已完成 |
| F-002 | PS 主机发现 | P0 | ✅ 已完成 |
| F-003 | 主机唤醒 | P0 | ✅ 已完成 |
| F-004 | 控制器支持 | P0 | ✅ 已完成 |
| F-005 | PSN 账户登录 | P1 | ✅ 已完成 |
| F-006 | 远程连接 | P1 | ✅ 已完成 |
| F-007 | 触觉反馈 | P2 | ✅ 已完成 |
| F-008 | 麦克风支持 | P2 | ✅ 已完成 |
| F-009 | 虚拟输入 | P3 | ✅ 已完成 |
| F-010 | API 现代化 | P1 | ✅ 已完成 |
| F-011 | 状态管理统一化 | P1 | ✅ 已完成 |
| F-012 | 架构解耦重构 | P2 | ✅ 已完成 |
| F-013 | 交互体验精致化 | P2 | ✅ 已完成 |
| F-014 | Liquid Glass 适配 | P3 | ⏸️ 延后 (iOS 26+) |
| F-015 | 深度本地化 | P0 | ✅ 已完成 |
| F-016 | 网络弹性与自动重连 | P0 | ✅ 已完成 |
| F-017 | 能效管理 (VRR) | P1 | ✅ 已完成 |
| F-018 | 应用分发元数据 | P1 | 🔄 进行中 |
| F-019 | 完善日志系统 | P0 | ⏳ 待开发 |

### 1.3 技术栈

| 层次 | 技术 | 说明 |
|------|------|------|
| UI 框架 | SwiftUI | 原生跨平台 UI |
| 视频渲染 | Metal + VideoToolbox | 硬件加速解码与渲染 |
| 音频播放 | AVAudioEngine | 低延迟音频 |
| 控制器 | GameController | MFi/DualSense/DualShock 4 |
| 触觉反馈 | CoreHaptics | DualSense 触觉模拟 |
| 网络监控 | NWPathMonitor | 连接状态与自动重连 |
| 核心协议 | libchiaki (C) | PlayStation Remote Play 协议实现 |
| 加密 | mbedTLS | TLS/加密通信 |
| 音频编解码 | Opus | 音频压缩 |

---

## 2. 系统架构

### 2.1 架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Application Layer                               │
│   ChiakiApp (iOS/iPad)  │  ChiakiTVApp (tvOS)  │  ChiakiMacApp (macOS)  │
├─────────────────────────────────────────────────────────────────────────┤
│                           Feature Layer                                  │
│   HostList  │  Streaming  │  Settings  │  PSNLogin  │  AutoConnect      │
├─────────────────────────────────────────────────────────────────────────┤
│                           Domain Layer                                   │
│   HostManager  │  SessionManager  │  SettingsStore  │  PSNService       │
├─────────────────────────────────────────────────────────────────────────┤
│                          Bridge Layer (ChiakiBridge)                     │
│   ChiakiSessionWrapper  │  ChiakiDiscovery  │  ChiakiRegist             │
├─────────────────────────────────────────────────────────────────────────┤
│                           Native Layer                                   │
│   MetalVideoRenderer  │  AudioPlayer  │  ControllerManager  │  Haptics  │
├─────────────────────────────────────────────────────────────────────────┤
│                          C Library Layer                                 │
│                      libchiaki.xcframework                               │
│   session  │  takion  │  discovery  │  regist  │  rudp  │  opus         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 核心模块

| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **HostManager** | 主机发现、状态管理 | `Domain/Services/HostManager.swift` |
| **SessionManager** | 会话生命周期管理 | `Domain/Services/SessionManager.swift` |
| **StreamingViewModel** | 流媒体状态控制 | `Features/Streaming/StreamingViewModel.swift` |
| **MetalVideoRenderer** | YUV→RGB 渲染 | `Core/Video/MetalVideoRenderer.swift` |
| **AudioPlayer** | 低延迟音频播放 | `Core/Audio/AudioPlayer.swift` |
| **ControllerManager** | 控制器输入处理 | `Core/Controllers/ControllerManager.swift` |
| **HapticsManager** | 语义化触觉反馈 | `Core/Controllers/HapticsManager.swift` |
| **NetworkMonitor** | 网络状态监控 | `Core/Network/NetworkMonitor.swift` |
| **Logger** | 统一日志系统 | `Utilities/Logger.swift` |

### 2.3 关键数据流

```
视频流: PS Console → libchiaki → VideoToolbox → CVPixelBuffer → Metal → MTKView
音频流: PS Console → libchiaki → Opus → PCM → AVAudioEngine → Speaker
控制器: GCController → ControllerManager → ChiakiControllerState → libchiaki → PS
```

---

## 3. 代码结构

### 3.1 目录结构

```
chiaki-apple/
├── Chiaki/                          # 共享代码 (iOS/iPadOS/macOS)
│   ├── App/                         # 应用入口
│   │   └── ChiakiApp.swift
│   ├── Features/                    # 功能模块
│   │   ├── HostList/               # 主机列表
│   │   ├── Streaming/              # 流媒体
│   │   ├── Settings/               # 设置
│   │   ├── PSNLogin/               # PSN 登录
│   │   └── AutoConnect/            # 自动连接
│   ├── Core/                        # 核心层
│   │   ├── Bridge/                 # C 桥接
│   │   ├── Video/                  # 视频渲染
│   │   ├── Audio/                  # 音频播放
│   │   ├── Controllers/            # 控制器
│   │   ├── Network/                # 网络监控
│   │   ├── Storage/                # 数据存储
│   │   └── Streaming/              # 流媒体辅助
│   ├── Domain/                      # 领域层
│   │   ├── Models/                 # 数据模型
│   │   └── Services/               # 业务服务
│   ├── Utilities/                   # 工具类
│   │   ├── Logger.swift            # 日志系统
│   │   ├── Localization.swift      # 本地化
│   │   └── Extensions/             # Swift 扩展
│   └── Resources/                   # 资源
│       ├── Localizable.xcstrings   # 多语言
│       └── Assets.xcassets         # 图片资源
├── Chiaki/Platforms/tvOS/          # tvOS 特定代码
├── ChiakiTests/                     # 单元测试
├── ChiakiUITests/                   # UI 测试
├── chiaki-ng/                       # git submodule (libchiaki)
├── Frameworks/                      # 预编译框架
│   ├── libchiaki.xcframework
│   ├── opus.xcframework
│   └── mbedtls.xcframework
├── Scripts/                         # 构建脚本
└── docs/devdocs/                    # DevDocs 文档
```

### 3.2 代码统计

| 类型 | 数量 |
|------|------|
| Swift 源文件 | ~80 个 |
| Swift 代码行数 | ~13,000 行 |
| 单元测试文件 | 8 个 |
| UI 测试文件 | 4 个 |

---

## 4. 当前进度

### 4.1 总体进度

| 类型 | 总数 | 已完成 | 进行中 | 完成率 |
|------|------|--------|--------|--------|
| 功能点 (F-XXX) | 19 | 15 | 1 | 79% |
| M11 任务 (T-XXX) | 14 | 5 | 1 | 36% |
| 里程碑 | 11 | 10 | 1 | 91% |

### 4.2 里程碑状态

| 里程碑 | 状态 | 说明 |
|--------|------|------|
| M1-M9 | ✅ 已完成 | 项目初始化到功能完善 |
| M10 | ✅ 已完成 | SwiftUI 架构优化 |
| **M11** | 🔄 进行中 | Beta 1 发布冲刺 |

### 4.3 最近完成

| 时间 | 任务 | 提交 |
|------|------|------|
| 2026-01-28 | T-113: Metal VRR 节能调优 | `86b10ea` |
| 2026-01-28 | T-116: 语义化触觉反馈 (HapticsManager) | `d9e98ac` |
| 2026-01-28 | T-114: Info.plist 隐私说明 | `da63492` |
| 2026-01-28 | T-111: i18n 深度本地化 | `20024d5` |
| 2026-01-28 | T-112: NetworkMonitor 自动重连 | `d378546` |

### 4.4 当前进行中

| 任务 | 状态 | 说明 |
|------|------|------|
| T-115: tvOS App Icon | 🔄 配置完成 | 尺寸定义已添加，待图片资源 |

### 4.5 未提交变更

当前工作区干净，无未提交变更。
本地分支领先 origin/dev 22 个提交。

---

## 5. 待办任务

### 5.1 当前里程碑 (M11) 待办任务

| 优先级 | 任务 | TDD | 依赖 | 关联需求 |
|--------|------|-----|------|----------|
| **P0** | T-117: FileLogHandler 文件持久化 | 🔴 强制 | 无 | F-019, AC-049/050 |
| **P0** | T-118: Logger 集成 FileLogHandler | 🟡 推荐 | T-117 | F-019, AC-049 |
| **P0** | T-119: DiagnosticsExporter 诊断包导出 | 🔴 强制 | T-117, T-118 | F-019, AC-051/053 |
| P1 | T-120: CrashReporter 崩溃捕获 | 🔴 强制 | T-117 | F-019, AC-052 |
| P1 | T-121: LogViewerView 增强 | 🟢 可选 | T-119 | F-019, AC-051 |
| P1 | T-122: CrashReportView 崩溃报告 UI | 🟢 可选 | T-120 | F-019, AC-052 |
| P1 | T-123: App 启动集成 | ⚪ N/A | T-121, T-122 | F-019 |
| P1 | T-124: 核心流程日志覆盖增强 | ⚪ N/A | T-118 | F-019, AC-054 |

### 5.2 推荐执行顺序

```
T-117 (FileLogHandler)
    ↓
T-118 (Logger 集成)
    ↓
┌───┴───┬───────────┐
T-119   T-120       T-124
(诊断包) (崩溃捕获)  (日志覆盖)
    ↓       ↓
T-121   T-122
(UI)    (崩溃UI)
    └───┬───┘
        ↓
     T-123
   (App集成)
```

### 5.3 阻塞项

无阻塞项。

---

## 6. 重要约定

### 6.1 编码规范

- 遵循 MTE 原则（可维护、可测试、可扩展）
- 使用 `@Observable` 宏（非 `ObservableObject`）
- 使用 `.foregroundStyle()` 替代 `.foregroundColor()`
- 使用 `.clipShape()` 替代 `.cornerRadius()`
- 函数不超过 50 行，参数不超过 5 个

### 6.2 测试要求

- TDD 🔴 强制任务：必须先写测试
- TDD 🟡 推荐任务：建议先写测试
- TDD 🟢 可选任务：UI 层可后补测试
- 单元测试覆盖率目标 ≥ 80%

### 6.3 提交规范

```
<type>(<scope>): <subject>

类型: feat, fix, refactor, docs, test, chore
范围: core, ui, bridge, streaming, settings, etc.

示例:
feat(i18n): localize PSNLoginView hardcoded strings (T-111)
fix(test): resolve test runner crash and test failures
docs(F-019): add logging system design and task breakdown
```

### 6.4 代码追溯标注

```swift
/// 功能描述
/// @requirement F-XXX - 功能名称
/// @satisfies AC-XXX - 验收标准
```

---

## 7. 快速开始

### 7.1 环境准备

```bash
# 克隆仓库（含子模块）
git clone --recursive https://github.com/user/chiaki-apple.git
cd chiaki-apple

# 如果已克隆，初始化子模块
git submodule update --init --recursive
```

### 7.2 构建依赖

```bash
# 构建 libchiaki 及依赖
make build-deps
# 或单独构建
./Scripts/build_dependencies.sh
```

### 7.3 运行项目

```bash
# 使用 Xcode 打开
open Chiaki.xcodeproj

# 选择目标平台 (macOS/iOS/tvOS)
# 按 Cmd+R 运行
```

### 7.4 运行测试

```bash
# 单元测试
xcodebuild test -scheme Chiaki -destination 'platform=macOS' -only-testing:ChiakiTests

# UI 测试
xcodebuild test -scheme Chiaki -destination 'platform=macOS' -only-testing:ChiakiUITests
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| **上下文** | `00-context.md` | 本文件，项目全景概览 |
| **需求文档** | `01-requirements.md` | 功能点、用户故事、验收标准 |
| **系统设计** | `02-system-design.md` | 架构、接口、数据模型 |
| **测试用例** | `03-test-cases.md` | 测试策略、追溯矩阵 |
| **开发任务** | `04-dev-tasks.md` | M11 任务列表、依赖关系 |
| **任务归档** | `04-dev-tasks-archive.md` | M1-M10 已完成任务 |
| **洞察收集** | `05-insights.md` | 改进建议与转化记录 |

---

## 9. 接手建议

1. **阅读本文档** 了解项目全貌和当前状态
2. **查看待办任务** 从 T-117 (FileLogHandler) 开始
3. **运行测试** 确认环境正常：所有单元测试应通过
4. **查阅 DevDocs** 遇到细节问题查阅对应文档
5. **遵循 TDD** P0 任务必须先写测试

**当前推荐**：
- 继续日志系统：执行 `/devdocs-dev-workflow T-117` 开始 FileLogHandler 开发
- 或完成进行中任务：T-113 需 Instruments 验证，T-115 需图片资源
