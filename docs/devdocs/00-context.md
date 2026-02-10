# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-10
**生成工具**：/devdocs-onboard --update

---

## 1. 项目概述

### 1.1 项目目标

将 Chiaki-ng（开源 PlayStation 4/5 远程游玩客户端）从 Qt6 迁移到 Apple 原生技术栈，统一覆盖 macOS、iOS、iPadOS 和 tvOS 平台。使用 SwiftUI + Metal 实现原生体验，复用 libchiaki C 核心库保证协议兼容性。

### 1.2 核心功能状态

| 编号 | 功能 | 优先级 | 状态 |
|------|------|--------|------|
| F-001 | 核心流媒体 | P0 | ✅ 已完成 |
| F-002 | PS 主机发现 | P0 | ✅ 已完成 |
| F-003 | 主机唤醒 | P0 | ✅ 已完成 |
| F-004 | 控制器支持 | P0 | ✅ 已完成 |
| F-005 | PSN 账户登录 | P1 | ✅ 已完成 |
| F-010~F-014 | SwiftUI 架构优化 | P1~P3 | ✅ 已完成 |
| F-015~F-018 | 生产就绪配置 | P0~P1 | ✅ 已完成 |
| F-019 | 日志系统 | P0 | ✅ 已完成 |
| F-020 | 手柄操作友好化 | P0 | ✅ 已完成 |
| F-021~F-023 | 手柄/触摸深度集成 | P1~P2 | ✅ 已完成 |
| F-024~F-025 | HDR 设置与渲染管线 | P0~P1 | ✅ 已完成 |
| F-026~F-027 | 渲染模块解耦 / MVVM 重构 | P1 | ✅ 已完成 |
| F-028 | HDR 配置落地 | P0 | ✅ 已完成 |
| F-029 | MainActor 边界规范化 | P1 | ✅ 已完成 |
| F-030 | 日志输出规范化 | P2 | ✅ 已完成 |
| F-031~F-033 | 主题色/自动发现/TabView | P2 | ✅ 已完成 |
| F-034~F-038 | macOS 侧边栏/Slider/UI/Bridge 安全 | P1~P2 | ✅ 已完成 |
| F-039 | iPhone 串流横屏锁定 | P1 | ✅ 已完成 |
| **F-040** | **控制器架构分层重构** | **P0** | **⏳ 设计完成，待实施** |

**已完成 39 个功能点**，F-040 为活跃开发功能。

### 1.3 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI (iOS 17+ / macOS 14+ / tvOS 17+) |
| 状态管理 | @Observable (Observation 框架) |
| 视频渲染 | Metal + MetalKit + VideoToolbox |
| 音频播放 | AVFoundation + Opus 解码 |
| 网络通信 | libchiaki (C 核心库 via Bridge) |
| 手柄输入 | GameController + IOKit HID (macOS) |
| 本地存储 | UserDefaults + Keychain |
| 国际化 | String Catalogs (Localizable.xcstrings) |

### 1.4 代码规模

| 指标 | 数值 |
|------|------|
| Swift 源文件 | 92 个 |
| Swift 代码行数 | ~19,700 行 |
| C Bridge 文件 | 6 个 (1 .h + 5 .swift) |
| 测试文件 | 49 个 (单元) + 7 个 (UI) |
| UI 设计文件 | `designs/chiaki-apple-ui.pen` (24 screens) |
| @satisfies/@verifies 标注 | 459 处 (106 个文件) |

---

## 2. 系统架构

### 2.1 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views (UI Layer)                  │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│  │HostListView│ │StreamingView│ │SettingsView│ │  ...     │   │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘   │
├────────┼─────────────┼─────────────┼─────────────┼──────────┤
│        ▼             ▼             ▼             ▼          │
│              ViewModels (@Observable)                       │
│  ┌───────────────┐ ┌───────────────┐ ┌────────────────┐    │
│  │HostListViewModel│ │StreamingViewModel│ │SettingsStore│    │
│  └───────┬───────┘ └───────┬───────┘ └───────┬────────┘    │
├──────────┼─────────────────┼─────────────────┼──────────────┤
│          ▼                 ▼                 ▼              │
│                    Core Services                            │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│  │HostManager │ │ChiakiSession│ │VideoRenderer│ │AudioPlayer│   │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘   │
├────────┼─────────────┼─────────────┼─────────────┼──────────┤
│        ▼             ▼             ▼             ▼          │
│                    C Bridge Layer                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │           libchiaki (C Core Library)                │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心模块

| 模块 | 职责 | 关键文件 |
|------|------|----------|
| App | 应用入口、导航管理、方向控制 | `Chiaki/App/` (4 files) |
| Features | 功能页面 (HostList, Streaming, Settings) | `Chiaki/Features/` (41 files) |
| Domain | 业务逻辑服务层 | `Chiaki/Domain/` (4 files) |
| Core/Bridge | libchiaki C 桥接层 | `Chiaki/Core/Bridge/` (5 files) |
| Core/Video | Metal 视频渲染 (HDR/SDR) | `Chiaki/Core/Video/` (9 files) |
| Core/Audio | 音频播放与 Opus 解码 | `Chiaki/Core/Audio/` (3 files) |
| Core/Controllers | GameController + DualSense HID | `Chiaki/Core/Controllers/` (6 files) |
| Core/Storage | Keychain、主机/设置持久化 | `Chiaki/Core/Storage/` (4 files) |
| Shared | 跨功能协议 (PSNServicing, PinManaging) | `Chiaki/Shared/` |
| Utilities | 通用工具 (Logger, Theme, Haptics) | `Chiaki/Utilities/` (11 files) |
| Platforms | 平台特定代码 (tvOS/macOS) | `Chiaki/Platforms/` |

### 2.3 控制器架构 (F-040 待重构)

**当前架构** (单体):
```
StreamingViewModel → ControllerManager (824 行)
                     └── DualSenseHIDManager (468 行, macOS)
```

**目标架构** (Provider 分层, §21):
```
StreamingViewModel → ControllerOrchestrator (<300 行)
                     ├── GameControllerProvider (所有平台)
                     ├── DualSenseHIDProvider (macOS, HID 优先)
                     └── DualShock4HIDProvider (macOS, P2)
```

---

## 3. 代码结构

```
chiaki-apple/
├── Chiaki/
│   ├── App/                    # 应用入口 (ChiakiApp, Navigation, Orientation)
│   ├── Core/
│   │   ├── Audio/              # 音频播放 (AVFoundation + Opus)
│   │   ├── Bridge/             # C 桥接 (ChiakiSession, Discovery, Regist)
│   │   ├── Controllers/        # 手柄管理 (GCController, DualSense HID)
│   │   ├── Network/            # 网络监控 (NWPathMonitor)
│   │   ├── Storage/            # 持久化 (HostStore, SettingsStore, Keychain)
│   │   ├── Streaming/          # 流统计 (StreamStats)
│   │   └── Video/              # Metal 渲染 (HDR/SDR, VideoToolbox)
│   ├── Domain/                 # 业务逻辑 (HostManager, PSNService)
│   ├── Features/
│   │   ├── AutoConnect/        # 自动连接
│   │   ├── Common/             # 共享组件 (GamepadNumPad)
│   │   ├── HostList/           # 主机列表 (6 views + 2 viewmodels)
│   │   ├── PSNLogin/           # PSN OAuth 登录
│   │   ├── Settings/           # 设置页 (8 views + 3 viewmodels)
│   │   └── Streaming/          # 串流页 (StreamingView, Controls, VirtualController)
│   ├── Shared/                 # 协议 (PSNServicing, PinManaging)
│   ├── Utilities/              # 工具 (Logger, Theme, CrashReporter)
│   ├── Resources/              # Assets, Localizable.xcstrings
│   └── Platforms/              # tvOS/macOS 平台特定代码
├── ChiakiTests/                # 49 个测试文件
├── ChiakiUITests/              # 7 个 UI 测试文件
├── Frameworks/                 # XCFrameworks (libchiaki, opus, mbedtls)
├── Scripts/                    # 构建脚本 (build_libchiaki.sh 等)
├── docs/devdocs/               # DevDocs 文档体系
└── Chiaki.xcodeproj            # Xcode 项目
```

---

## 4. 当前进度

### 4.1 里程碑状态

| 里程碑 | 任务数 | 完成率 | 状态 |
|--------|--------|--------|------|
| M11 Beta 1 冲刺 | 35 | 97% | ✅ 已归档 |
| M12 HDR/渲染/MVVM | 24 | 100% | ✅ 已归档 |
| M13 HDR落地/MainActor/日志 | 23 | 100% | ✅ 已归档 |
| M14 macOS 设置侧边栏 | 4 | 100% | ✅ 已归档 |
| M15 UI/UX+Bridge 安全 | 18 | 100% | ✅ 已归档 |
| M16 iPhone 串流横屏锁定 | 2 | 100% | ✅ 已完成 |
| **M17 控制器架构分层重构** | **7** | **0%** | **⏳ 待开始** |
| Bug 修复 | 11 | 100% | ✅ |
| **总计** | **124** | **94%** | — |

> T-115 (App Icon 资产) 待设计师交付。BUG-018/019 待真机验证。

### 4.2 最近完成

| 提交 | 任务 | 说明 |
|------|------|------|
| 0eda629 | — | 文档同步至 M17 当前状态 |
| 52843ac | — | 全局追溯矩阵更新 F-023~F-040 |
| e594c25 | — | F-040 控制器架构设计与任务拆分 |
| 33fc790 | BUG-018/019 | IOKit HID: DualSense PS button + rumble (macOS) |
| 4a5d5a5 | BUG-017 | macOS 窗口最大化后视频模糊修复 |
| 9ebd0ac | BUG-016 | VideoToolbox 解码器重排缓冲优化 |
| f2286d8 | T-227/228 | HDR EDR 亮度与 macOS Retina 分辨率修复 |
| d42ca3c | T-221/222 | iPhone 串流横屏锁定 |

### 4.3 当前活跃任务 (M17)

```
T-229 协议定义 (P0, 🔴 TDD) ← 起点
  ├── T-230 GameControllerProvider (P0, 🟡)
  ├── T-231 DualSenseHIDProvider (P0, 🟡)
  └── T-232 ControllerOrchestrator (P0, 🔴 TDD)
        ├── T-233 StreamingVM 集成 (P0, 🟢)
        ├── T-234 DS4 HID Provider (P2, 🔴 TDD)
        └── T-235 清理+验证 (P1, 🟢)
```

### 4.4 未提交变更

```
无 — 工作区干净
```

---

## 5. 待办事项

### 5.1 M17 任务清单

| 编号 | 名称 | 优先级 | 新增/修改文件 |
|------|------|--------|--------------|
| T-229 | ControllerInputProvider + FeedbackOutput 协议 | P0 | `ControllerInputProvider.swift` (新) |
| T-230 | GameControllerProvider 实现 | P0 | `GameControllerProvider.swift` (新) |
| T-231 | DualSenseHIDManager → DualSenseHIDProvider | P0 | `DualSenseHIDProvider.swift` (新/删旧) |
| T-232 | ControllerOrchestrator 实现 | P0 | `ControllerOrchestrator.swift` (新) |
| T-233 | StreamingViewModel 切换到 Orchestrator | P0 | `StreamingViewModel.swift` (改) |
| T-234 | DualShock4HIDProvider (macOS only) | P2 | `DualShock4HIDProvider.swift` (新) |
| T-235 | 清理旧代码 + 全平台验证 | P1 | 删除 ControllerManager.swift |

### 5.2 遗留项

| 项目 | 说明 | 状态 |
|------|------|------|
| T-115 | App Icon 资产准备 | 待设计师提供 |
| BUG-018/019 | macOS DualSense BT HID 验证 | 🔧 待真机验证 |
| INS-047 | 解码重排策略优化 | ⏸️ 暂缓 |
| INS-060 | 空状态视图引导动画 | ⏳ P3 |
| INS-061 | 批量删除确认对话框 | ⏳ P3 |

---

## 6. 重要约定

### 6.1 编码规范

- **MTE 原则**：可维护、可测试、可扩展
- **MVVM 架构**：View → ViewModel → Service
- **@Observable 优先**：使用 Observation 框架替代 Combine
- **依赖注入**：通过 @Environment 注入，避免 Singleton
- **MainActor 边界**：所有 Store/ViewModel 标注 @MainActor，C Bridge 回调通过 MainActor.run 回主线程
- **平台条件编译**：`#if os(iOS)` / `#if os(macOS)` / `#if os(tvOS)` 隔离平台代码

### 6.2 代码追溯标注

```swift
/**
 * @requirement F-XXX - 功能点
 * @satisfies AC-XXX - 验收标准
 */
```

### 6.3 提交规范

```
<type>(scope): <description>

feat(T-XXX): 新功能
fix(BUG-XXX): Bug 修复
docs: 文档更新

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### 6.4 DevDocs 工作流

```
/devdocs-feature     → 新增功能需求
/devdocs-dev-workflow → 执行开发任务 (TDD + 骨架优先)
/devdocs-sync        → 同步文档与代码状态
/devdocs-bugfix      → Bug 修复工作流
```

---

## 7. 快速开始

### 7.1 环境要求

- Xcode 15.0+
- macOS 14.0+ / iOS 17.0+ / tvOS 17.0+
- 需要签名证书 (开发者账号)

### 7.2 构建项目

```bash
# 构建 C 依赖 (首次)
make frameworks

# 打开 Xcode 项目
open Chiaki.xcodeproj

# 命令行构建
xcodebuild -scheme Chiaki -destination 'platform=macOS' build
xcodebuild -scheme Chiaki -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 7.3 运行测试

```bash
xcodebuild test -scheme Chiaki -destination 'platform=macOS'
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目上下文 | `docs/devdocs/00-context.md` | 本文档 |
| 进度报告 | `docs/devdocs/00-progress-report.md` | M17 当前进度 |
| 功能日志 | `docs/devdocs/00-feature-log.md` | 新增功能变更记录 |
| 需求文档 | `docs/devdocs/01-requirements.md` | 40 功能点、用户故事、157 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构 §1~§21，含 F-040 控制器设计 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | UT-054/IT-018/E2E-013，追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | 124 任务 (M11~M17)、依赖关系 |
| 洞察收集 | `docs/devdocs/05-insights.md` | 81 条洞察 (75 完成, 4 待实现) |
| Bug 日志 | `docs/devdocs/05-bugfix-log.md` | BUG-001~019 修复记录 |
| 归档 | `docs/devdocs/archive/` | 已完成里程碑/设计/洞察归档 |
| UI 设计 | `designs/chiaki-apple-ui.pen` | Pencil 设计 (10 组件, 24 screens) |

---

## 接手建议

1. **先读本文档**了解项目全貌
2. **查看 §5 待办事项** — M17 T-229~T-235 为当前活跃任务
3. **阅读 02-system-design.md §21** 了解控制器架构重构设计
4. **使用 `/devdocs-dev-workflow T-229`** 从协议定义开始实施
5. 遇到细节问题查阅对应 DevDocs 文档

---

*文档由 `/devdocs-onboard --update` 生成 (2026-02-10)*
