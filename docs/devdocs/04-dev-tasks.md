# Chiaki-ng Apple 原生客户端 - 开发任务 (M11)

> **状态更新**: 2026-01-28 (F-019 日志系统增量)
> **阶段目标**: Beta 1 发布冲刺：生产就绪、体验打磨与稳定性增强 (M11)

## 任务概览

| 编号 | 名称 | 优先级 | TDD 模式 | 状态 |
|------|------|--------|----------|------|
| **T-111** | **i18n：深度本地化与 xcstrings 迁移** | P0 | 🟢 可选 | ✅ 已完成 |
| **T-112** | **稳定性：NetworkMonitor 与自动重连** | P0 | 🔴 强制 | ✅ 已完成 |
| **T-113** | **性能：Metal 渲染器节能调优 (VRR)** | P1 | ⚪ 不适用 | ⏳ 待处理 |
| **T-114** | **分发：Info.plist 隐私说明与元数据补全** | P1 | ⚪ 不适用 | ⏳ 待处理 |
| **T-115** | **分发：多平台 App Icon 资产准备** | P2 | ⚪ 不适用 | ⏳ 待处理 |
| **T-116** | **体验：语义化触觉反馈 (CoreHaptics) 精调** | P2 | 🟢 可选 | ⏳ 待处理 |
| **T-117** | **日志：FileLogHandler 文件持久化** | P0 | 🔴 强制 | ✅ 已完成 |
| **T-118** | **日志：Logger 集成 FileLogHandler** | P0 | 🟡 推荐 | ⏳ 待处理 |
| **T-119** | **日志：DiagnosticsExporter 诊断包导出** | P0 | 🔴 强制 | ⏳ 待处理 |
| **T-120** | **日志：CrashReporter 崩溃捕获** | P1 | 🔴 强制 | ⏳ 待处理 |
| **T-121** | **日志：LogViewerView 增强与诊断包 UI** | P1 | 🟢 可选 | ⏳ 待处理 |
| **T-122** | **日志：CrashReportView 崩溃报告 UI** | P1 | 🟢 可选 | ⏳ 待处理 |
| **T-123** | **日志：App 启动集成与本地化** | P1 | ⚪ 不适用 | ⏳ 待处理 |
| **T-124** | **日志：核心流程日志覆盖增强** | P1 | ⚪ 不适用 | ⏳ 待处理 |

## 任务详情

### T-111: i18n：深度本地化与 xcstrings 迁移 ✅
- **目标**: 实现 100% 本地化覆盖，移除硬编码。
- **关联需求**: F-015, AC-044
- **涉及文件**: `Localizable.xcstrings`, `Localization.swift`, `PSNLoginView.swift`
- **验收标准**:
  - [x] 所有的 `Text` 和 `String(localized:)` 均有对应的键值。
  - [x] Accessibility 标签完成本地化。
- **测试方法**: UT-15.1 (静态扫描)。
- **完成提交**: `20024d5` feat(i18n): localize PSNLoginView hardcoded strings

### T-112: 稳定性：NetworkMonitor 与自动重连 ✅
- **目标**: 处理 WiFi/5G 切换时的会话保持。
- **关联需求**: F-016, AC-045
- **涉及文件**:
  - `Chiaki/Core/Network/NetworkMonitor.swift` ✅
  - `Chiaki/Features/Streaming/StreamingViewModel.swift` ✅
- **验收标准**:
  - [x] 断网后 UI 提示"正在尝试重连"。
  - [x] 网络恢复后 5s 内自动恢复视频流。
- **测试方法**: 🔴 **TDD**: IT-16.1。
- **完成提交**: `d378546` refactor(streaming): extract modules from StreamingViewModel

### T-113: 性能：Metal 渲染器节能调优 (VRR)
- **目标**: 降低静态画面下的 GPU 功耗。
- **关联需求**: F-017, AC-046
- **涉及文件**: `Chiaki/Core/Render/MetalVideoRenderer.swift`
- **验收标准**: 静态画面下 GPU 负载显著降低。

### T-114: 分发：Info.plist 隐私说明与元数据补全
- **目标**: 满足 App Store 隐私审核要求。
- **关联需求**: F-018, AC-047
- **涉及文件**: `Info.plist`
- **验收标准**: 包含具体的麦克风、蓝牙和局域网扫描用途说明。

---

## F-019 日志系统任务 (T-117 ~ T-123)

> **来源**: F-019 完善日志系统 (INS-011 ~ INS-015)
> **关联需求**: AC-049 ~ AC-053

### T-117: 日志：FileLogHandler 文件持久化 ✅

- **目标**: 实现日志文件写入和轮换策略。
- **关联需求**: F-019, AC-049, AC-050
- **TDD 模式**: 🔴 强制（核心逻辑）
- **涉及文件**:
  - `Chiaki/Utilities/FileLogHandler.swift` ✅
- **依赖**: 无
- **验收标准**:
  - [x] 日志写入 `Documents/Logs/chiaki-current.log`
  - [x] 单文件超过 5MB 时自动轮换为 `chiaki-{timestamp}.log`
  - [x] 保留最近 7 个日志文件，自动删除旧文件
  - [x] 日志格式: `[时间] [级别] [分类] 消息`
- **测试方法**:
  - [x] UT-19.1: 测试日志写入文件
  - [x] UT-19.2: 测试轮换触发条件 (模拟 5MB)
  - [x] UT-19.3: 测试旧文件清理 (模拟 8 个文件)
- **Review 要点**:
  - [x] 文件写入线程安全 (writeLock)
  - [x] 文件句柄正确释放
  - [x] 轮换时不丢失日志
- **完成提交**: `f591f60` feat(core): implement FileLogHandler for log persistence (T-117)

### T-118: 日志：Logger 集成 FileLogHandler 🟡

- **目标**: 将 FileLogHandler 集成到现有 Logger 系统。
- **关联需求**: F-019, AC-049
- **TDD 模式**: 🟡 推荐
- **涉及文件**:
  - `Chiaki/Utilities/Logger.swift` (修改)
- **依赖**: T-117
- **验收标准**:
  - [ ] Logger.shared 初始化时自动添加 FileLogHandler
  - [ ] 提供 `fileLogHandler` 属性访问日志文件
  - [ ] Preview 模式下不启用文件日志
- **测试方法**:
  - UT-19.4: 测试 Logger 包含 FileLogHandler
  - IT-19.1: 集成测试日志同时输出到 os.log 和文件
- **Review 要点**:
  - [ ] 初始化失败不影响 Logger 正常工作
  - [ ] Preview 环境判断正确

### T-119: 日志：DiagnosticsExporter 诊断包导出 🔴

- **目标**: 实现诊断包生成和敏感信息脱敏。
- **关联需求**: F-019, AC-051, AC-053
- **TDD 模式**: 🔴 强制（核心逻辑）
- **涉及文件**:
  - `Chiaki/Utilities/DiagnosticsExporter.swift` (新增)
- **依赖**: T-117, T-118
- **验收标准**:
  - [ ] 生成 ZIP 包含: 日志文件、设备信息、网络状态、配置快照
  - [ ] IP 脱敏: `192.168.1.100` → `192.168.xxx.xxx`
  - [ ] Token 脱敏: 保留前 8 位 + `...`
  - [ ] User ID 脱敏: SHA256 哈希后取前 16 位
  - [ ] MAC 地址脱敏: 保留前 3 段
  - [ ] 注册密钥完全隐藏: `[REDACTED]`
- **测试方法**:
  - UT-19.5: 测试 IP 脱敏
  - UT-19.6: 测试 Token 脱敏
  - UT-19.7: 测试 User ID 脱敏
  - UT-19.8: 测试日志内容批量脱敏
  - IT-19.2: 集成测试 ZIP 生成和内容验证
- **Review 要点**:
  - [ ] 脱敏规则覆盖所有敏感字段
  - [ ] ZIP 文件结构正确
  - [ ] 异步导出不阻塞 UI

### T-120: 日志：CrashReporter 崩溃捕获 🔴

- **目标**: 捕获应用崩溃，记录崩溃信息。
- **关联需求**: F-019, AC-052
- **TDD 模式**: 🔴 强制（核心逻辑）
- **涉及文件**:
  - `Chiaki/Utilities/CrashReporter.swift` (新增)
- **依赖**: T-117
- **验收标准**:
  - [ ] 注册 SIGABRT、SIGSEGV 信号处理器
  - [ ] 捕获 Swift 未处理异常
  - [ ] 崩溃时写入 `crash_report.log`
  - [ ] 记录: 时间戳、信号/异常、调用栈、最后 50 条日志
  - [ ] 下次启动时可检测到崩溃报告
- **测试方法**:
  - UT-19.9: 测试崩溃报告写入
  - UT-19.10: 测试崩溃报告读取
  - UT-19.11: 测试崩溃报告清除
  - (手动) 模拟崩溃验证捕获
- **Review 要点**:
  - [ ] 信号处理器内不使用不安全的函数
  - [ ] 崩溃报告格式可解析
  - [ ] 不影响正常异常处理流程

### T-121: 日志：LogViewerView 增强与诊断包 UI 🟢

- **目标**: 在日志查看器中添加诊断包导出功能。
- **关联需求**: F-019, AC-051
- **TDD 模式**: 🟢 可选（UI 层）
- **涉及文件**:
  - `Chiaki/Features/Settings/LogViewerView.swift` (修改)
- **依赖**: T-119
- **验收标准**:
  - [ ] 新增"导出诊断包"按钮
  - [ ] 点击后显示导出进度
  - [ ] 导出完成后显示分享面板
  - [ ] 本地化所有新增文本
- **测试方法**:
  - (手动) UI 测试导出流程
  - E2E-19.1: 自动化测试按钮存在性
- **Review 要点**:
  - [ ] 按钮位置符合 UI 规范
  - [ ] 导出过程有进度反馈
  - [ ] 错误处理友好

### T-122: 日志：CrashReportView 崩溃报告 UI 🟢

- **目标**: 创建崩溃报告查看视图。
- **关联需求**: F-019, AC-052
- **TDD 模式**: 🟢 可选（UI 层）
- **涉及文件**:
  - `Chiaki/Features/Settings/CrashReportView.swift` (新增)
- **依赖**: T-120
- **验收标准**:
  - [ ] 显示崩溃时间、信号/异常信息
  - [ ] 显示调用栈（可滚动）
  - [ ] 显示最后日志条目
  - [ ] 提供"关闭并清除"按钮
  - [ ] 本地化所有文本
- **测试方法**:
  - (手动) UI 测试视图显示
  - E2E-19.2: 自动化测试视图内容
- **Review 要点**:
  - [ ] 调用栈使用等宽字体
  - [ ] 长内容可滚动
  - [ ] 关闭后正确清除报告

### T-123: 日志：App 启动集成与本地化 ⚪

- **目标**: 在应用启动时初始化崩溃捕获，添加本地化字符串。
- **关联需求**: F-019, AC-052
- **TDD 模式**: ⚪ 不适用（基础设施）
- **涉及文件**:
  - `Chiaki/App/ChiakiApp.swift` (修改)
  - `Chiaki/Resources/Localizable.xcstrings` (修改)
  - `Chiaki/Utilities/Localization.swift` (修改)
- **依赖**: T-120, T-121, T-122
- **验收标准**:
  - [ ] App 启动时调用 `CrashReporter.shared.initialize()`
  - [ ] 检测到崩溃报告时自动弹出 CrashReportView
  - [ ] 所有新增文本完成中英文本地化
- **测试方法**:
  - IT-19.3: 集成测试启动流程
  - (手动) 验证崩溃报告弹窗
- **Review 要点**:
  - [ ] 初始化时机正确（尽早）
  - [ ] 本地化 Key 命名规范
  - [ ] 弹窗不阻塞正常启动

### T-124: 日志：核心流程日志覆盖增强 ⚪

- **目标**: 在核心模块中增加关键操作的日志记录，确保问题可追溯。
- **关联需求**: F-019, AC-054
- **TDD 模式**: ⚪ 不适用（日志增强）
- **涉及文件**:
  - `Chiaki/Core/Bridge/ChiakiSessionWrapper.swift` (修改)
  - `Chiaki/Core/Video/VideoToolboxDecoder.swift` (修改)
  - `Chiaki/Core/Audio/AudioPlayer.swift` (修改)
  - `Chiaki/Core/Controllers/ControllerManager.swift` (修改)
  - `Chiaki/Domain/Services/DiscoveryService.swift` (修改)
  - `Chiaki/Domain/Services/PSNService.swift` (修改)
  - `Chiaki/Core/Network/NetworkMonitor.swift` (修改)
- **依赖**: T-117, T-118
- **验收标准**:
  - [ ] Session: 记录连接参数、握手阶段、认证步骤、会话建立/断开
  - [ ] Video: 记录 SPS/PPS 接收、解码器初始化、每 100 帧统计
  - [ ] Audio: 记录音频格式、缓冲欠载事件
  - [ ] Controller: 记录控制器连接/断开、类型识别
  - [ ] Discovery: 记录发现开始/停止、主机发现/丢失
  - [ ] PSN: 记录 OAuth 流程阶段、Token 刷新
  - [ ] Network: 记录连接类型变化
- **测试方法**:
  - (手动) 执行完整连接流程，验证日志完整性
  - IT-19.4: 集成测试日志输出验证
- **Review 要点**:
  - [ ] 使用正确的日志级别 (INFO/DEBUG)
  - [ ] 不记录敏感信息到日志
  - [ ] 日志消息清晰、可理解
  - [ ] 高频操作使用 DEBUG 级别避免日志爆炸

---

## 依赖关系图

```mermaid
graph TD
    T111[T-111: i18n 补全]
    T112[T-112: 自动重连]
    T113[T-113: VRR 调优]
    T114[T-114: 元数据补全]
    T115[T-115: App Icon]
    T116[T-116: 触觉精调]

    %% 日志系统任务
    T117[T-117: FileLogHandler]
    T118[T-118: Logger 集成]
    T119[T-119: DiagnosticsExporter]
    T120[T-120: CrashReporter]
    T121[T-121: 诊断包 UI]
    T122[T-122: 崩溃报告 UI]
    T123[T-123: App 启动集成]
    T124[T-124: 日志覆盖增强]

    %% 原有依赖
    T112 --> T113
    T114 --> T115

    %% 日志系统依赖链
    T117 --> T118
    T117 --> T120
    T118 --> T119
    T118 --> T124
    T119 --> T121
    T120 --> T122
    T121 --> T123
    T122 --> T123
```

## 执行检查清单

1. [ ] 本阶段任务执行前，必须确保 M10 回归测试全部通过。
2. [ ] 所有的本地化 Key 采用 `camelCase` 命名规范。
3. [ ] 提交 Beta 1 前需清理所有 `TODO` 标记。
