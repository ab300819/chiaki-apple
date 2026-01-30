# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-01-30 01:45
**生成工具**：/devdocs-onboard

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
| F-019 | 完善日志系统 (持久化/诊断包/崩溃捕获) | ✅ 已完成 |

### 1.3 技术栈
- **UI 框架**：SwiftUI (Modern APIs, @Observable)
- **图形渲染**：Metal (Zero-copy CVPixelBuffer)
- **视频解码**：VideoToolbox (H.264/H.265)
- **音频处理**：AVAudioEngine (Lock-free circular buffer)
- **底层通讯**：libchiaki (C 核心库桥接)
- **数据安全**：KeychainManager (CryptoKit)

---

## 2. 系统架构

### 2.1 架构概览
项目采用清晰的分层架构，确保逻辑解耦与跨平台复用：
- **Application Layer**: 各平台入口与生命周期管理。
- **Feature Layer**: 独立功能模块（主机列表、流媒体、设置等）。
- **Domain Layer**: 业务逻辑与状态管理（HostManager, SessionManager）。
- **Bridge Layer**: 与 libchiaki C 库的 Swift 封装层。
- **Native Layer**: Apple 原生底层集成（渲染器、音频引擎、控制器）。

### 2.2 核心模块
| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **Streaming** | 流媒体状态与生命周期 | `StreamingViewModel.swift` |
| **Renderer** | Metal 高性能渲染与 VRR | `MetalVideoRenderer.swift` |
| **Session** | C 库会话状态桥接 | `ChiakiSession.swift` |
| **Logging** | 日志持久化与脱敏 | `FileLogHandler.swift`, `DiagnosticsExporter.swift` |
| **Crash** | 崩溃监测与报告 | `CrashReporter.swift` |

### 2.3 核心接口
- `ChiakiSessionWrapper`: 连接、断开、发送输入。
- `VideoDecoderBridge`: 解码器配置与数据分发。
- `AudioPlayerBridge`: 音频同步与音量控制。

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
│   └── Streaming/      # 流媒体核心视图
├── Core/               # 底层基础设施
│   ├── Audio/          # 音频引擎
│   ├── Bridge/         # C 库桥接
│   ├── Controllers/    # 控制器与触觉
│   ├── Network/        # 网络状态监控
│   ├── Video/          # Metal 渲染与解码
│   └── Storage/        # 持久化存储
├── Domain/             # 业务逻辑模型
└── Utilities/          # 工具类与扩展
```

### 3.2 关键文件说明
| 文件 | 用途 |
|------|------|
| `ChiakiApp.swift` | App 启动集成，初始化崩溃捕获 |
| `Logger.swift` | 统一日志入口，集成文件持久化 |
| `DiagnosticsExporter.swift` | 诊断数据脱敏打包 (ZIP) |
| `Localizable.xcstrings` | 100% 覆盖的中英文本地化 |

---

## 4. 当前进度

### 4.1 总体进度 (M11)
| 类型 | 总数 | 已完成 | 进行中 | 完成率 |
|------|------|--------|--------|--------|
| 功能点 | 19 | 16 | 3 | 84% |
| 开发任务 | 14 | 11 | 0 | 78% |

### 4.2 最近完成
- **T-113**: Metal 渲染器节能调优 (VRR) (2026-01-30)
- **T-124**: 核心流程日志覆盖增强 (2026-01-30)
- **T-123**: App 启动集成与检测 (2026-01-30)
- **T-120/121/122**: 崩溃捕获与报告全链路实现 (2026-01-29)

### 4.3 未提交变更
- `Chiaki/Resources/Localizable.xcstrings`: 包含最新的日志/崩溃相关本地化文本。

---

## 5. 待办任务

### 5.1 下一步任务
| 优先级 | 任务 | 依赖 | 关联需求 |
|--------|------|------|----------|
| P0 | **T-125**: 分发：App Icon、版本号与发布配置 | - | F-018 |
| P1 | **T-114**: 分发：Info.plist 隐私说明补全 | - | AC-047 |
| P2 | **T-115**: 分发：多平台 App Icon 资产准备 | T-125 | F-018 |
| P2 | **T-116**: 体验：语义化触觉反馈 (CoreHaptics) 精调 | - | F-007 |

---

## 6. 重要约定

### 6.1 编码规范
- 使用 `@Observable` 宏进行状态管理。
- 强制 TDD：核心逻辑（Core 层）必须包含单元测试。
- 日志规范：所有核心路径必须有日志覆盖，且不记录明文敏感信息。

### 6.2 提交规范
- 格式：`<type>(scope): <subject> (T-XXX)`
- 示例：`feat(core): implement FileLogHandler (T-117)`

---

## 7. 快速开始

### 7.1 环境准备
```bash
make build-deps  # 构建 C 库依赖 (mbedtls, opus, libchiaki)
```

### 7.2 运行测试
```bash
xcodebuild test -scheme Chiaki -destination 'platform=macOS'
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 需求文档 | `docs/devdocs/01-requirements.md` | F-XXX 功能点、AC 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 模块化设计、Metal 渲染架构 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | UT/IT/E2E 追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | 任务列表与当前冲刺进度 |
| 进度报告 | `docs/devdocs/00-progress-report.md` | 自动化扫描的追溯状态 |

---

**接手建议**：
1. 先阅读 `00-progress-report.md` 查看当前的验收标准覆盖情况。
2. 运行现有的单元测试，确认 VRR 和日志系统的回归测试通过。
3. 从 **T-125** 开始整理发布所需的元数据，为 Beta 1 封包做准备。
