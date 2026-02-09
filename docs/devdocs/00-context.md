# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-09
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
| F-031 | 主题色系统化 | P2 | ✅ 已完成 |
| F-032 | 自动发现主机 | P2 | ✅ 已完成 |
| F-033 | macOS TabView 布局 | P2 | ✅ 已完成 |
| F-034 | macOS 设置侧边栏 | P2 | ✅ 已完成 |
| F-035 | Slider 布局规范化 | P2 | ✅ 已完成 |
| F-036 | HostListView UI/UX 优化 | P2 | ✅ 已完成 |
| F-037 | AddHostView/ConsolePinView 优化 | P2 | ✅ 已完成 |
| F-038 | Swift/C Bridge 安全加固 | P1 | ✅ 已完成 |

**全部 38 个功能点已完成**。未实现功能：F-006 (远程连接)、F-007 (触觉反馈)、F-008 (麦克风)、F-009 (虚拟输入) 为 P2~P3 低优先级，待后续迭代。

### 1.3 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI (iOS 17+ / macOS 14+) |
| 状态管理 | @Observable (Observation 框架) |
| 视频渲染 | Metal + MetalKit + VideoToolbox |
| 音频播放 | AVFoundation + Opus 解码 |
| 网络通信 | libchiaki (C 核心库 via Bridge) |
| 本地存储 | UserDefaults + Keychain |
| 国际化 | String Catalogs (Localizable.xcstrings) |

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
| App | 应用入口、导航管理 | `Chiaki/App/` |
| Features | 功能页面 (HostList, Streaming, Settings) | `Chiaki/Features/` |
| Domain | 业务逻辑服务层 | `Chiaki/Domain/` |
| Core/Bridge | libchiaki C 桥接层 | `Chiaki/Core/Bridge/` |
| Core/Video | Metal 视频渲染 (HDR/SDR) | `Chiaki/Core/Video/` |
| Core/Audio | 音频播放与 Opus 解码 | `Chiaki/Core/Audio/` |
| Core/Controllers | GameController 集成 | `Chiaki/Core/Controllers/` |
| Shared | 跨功能共享组件 | `Chiaki/Shared/` |
| Utilities | 通用工具 (Logger, Theme, Haptics) | `Chiaki/Utilities/` |
| Platforms | 平台特定代码 | `Chiaki/Platforms/` |

---

## 3. 代码结构

```
Chiaki/
├── App/                    # 应用入口
│   ├── ChiakiApp.swift     # @main 入口
│   └── NavigationManager.swift
├── Core/
│   ├── Audio/              # 音频播放
│   ├── Bridge/             # C 桥接 (ChiakiSession, etc.)
│   ├── Controllers/        # 手柄管理
│   ├── Network/            # 网络层
│   ├── Storage/            # 存储层
│   ├── Streaming/          # 流媒体核心
│   └── Video/              # Metal 渲染
├── Domain/                 # 业务逻辑服务层
├── Features/
│   ├── HostList/           # 主机列表页
│   ├── Settings/           # 设置页
│   ├── Streaming/          # 串流页
│   └── Common/             # 共享组件
├── Shared/                 # 跨功能共享组件
├── Utilities/              # 工具类
│   ├── ChiakiTheme.swift   # 主题系统
│   ├── Logger.swift        # 日志系统
│   └── HapticFeedback.swift
├── Resources/
│   └── Localizable.xcstrings # 国际化
└── Platforms/              # 平台特定代码
```

---

## 4. 当前进度

### 4.1 总体进度

| 里程碑 | 任务数 | 已完成 | 完成率 |
|--------|--------|--------|--------|
| M11 Beta 1 | 35 | 35 | 97% |
| M12 HDR/MVVM | 24 | 24 | 100% |
| M13 质量优化 | 23 | 23 | 100% |
| M14 macOS 侧边栏 | 4 | 4 | 100% |
| M15 UI/UX+Bridge 安全 | 18 | 18 | 100% |
| Bug 修复 | 5 | 5 | 100% |
| **总计** | **109** | **109** | **99%** |

> M11 有 1 个遗留任务 T-115 (App Icon 资产) 待设计师交付，不影响功能完整性。

### 4.2 最近完成

| 提交 | 任务 | 说明 |
|------|------|------|
| 14559c6 | T-219~T-220 | heap-allocate ChiakiLogBridge, SAFETY contracts |
| 99f5b59 | T-218 | unify updateState() to MainActor |
| 065cfca | T-217 | fix strdup memory leak in ChiakiRegist |
| e5f6a15 | T-216 | DiscoveryService deinit lifecycle cleanup |
| 26779d1 | T-215 | PINDisplay accessibility enhancements |
| b96cb05 | T-214 | ConsolePinView zh-Hans translations |
| 6f52cae~1f7cd13 | T-210~T-213 | AddHostView/ConsolePinView macOS form style |
| f25b371 | T-206~T-209 | HostListView UI/UX accessibility |

### 4.3 当前状态

**所有里程碑已完成**。项目处于迭代间歇期，可选方向：
- 集成测试验证
- 下一功能迭代 (F-006~F-009 等低优先级功能)
- 待定洞察 INS-060 (空状态动画)、INS-061 (批量删除确认)

### 4.4 未提交变更

```
M docs/devdocs/00-context.md          # 本文档更新
M docs/devdocs/01-requirements.md     # 归档瘦身
M docs/devdocs/02-system-design.md    # 归档瘦身
M docs/devdocs/04-dev-tasks.md        # M15 归档
M docs/devdocs/05-insights.md         # 全量归档
新增 docs/devdocs/archive/02-system-design-archive.md
```

---

## 5. 待办事项

### 5.1 遗留任务

| 任务 | 说明 | 状态 |
|------|------|------|
| T-115 | App Icon 资产准备 | 待设计师提供 |

### 5.2 待定洞察

| 编号 | 建议 | 优先级 |
|------|------|--------|
| INS-047 | 解码重排策略优化 (VideoToolboxDecoder) | ⏸️ 暂缓 |
| INS-060 | 空状态视图引导动画 | P3 |
| INS-061 | 批量删除确认对话框 | P3 |

---

## 6. 重要约定

### 6.1 编码规范

- **MTE 原则**：可维护、可测试、可扩展
- **MVVM 架构**：View → ViewModel → Service
- **@Observable 优先**：使用 Observation 框架替代 Combine
- **依赖注入**：通过 @Environment 注入，避免 Singleton
- **MainActor 边界**：所有 Store/ViewModel 标注 @MainActor，C Bridge 回调通过 MainActor.run 回主线程

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
fix(T-XXX): Bug 修复
refactor(T-XXX): 重构

关联: F-XXX, AC-XXX
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

---

## 7. 快速开始

### 7.1 环境要求

- Xcode 15.0+
- macOS 14.0+ / iOS 17.0+ / tvOS 17.0+
- 需要签名证书 (开发者账号)

### 7.2 构建项目

```bash
# 打开 Xcode 项目
open Chiaki.xcodeproj

# 或使用命令行构建
xcodebuild -scheme Chiaki -destination 'platform=macOS'
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
| 需求文档 | `docs/devdocs/01-requirements.md` | 功能点、用户故事、验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构、接口、数据模型 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | 测试策略、追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | 任务列表、依赖关系、进度 |
| 洞察收集 | `docs/devdocs/05-insights.md` | INS-XXX 改进建议 |
| 归档 | `docs/devdocs/archive/` | 已完成里程碑归档 |

---

## 接手建议

1. **先读本文档**了解项目全貌
2. **查看 04-dev-tasks.md** 确认当前任务状态（目前全部完成）
3. **查看 05-insights.md** 了解待定改进建议 (INS-060, INS-061)
4. **使用 `/devdocs-feature`** 添加新功能需求
5. **使用 `/devdocs-dev-workflow T-XXX`** 执行开发任务
6. 遇到细节问题查阅对应 DevDocs 文档

---

*文档由 `/devdocs-onboard --update` 生成 (2026-02-09)*
