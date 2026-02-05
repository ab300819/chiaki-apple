# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-05 01:30
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
| F-025 | HDR 渲染管线优化 | ✅ 已完成 (M12) |
| F-026 | 渲染模块解耦重构 | ✅ 已完成 (M12) |
| F-027 | UI 层 MVVM 合规重构 | ✅ 已完成 (M12) |
| F-028 | HDR 配置完全落地 | ✅ 已完成 (M13) |
| F-029 | MainActor 边界规范化 | ✅ 已完成 (M13) |
| F-030 | 日志输出规范化 | ✅ 已完成 (M13) |
| F-031 | 主题色系统化 | ✅ 已完成 (M13) |
| F-032 | 自动发现主机 | ✅ 已完成 (M13) |
| F-033 | macOS TabView 布局 | ✅ 已完成 (M13) |

### 1.3 技术栈
- **UI 框架**：SwiftUI (Modern APIs, @Observable)
- **图形渲染**：Metal (Zero-copy CVPixelBuffer, HDR/EDR)
- **视频解码**：VideoToolbox (H.264/H.265, HDR10/PQ)
- **音频处理**：AVAudioEngine + Opus Decoder (Lock-free circular buffer)
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
│  │ChiakiSession│ │ChiakiDiscovery│ │OpusDecoder │ │ChiakiAudio│ │
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
| **Audio** | Opus 解码 + AVAudioEngine | `OpusDecoderBridge.swift`, `AudioPlayerBridge.swift` |
| **Session** | C 库会话状态桥接 | `ChiakiSession.swift` |
| **Logging** | 日志持久化与脱敏 | `FileLogHandler.swift`, `DiagnosticsExporter.swift` |
| **Controller** | 手柄输入与触觉反馈 | `ControllerManager.swift`, `HapticsManager.swift` |
| **VirtualController** | 虚拟触摸控制器 | `VirtualControllerView.swift`, `VirtualButtonView.swift` |

### 2.3 核心接口
- `ChiakiSessionWrapper`: 连接、断开、发送输入
- `VideoDecoderBridge`: 解码器配置与数据分发
- `OpusDecoderBridge`: Opus 音频解码桥接
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
│   ├── Audio/          # 音频引擎 + Opus 解码
│   ├── Bridge/         # C 库桥接
│   ├── Controllers/    # 控制器与触觉
│   ├── Network/        # 网络状态监控
│   ├── Video/          # Metal 渲染、解码、HDR
│   │   ├── MetalVideoRenderer.swift
│   │   ├── VideoToolboxDecoder.swift
│   │   ├── VideoStreamView.swift
│   │   └── HDRConfiguration.swift
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

ChiakiTests/            # 单元测试与集成测试 (45 个测试文件)
```

### 3.2 关键文件说明
| 文件 | 用途 |
|------|------|
| `ChiakiApp.swift` | App 启动集成，初始化崩溃捕获 |
| `MetalVideoRenderer.swift` | Metal 视频渲染器 (HDR/EDR) |
| `HDRConfiguration.swift` | HDR 统一配置结构 |
| `VideoToolboxDecoder.swift` | 硬件视频解码 |
| `OpusDecoderBridge.swift` | Opus 音频解码桥接 |
| `Logger.swift` | 统一日志入口，集成文件持久化 |
| `DiagnosticsExporter.swift` | 诊断数据脱敏打包 (ZIP) |
| `Localizable.xcstrings` | 100% 覆盖的中英文本地化 |
| `StreamingOverlay.swift` | 流媒体状态覆盖层（含 HDR 徽章） |

### 3.3 代码统计
- **Swift 源文件**: 90 个
- **测试文件**: 45 个

---

## 4. 当前进度

### 4.1 里程碑状态
| 里程碑 | 目标 | 完成率 | 状态 |
|--------|------|--------|------|
| M11 | Beta 1 发布冲刺 | 97% (35/36) | ✅ 基本完成 |
| M12 | HDR 优化 + 架构重构 | 100% (24/24) | ✅ 已归档 |
| M13 | HDR 配置落地 + 代码质量 + UI 优化 | 100% (23/23) | ✅ 已完成 |

### 4.2 M13 完成进度
| 指标 | 数值 |
|------|------|
| 总任务数 | 23 |
| 已完成 | 23 |
| 进行中 | 0 |
| 待处理 | 0 |
| **完成率** | **100%** |

### 4.3 M13 完成任务汇总
| 功能 | 任务 | 提交 |
|------|------|------|
| F-028 HDR 配置落地 | T-171~T-174, T-182 | cf958bd, b736a4c |
| F-029 MainActor 边界 | T-175~T-177, T-183 | 83444ad, 61866a3, 6f6e6eb, 452f1eb |
| F-030 日志规范化 | T-178~T-181 | 8c975cd |
| F-031 主题色系统化 | T-189~T-191 | 6ae26c5 |
| F-032 自动发现主机 | T-192~T-194 | e6a08d7 |
| F-033 macOS TabView | T-195~T-198 | b1ce996 |

### 4.4 最近 Bug 修复
| Bug | 描述 | 修复日期 | Commit |
|-----|------|----------|--------|
| BUG-008 | ControllerSettingsView Preview 崩溃 | 2026-02-05 | `0dde4f5` |
| BUG-007 | 设置页面 i18n 显示异常 | 2026-02-05 | `0dde4f5` |
| BUG-006 | PS5 进入串流后断开 | 2026-02-04 | `8cdd1b1` |
| BUG-005 | 音频播放杂音 (Opus 解码) | 2026-02-04 | `12e570c`, `8999532` |
| BUG-004 | 唤醒后首次连接失败 | 2026-02-04 | `19fff2a` |

### 4.5 Git 状态
- **当前分支**: dev
- **最新提交**: `7471c24` docs: update M13 task status and traceability
- **工作区**: 干净

---

## 5. 待办任务

### 5.1 M13 已完成
M13 里程碑的所有 23 个任务已全部完成。详见 [4.3 M13 完成任务汇总](#43-m13-完成任务汇总)。

### 5.2 下一步建议
- 运行 `/devdocs-onboard --update` 更新项目上下文
- 规划 M14 里程碑任务
- 考虑发布 Beta 1 版本

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
- Bug 修复：`fix(scope): <subject>` + Bug 编号

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

### 7.2 构建项目
```bash
xcodebuild -scheme Chiaki -configuration Debug -destination 'platform=macOS' build
```

### 7.3 运行测试
```bash
xcodebuild test -scheme Chiaki -destination 'platform=macOS'
```

### 7.4 执行开发任务
```bash
# 使用 DevDocs 工作流开发
/devdocs-dev-workflow T-171
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 上下文 | `docs/devdocs/00-context.md` | 项目全貌与接手指南 (本文件) |
| 进度报告 | `docs/devdocs/00-progress-report.md` | M13 进度统计 |
| 需求文档 | `docs/devdocs/01-requirements.md` | F-001~033 功能点、AC-001~119 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构设计 v1.5.0 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | UT/IT/E2E 测试用例 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | M13 活跃任务 T-171~T-198 |
| 任务归档 | `docs/devdocs/archive/04-dev-tasks-archive.md` | 已完成任务归档 (M1~M12) |
| 洞察记录 | `docs/devdocs/05-insights.md` | 改进建议收集 |
| Bug 修复 | `docs/devdocs/05-bugfix-log.md` | Bug 修复记录 (BUG-001~008) |

---

**接手建议**：
1. 阅读本文档了解项目全貌
2. M13 已完成：HDR 配置落地 + 代码质量提升 + UI 优化
3. 项目当前处于 Beta 1 就绪状态
4. 遗留任务：T-115 (App Icon 资产准备) 等待设计师资源
5. 使用 `/devdocs-dev-workflow T-XXX` 执行新任务
6. 遇到细节问题查阅对应 DevDocs 文档

---

## 9. M13 关键技术点 (已完成)

### 9.1 HDR 配置完全落地 (F-028) ✅
已将 `HDRConfiguration` 中的字段传入 Shader：
- `VideoUniforms` 扩展：添加 `edrIntensity`、`gamutMappingEnabled`
- Shader 动态分支：根据配置执行色域映射和 EDR 强度调整
- CPU 端验证：`VideoShaderConstants.swift` 用于单元测试

### 9.2 MainActor 边界规范化 (F-029) ✅
Store 类已明确线程边界：
- `SettingsStore`、`HostStore` 整体标注 `@MainActor`
- `NetworkMonitor` 状态属性隔离
- 集成测试验证后台线程无法直接写入

### 9.3 主题色系统化 (F-031) ✅
已迁移为 Apple 系统强调色：
- `ChiakiTheme.brandColor` = `Color.accentColor`
- 支持 macOS 用户自定义强调色
- 保留 `chiakiPurple` deprecated 别名

### 9.4 自动发现主机 (F-032) ✅
已优化用户体验：
- 进入 `HostListView` 自动启动发现
- 移除工具栏发现按钮
- 保留下拉刷新和 macOS 菜单栏命令

### 9.5 macOS TabView 布局 (F-033) ✅
已实现跨平台一致性：
- macOS 使用 `TabView` 替代 `NavigationSplitView`
- 移除 `WelcomeView`（无需侧边栏空状态）
- 保持 macOS 菜单栏功能

---

*报告由 /devdocs-onboard 生成 (2026-02-05)*
