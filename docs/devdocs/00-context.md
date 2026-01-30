# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-01-30 18:30
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
| F-019 | 完善日志系统 (持久化/诊断包/崩溃捕获) | ✅ 已完成 |
| F-020 | 手柄操作友好化 | ⏳ 待开发 |
| F-021 | GameController 深度集成 | ⏳ 待开发 |
| F-022 | 手柄操控 UI/UX 优化 | ⏳ 待开发 |

### 1.3 技术栈
- **UI 框架**：SwiftUI (Modern APIs, @Observable)
- **图形渲染**：Metal (Zero-copy CVPixelBuffer)
- **视频解码**：VideoToolbox (H.264/H.265)
- **音频处理**：AVAudioEngine (Lock-free circular buffer)
- **底层通讯**：libchiaki (C 核心库桥接)
- **数据安全**：KeychainManager (CryptoKit)
- **控制器**：GameController framework (DualSense/MFi)

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
| **Controller** | 手柄输入与触觉反馈 | `ControllerManager.swift`, `HapticsManager.swift` |

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
├── Platforms/          # 平台特定代码 (macOS/tvOS)
└── Utilities/          # 工具类与扩展
```

### 3.2 关键文件说明
| 文件 | 用途 |
|------|------|
| `ChiakiApp.swift` | App 启动集成，初始化崩溃捕获 |
| `Logger.swift` | 统一日志入口，集成文件持久化 |
| `DiagnosticsExporter.swift` | 诊断数据脱敏打包 (ZIP) |
| `Localizable.xcstrings` | 100% 覆盖的中英文本地化 |
| `StreamingOverlay.swift` | 流媒体状态覆盖层（含 HDR 徽章） |

### 3.3 代码统计
- **Swift 源文件**: 67 个
- **测试文件**: 14 个 (Unit/Integration)

---

## 4. 当前进度

### 4.1 总体进度 (M11)
| 类型 | 总数 | 已完成 | 进行中 | 完成率 |
|------|------|--------|--------|--------|
| 功能点 | 22 | 16 | 0 | 73% |
| 开发任务 (T-111~135) | 25 | 12 | 0 | 48% |

### 4.2 最近完成
- **T-135**: StreamingOverlay HDR 标志 (2026-01-30) `3241eae`
- **T-113**: Metal 渲染器节能调优 (VRR) (2026-01-30)
- **T-124**: 核心流程日志覆盖增强 (2026-01-30)
- **T-123**: App 启动集成与检测 (2026-01-30)

### 4.3 本次会话工作 (F-022 文档完成)
| 阶段 | 提交 | 内容 |
|------|------|------|
| 需求 | `4193259` | F-022 需求定义 + INS-028~031 洞察 |
| 设计 | `dee6564` | F-022 系统设计 v1.5.0 (650 行) |
| 测试 | `b5011c1` | 37 个测试用例 (UT-017~020, IT-009~010, E2E-008~009) |
| 任务 | `ca3329f` | 开发任务 T-136~139 |

### 4.4 Git 状态
- **当前分支**: dev (领先 origin/dev 19 个提交)
- **工作区**: 干净 (无未提交变更)

---

## 5. 待办任务

### 5.1 F-020/F-021 手柄基础支持 (共 10 个任务)
| 优先级 | 任务 | 关联需求 | 状态 |
|--------|------|----------|------|
| P0 | **T-125**: 流媒体控制菜单焦点管理 | AC-055 | ⏳ |
| P0 | **T-126**: tvOS 焦点视觉反馈 | AC-056 | ⏳ |
| P0 | **T-127**: 控制菜单焦点陷阱 | AC-057 | ⏳ |
| P0 | **T-128**: tvOS 方向键导航完善 | AC-058 | ⏳ |
| P0 | **T-129**: 手柄组合键快捷操作 | AC-059 | ⏳ |
| P1 | **T-130**: 焦点恢复逻辑 | AC-060 | ⏳ |
| P2 | **T-131**: DualSense 自适应扳机 | AC-061 | ⏳ |
| P2 | **T-132**: 触控板位置追踪 | AC-062 | ⏳ |
| P2 | **T-133**: Haptics 引擎统一 | AC-063 | ⏳ |
| P2 | **T-134**: 控制器电池电量显示 | AC-064 | ⏳ |

### 5.2 F-022 手柄 UI/UX 优化 (共 4 个任务)
| 优先级 | 任务 | 关联需求 | 依赖 | 状态 |
|--------|------|----------|------|------|
| P1 | **T-136**: 主机快速操作栏 | AC-065 | 无 | ⏳ |
| P1 | **T-137**: 流媒体音量快捷调节 | AC-066 | T-129 | ⏳ |
| P2 | **T-138**: PIN 输入数字键盘 | AC-067 | 无 | ⏳ |
| P3 | **T-139**: 流媒体快速设置面板 | AC-068 | T-125 | ⏳ |

### 5.3 依赖关系
```
T-125 ──→ T-126, T-127, T-130, T-139
T-127 ──→ T-128, T-130
T-129 ──→ T-137
```

### 5.4 建议执行顺序
1. **F-020 基础**: T-125 → T-126 → T-127 → T-128 → T-129 → T-130
2. **F-021 并行**: T-131, T-132, T-133, T-134
3. **F-022 扩展**: T-136, T-138 (并行) → T-137, T-139

---

## 6. 重要约定

### 6.1 编码规范
- 使用 `@Observable` 宏进行状态管理
- 使用 `@FocusState` 管理焦点状态
- 强制 TDD：核心逻辑（Core 层）必须包含单元测试
- 日志规范：所有核心路径必须有日志覆盖

### 6.2 测试约束
- 单元测试覆盖率目标 ≥ 80%
- 禁止弱断言 (toBeDefined, toBeTruthy 不能作为唯一断言)
- Mock 只用于外部依赖

### 6.3 提交规范
- 格式：`<type>(scope): <subject> (T-XXX)`
- 示例：`feat(ui): add host quick action bar (T-136)`

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

### 7.3 执行开发任务
```bash
# 使用 DevDocs 工作流开发
/devdocs-dev-workflow T-125
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 上下文 | `docs/devdocs/00-context.md` | 项目全貌与接手指南 (本文件) |
| 需求文档 | `docs/devdocs/01-requirements.md` | F-001~022 功能点、AC-001~068 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构设计 v1.5.0 (含 F-022) |
| 测试用例 | `docs/devdocs/03-test-cases.md` | 320 个测试用例、追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | T-111~139 任务列表 |
| 洞察记录 | `docs/devdocs/05-insights.md` | INS-001~031 改进建议 |

---

**接手建议**：
1. 阅读本文档了解项目全貌
2. 查看"待办任务"部分了解当前工作重点
3. 从 **T-125** (流媒体控制菜单焦点管理) 开始实现 F-020
4. 使用 `/devdocs-dev-workflow T-XXX` 执行任务
5. 遇到细节问题查阅对应 DevDocs 文档
