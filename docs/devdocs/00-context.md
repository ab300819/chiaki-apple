# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-12
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
| F-040 | 控制器架构分层重构 | P0 | ✅ 已完成 |
| F-041 | Metal 原生高质量视频滤波管线 | P1 | ✅ 已完成（降级为兼容模式） |
| **F-042** | **libplacebo 渲染后端集成** | **P0** | **🔄 进行中 (M19 50%)** |

**已完成 41 个功能点**，F-042 为活跃开发功能 (T-243~T-246 已完成，T-247~T-250 待实施)。

### 1.3 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI (iOS 17+ / macOS 14+ / tvOS 17+) |
| 状态管理 | @Observable (Observation 框架) |
| 视频渲染 | Metal + MetalKit + VideoToolbox（当前）→ libplacebo + MoltenVK（F-042 目标） |
| 音频播放 | AVFoundation + Opus 解码 |
| 网络通信 | libchiaki (C 核心库 via Bridge) |
| 手柄输入 | GameController + IOKit HID (macOS) — ControllerOrchestrator 架构 |
| 本地存储 | UserDefaults + Keychain |
| 国际化 | String Catalogs (Localizable.xcstrings) |

### 1.4 代码规模

| 指标 | 数值 |
|------|------|
| Swift 源文件 | 98 个 |
| Swift 代码行数 | ~21,400 行 |
| C Bridge 文件 | 7 个 (2 .h + 1 .m + 4 .swift) |
| 测试文件 | 56 个 (单元) + 7 个 (UI) |
| UI 设计文件 | `designs/chiaki-apple-ui.pen` (24 screens) |
| @satisfies/@verifies 标注 | 123 个文件 |

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
│  ┌──────────┐ ┌────────────┐ ┌──────────────┐ ┌──────────┐ │
│  │HostManager│ │ChiakiSession│ │VideoRenderer │ │AudioPlayer│ │
│  └────┬─────┘ └─────┬──────┘ └──────┬───────┘ └────┬─────┘ │
│       │              │               │               │       │
│       │              │        ┌──────┴───────┐       │       │
│       │              │        │              │       │       │
│       │              │  MetalVideo     Placebo       │       │
│       │              │  Renderer       Video         │       │
│       │              │  (兼容模式)     Renderer       │       │
│       │              │               (F-042 目标)     │       │
├───────┼──────────────┼───────────────────────────────┼──────┤
│       ▼              ▼                               ▼      │
│                    C Bridge Layer                            │
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
| Core/Bridge | libchiaki C 桥接层 | `Chiaki/Core/Bridge/` (6 files) |
| Core/Video | Metal + Placebo 渲染 (HDR/SDR, 滤波管线, VideoToolbox) | `Chiaki/Core/Video/` (14 files, 含 Placebo/ 子模块) |
| Core/Audio | 音频播放与 Opus 解码 | `Chiaki/Core/Audio/` (3 files) |
| Core/Controllers | ControllerOrchestrator + Provider 分层 | `Chiaki/Core/Controllers/` (9 files) |
| Core/Storage | Keychain、主机/设置持久化 | `Chiaki/Core/Storage/` (4 files) |
| Shared | 跨功能协议 (PSNServicing, PinManaging) | `Chiaki/Shared/` |
| Utilities | 通用工具 (Logger, Theme, Haptics) | `Chiaki/Utilities/` (11 files) |
| Platforms | 平台特定代码 (tvOS/macOS) | `Chiaki/Platforms/` |

### 2.3 控制器架构 (F-040 ✅ 已完成)

**Provider 分层架构** (§21):
```
StreamingViewModel → ControllerOrchestrator (<300 行)
                     ├── GameControllerProvider (所有平台)
                     ├── DualSenseHIDProvider (macOS, HID 优先)
                     └── DualShock4HIDProvider (macOS, P2)
```

### 2.4 视频渲染架构 (F-041 ✅ + F-042 ⏳)

**当前双后端架构** (§22 + §23):
```
StreamingViewModel
  ├── MetalVideoRenderer (F-041 兼容模式)
  │   └── Metal 原生: Bicubic + CAS + Deband
  └── PlaceboVideoRenderer (F-042 目标)
        └── libplacebo (pl_renderer)
              └── Phase 1: MoltenVK / Phase 2: Metal 原生后端
```

- **RenderBackend 枚举**: `.metalNative` / `.libplacebo` 切换
- **VideoRenderer 协议**: 统一接口，工厂方法按设置创建后端
- **Phase 1**: MoltenVK (Vulkan) 路径 → M19 里程碑
- **Phase 2**: libplacebo Metal 原生后端 → 后续里程碑
- **Phase 3**: libplacebo 默认，Metal 原生作为兼容/轻量模式

---

## 3. 代码结构

```
chiaki-apple/
├── Chiaki/
│   ├── App/                    # 应用入口 (ChiakiApp, Navigation, Orientation)
│   ├── Core/
│   │   ├── Audio/              # 音频播放 (AVFoundation + Opus)
│   │   ├── Bridge/             # C 桥接 (ChiakiSession, Discovery, Regist)
│   │   ├── Controllers/        # 手柄管理 (Orchestrator + Provider 分层)
│   │   ├── Network/            # 网络监控 (NWPathMonitor)
│   │   ├── Storage/            # 持久化 (HostStore, SettingsStore, Keychain)
│   │   ├── Streaming/          # 流统计 (StreamStats)
│   │   └── Video/              # Metal + Placebo 渲染 (HDR/SDR, 滤波管线, VTB)
│   │       └── Placebo/        # libplacebo C/Swift 桥接 (PlaceboBridge.h, PlaceboContext.m, PlaceboTypes.swift)
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
├── ChiakiTests/                # 52 个测试文件
├── ChiakiUITests/              # 7 个 UI 测试文件
├── Frameworks/                 # XCFrameworks (libchiaki, opus, mbedtls)
├── Scripts/                    # 构建脚本 (build_libchiaki.sh 等)
├── docs/devdocs/               # DevDocs 文档体系
├── designs/                    # Pencil UI 设计文件
├── metal-backend-*.md          # libplacebo Metal 后端设计文档 (3 份)
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
| M17 控制器架构分层重构 | 7 | 100% | ✅ 已完成 |
| M18 Metal 原生滤波管线 | 7 | 100% | ✅ 已完成 |
| **M19 libplacebo 渲染后端** | **8** | **50%** | **🔄 进行中** |
| Bug 修复 | 12 | 100% | ✅ |
| **总计** | **140** | **94%** | — |

> T-115 (App Icon 资产) 待设计师交付。

### 4.2 最近完成

| 提交 | 任务 | 说明 |
|------|------|------|
| efdc498 | T-246 | 零拷贝纹理导入 + 渲染管线 |
| 470bc2c | T-245 | PlaceboVideoRenderer 协议实现 |
| 4949f4d | T-244 | libplacebo C/Swift 桥接层 |
| 69e6df0 | T-243 | libplacebo + MoltenVK 构建脚本 |
| 77d2ab9 | BUG-020 | Metal shader 编译失败导致黑屏修复 |
| cec8a6a | T-242 | M18 全平台验证与测试修复 |

### 4.3 当前活跃任务 (M19 — libplacebo 渲染后端集成)

```
T-243 构建系统 (P0, 🟡) ✅
  └── T-244 C/Swift 桥接层 (P0, 🟡) ✅
        └── T-245 PlaceboVideoRenderer 核心 (P0, 🔴 TDD) ✅
              └── T-246 零拷贝纹理+渲染管线 (P0, 🔴 TDD) ✅
                    └── T-247 预设映射+HDR (P1, 🔴 TDD) ⏳ ← 下一个
                          └── T-248 后端切换+设置UI (P1, 🟡)
                                └── T-249 诊断+着色器缓存 (P1, 🟡)
                                      └── T-250 全平台验证 (P1, 🟢)
```

### 4.4 未提交变更

```
已修改 (2 文件):
  M docs/devdocs/00-progress-report.md
  M docs/devdocs/04-dev-tasks.md

未跟踪 (4 文件):
  ?? chiaki-ng (submodule, untracked content)
  ?? metal-backend-claude.md
  ?? metal-backend-gemini.md
  ?? metal-backend-gpt.md

36 个提交领先 origin/dev
```

---

## 5. 待办事项

### 5.1 M19 任务清单

| 编号 | 名称 | 优先级 | 状态 | 涉及文件 |
|------|------|--------|------|----------|
| T-243 | libplacebo + MoltenVK 构建系统 | P0 | ✅ | `Scripts/build-libplacebo.sh` |
| T-244 | C/Swift 桥接层 | P0 | ✅ | `PlaceboBridge.h`, `PlaceboContext.m`, `PlaceboTypes.swift` |
| T-245 | PlaceboVideoRenderer 核心实现 | P0 | ✅ | `PlaceboVideoRenderer.swift` |
| T-246 | 零拷贝纹理导入 + 渲染管线 | P0 | ✅ | `PlaceboVideoRenderer.swift`, `PlaceboContext.m` |
| **T-247** | **预设映射 + HDR 支持** | **P1** | **⏳** | `PlaceboVideoRenderer.swift`, `PlaceboTypes.swift` |
| T-248 | 后端切换 + 设置 UI | P1 | ⏳ | `StreamSettings.swift`, `VideoSettingsView.swift`, `StreamingViewModel.swift` |
| T-249 | 诊断接口 + Shader 缓存 | P1 | ⏳ | `StreamStatistics.swift`, `StreamingOverlay.swift` |
| T-250 | 全平台验证 + 性能基准 | P1 | ⏳ | 测试文件 |

### 5.2 遗留项

| 项目 | 说明 | 状态 |
|------|------|------|
| T-115 | App Icon 资产准备 | 待设计师提供 |
| INS-047 | 解码重排策略优化 | ⏸️ 暂缓 |
| INS-060 | 空状态视图引导动画 | ⏳ P3 |
| INS-061 | 批量删除确认对话框 | ⏳ P3 |

### 5.3 libplacebo Metal 后端 (Phase 2)

用户正在并行推进 libplacebo Metal 原生后端，有 3 份独立设计文档：
- `metal-backend-claude.md`
- `metal-backend-gemini.md`
- `metal-backend-gpt.md`

Phase 2 完成后将替代 MoltenVK，消除 Vulkan 翻译层开销。

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
/devdocs-insights    → 收集改进洞察
/devdocs-onboard     → 生成项目上下文
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
| 功能日志 | `docs/devdocs/00-feature-log.md` | 新增功能变更记录 (F-040~F-042) |
| 需求文档 | `docs/devdocs/01-requirements.md` | 42 功能点、用户故事、191 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构 §1~§23，含 F-042 libplacebo 设计 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | UT-066/IT-022/E2E-016，追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | 140 任务 (M11~M19)、依赖关系 |
| 洞察收集 | `docs/devdocs/05-insights.md` | 91 条洞察 (82 完成, 5 进行中, 3 暂缓) |
| Bug 日志 | `docs/devdocs/05-bugfix-log.md` | BUG-001~020 修复记录 |
| 归档 | `docs/devdocs/archive/` | 已完成里程碑/设计/洞察归档 |
| UI 设计 | `designs/chiaki-apple-ui.pen` | Pencil 设计 (10 组件, 24 screens) |

---

## 接手建议

1. **先读本文档**了解项目全貌
2. **查看 §5 待办事项** — M19 T-247~T-250 为当前待实施任务
3. **阅读 02-system-design.md §23** 了解 libplacebo 渲染后端集成设计
4. **阅读已完成代码**：`PlaceboVideoRenderer.swift`, `PlaceboTypes.swift`, `PlaceboContext.m`, `PlaceboBridge.h`
5. **使用 `/devdocs-dev-workflow T-247`** 从渲染预设映射 + HDR 支持开始
6. 遇到细节问题查阅对应 DevDocs 文档

---

*文档由 `/devdocs-onboard --update` 生成 (2026-02-12)*
