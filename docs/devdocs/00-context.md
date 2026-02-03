# 项目上下文：Chiaki-ng Apple 原生客户端

**生成时间**：2026-02-03 (更新)
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
| F-020 | 手柄操作友好化 | ✅ 已完成 |
| F-021 | GameController 深度集成 | ⏳ 待开发 |
| F-022 | 手柄操控 UI/UX 优化 | ✅ 已完成 |
| F-023 | iPad 触摸操作友好化 | ✅ 已完成 |

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
| **VirtualController** | 虚拟触摸控制器 | `VirtualControllerView.swift`, `VirtualButtonView.swift` |
| **EdgeGesture** | 边缘滑动手势 | `EdgeVolumeGesture.swift` |

### 2.3 核心接口
- `ChiakiSessionWrapper`: 连接、断开、发送输入。
- `VideoDecoderBridge`: 解码器配置与数据分发。
- `AudioPlayerBridge`: 音频同步与音量控制。
- `ControllerShortcutDetector`: 手柄快捷键检测（音量调节等）。

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
│       ├── VirtualController/  # 虚拟控制器组件
│       └── Controls/           # 流媒体控制组件
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
| `VirtualButtonView.swift` | 虚拟按钮组件（支持长按手势） |
| `EdgeVolumeGesture.swift` | 边缘滑动音量调节 |
| `ControllerShortcutDetector.swift` | 手柄快捷键检测器 |

### 3.3 代码统计
- **Swift 源文件**: 70+ 个
- **测试文件**: 16 个 (Unit/Integration)

---

## 4. 当前进度

### 4.1 总体进度 (M11)
| 类型 | 总数 | 已完成 | 进行中 | 完成率 |
|------|------|--------|--------|--------|
| 功能点 | 23 | 22 | 0 | 96% |
| 开发任务 (T-111~146) | 36 | 30 | 1 | 83% |

### 4.2 最近完成 (2026-02-02 ~ 02-03)
- **T-146**: 滑动快捷调节（边缘音量手势）`e36716c`
- **T-145**: 长按手势支持（虚拟按钮）`1ce7585`
- **T-139**: 流媒体快速设置面板 `58fe369`
- **T-138**: PIN 输入数字键盘 `bfa12a2`
- **T-137**: 流媒体音量快捷调节 `f5dfc62`
- **T-136**: 主机快速操作栏 `0a7f4b3`
- **T-144**: 虚拟控制器无障碍 `a2d97f5`
- **T-143**: 触觉反馈统一 `bc87252`
- **T-129**: 组合键快捷操作 `2257e97`
- **T-128**: tvOS 方向键导航 `6a98368`

### 4.3 归档记录
已归档 30 个完成任务至 `04-dev-tasks-archive.md`：
- **M11-Part1**: 生产就绪基础 (T-111~T-116)
- **M11-Part2**: 日志系统 F-019 (T-117~T-124)
- **M11-Part3**: 手柄操作友好化 F-020 (T-125~T-130)
- **M11-Part4**: iPad 触摸优化 F-023 (T-140~T-146)
- **M11-Part5**: 手柄 UI/UX 优化 F-022 (T-136~T-139)

### 4.4 Git 状态
- **当前分支**: dev
- **最新提交**: `2257e97` feat(core): implement controller shortcut detector (T-129)
- **工作区**: 有未提交变更 (文档更新)

---

## 5. 待办任务

### 5.1 唯一剩余任务
| 任务 | 名称 | 关联需求 | 状态 |
|------|------|----------|------|
| **T-115** | 多平台 App Icon 资产准备 | F-018 | ⏳ 等待设计师提供图像资产 |

### 5.2 F-021 待开发任务
以下任务属于 F-021 (GameController 深度集成)，暂未纳入 M11：
| 任务 | 名称 | 说明 |
|------|------|------|
| **T-131** | DualSense 自适应扳机 | 需要深入 GameController API |
| **T-132** | 触控板位置追踪 | 需要 DualSense 触控板支持 |
| **T-133** | Haptics 引擎统一 | 重构触觉反馈系统 |
| **T-134** | 控制器电池电量显示 | 需要 GameController API |

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

### 6.4 配置常量
关键配置值（便于调试和测试）：
| 常量 | 值 | 说明 |
|------|-----|------|
| `VirtualButtonConfig.longPressDuration` | 0.5s | 长按触发时间 |
| `VirtualButtonConfig.longPressScale` | 0.85 | 长按缩放比例 |
| `EdgeVolumeConfig.edgeWidth` | 44pt | 边缘检测宽度 (Apple HIG) |
| `EdgeVolumeConfig.minimumDragDistance` | 20pt | 最小拖拽距离 |
| `EdgeVolumeConfig.volumePerPoint` | 0.002 | 每点音量变化 |
| `VolumeAdjuster.step` | 0.05 | 手柄音量步进 |
| `VolumeOSD.autoHideDelay` | 2.0s | OSD 自动隐藏延迟 |

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
/devdocs-dev-workflow T-XXX
```

---

## 8. DevDocs 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 上下文 | `docs/devdocs/00-context.md` | 项目全貌与接手指南 (本文件) |
| 进度报告 | `docs/devdocs/00-progress-report.md` | M11 进度统计与追溯矩阵 |
| 需求文档 | `docs/devdocs/01-requirements.md` | F-001~023 功能点、AC-001~075 验收标准 |
| 系统设计 | `docs/devdocs/02-system-design.md` | 架构设计 v1.5.0 |
| 测试用例 | `docs/devdocs/03-test-cases.md` | 测试用例、追溯矩阵 |
| 开发任务 | `docs/devdocs/04-dev-tasks.md` | 活跃任务 T-131~146 |
| 任务归档 | `docs/devdocs/04-dev-tasks-archive.md` | 已完成任务归档 (M1~M11) |
| 洞察记录 | `docs/devdocs/05-insights.md` | INS-001~031 改进建议 |

---

**接手建议**：
1. 阅读本文档了解项目全貌
2. M11 开发任务已基本完成（96% 功能点，83% 任务）
3. 唯一剩余任务 **T-115** 等待设计师提供 App Icon 资产
4. 如需继续开发，可启动 F-021 (GameController 深度集成) 相关任务
5. 使用 `/devdocs-dev-workflow T-XXX` 执行任务
6. 遇到细节问题查阅对应 DevDocs 文档

---

## 9. Beta 1 发布准备

### 9.1 已完成
- [x] 所有 P0 优先级任务
- [x] 核心功能稳定
- [x] 日志与崩溃捕获系统
- [x] 手柄操作友好化 (F-020)
- [x] 手柄 UI/UX 优化 (F-022)
- [x] iPad 触摸优化 (F-023)
- [x] 虚拟控制器长按手势
- [x] 边缘滑动音量调节
- [x] 手柄快捷键音量调节

### 9.2 待完成
- [ ] 清理代码中的 TODO 标记
- [ ] 准备 TestFlight 元数据
- [ ] App Store Connect 配置
- [ ] 最终回归测试
- [ ] T-115: App Icon 资产（等待设计师）
