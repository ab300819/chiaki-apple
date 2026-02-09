# 需求归档 - Chiaki-ng Apple 原生客户端

> **归档时间**: 2026-02-08
> **归档原因**: 功能已完成并通过验收
> **归档版本**: M11 + M12 + M13 + M14 + M15

---

## 归档功能点

### F-010: API 现代化与规范化 ✅

**优先级**: P1 | **完成里程碑**: M9

**说明**: 迁移至 iOS 17+ 标准 API

**验收标准**:
- AC-035: 所有 `.foregroundColor()` 替换为 `.foregroundStyle()` ✅
- AC-036: 所有 `.cornerRadius()` 替换为 `.clipShape(.rect(cornerRadius:))` ✅
- AC-037: 视图样式逻辑与 iOS 17/18+ 设计规范对齐 ✅

---

### F-011: 状态管理统一化 ✅

**优先级**: P1 | **完成里程碑**: M9

**说明**: 全面迁移至 `@Observable` 框架

**验收标准**:
- AC-038: 所有的 `ObservableObject` 迁移至 `@Observable` 框架 ✅

---

### F-012: 架构解耦与重构 ✅

**优先级**: P2 | **完成里程碑**: M10

**说明**: 核心 ViewModel 逻辑拆分

**验收标准**:
- AC-039: `StreamingViewModel` 拆分为 `StatsManager` 和 `InputMapper` 等子模块 ✅
- AC-040: 子视图仅接收必要的原子属性而非整个 ViewModel 对象 ✅

---

### F-013: 交互体验精致化 ✅

**优先级**: P2 | **完成里程碑**: M10

**说明**: 优化动画曲线与反馈

**验收标准**:
- AC-041: 叠加层和菜单切换使用 `.spring()` 或 `.snappy` 动画曲线 ✅
- AC-043: 所有的按钮反馈符合各平台的主流交互习惯 ✅

---

### F-014: 未来特性适配 ✅

**优先级**: P3 | **完成里程碑**: M10

**说明**: Liquid Glass (iOS 26+) 适配

**验收标准**:
- AC-042: (iOS 26+) 在支持的设备上为流媒体控制菜单启用 `glassEffect` ✅

---

### F-015: 深度本地化与多语言支持 ✅

**优先级**: P0 | **完成里程碑**: M11

**说明**: 100% i18n 覆盖

**验收标准**:
- AC-044: 所有 UI 文本通过 `Localizable.xcstrings` 管理，无硬编码中文/英文 ✅

---

### F-016: 网络弹性与自动重连 ✅

**优先级**: P0 | **完成里程碑**: M11

**说明**: 增强网络波动下的恢复能力

**验收标准**:
- AC-045: 当 WiFi 断开并切换到 5G 时，应用在 5 秒内自动尝试重连 ✅

---

### F-017: 能效管理与渲染优化 ✅

**优先级**: P1 | **完成里程碑**: M11

**说明**: Variable Refresh Rate 与功耗调优

**验收标准**:
- AC-046: 静态画面下 GPU 功耗降低至少 20% (通过 Instruments 验证) ✅

---

### F-018: 应用分发元数据配置 ✅

**优先级**: P1 | **完成里程碑**: M11

**说明**: 隐私描述、Icon 与版本号

**验收标准**:
- AC-047: 所有的隐私访问（麦克风、局域网）均有清晰、合规的解释文案 ✅
- AC-048: 提供符合 Apple 规范的多尺寸 App Icon ⏳ (待设计师资产)

---

### F-019: 完善日志系统 ✅

**优先级**: P0 | **完成里程碑**: M11

**说明**: 日志持久化、诊断包导出、崩溃捕获

**验收标准**:
- AC-049: 日志实时写入文件，应用重启后仍可查看历史日志 ✅
- AC-050: 实现日志轮换策略（5MB/文件，保留最近 7 个文件，总上限约 35MB）✅
- AC-051: 提供"导出诊断包"功能 ✅
- AC-052: 应用崩溃时自动捕获异常信息，下次启动可查看 ✅
- AC-053: 导出日志时自动脱敏敏感信息 ✅
- AC-054: 核心流程有充足的日志覆盖 ✅

---

### F-020: 手柄操作友好化 ✅

**优先级**: P0 | **完成里程碑**: M11

**说明**: 焦点管理、快捷键、无触控操作

**验收标准**:
- AC-055: 流媒体控制菜单支持手柄方向键导航 ✅
- AC-056: tvOS 上所有可交互元素有明确的焦点状态视觉反馈 ✅
- AC-057: 控制菜单打开时实现焦点陷阱 ✅
- AC-058: tvOS 支持完整方向键导航命令 ✅
- AC-059: 支持手柄组合键快捷操作 ✅
- AC-060: 控制菜单关闭后焦点正确恢复 ✅

---

### F-021: GameController 深度集成 ✅

**优先级**: P2 | **完成里程碑**: M11

**说明**: 自适应扳机、触控板、电池显示

**验收标准**:
- AC-061: DualSense 自适应扳机支持 ✅
- AC-062: 触控板位置追踪 ✅
- AC-063: Haptics 引擎统一 ✅
- AC-064: 控制器电池电量显示 ✅

---

### F-022: 手柄操控 UI/UX 优化 ✅

**优先级**: P2 | **完成里程碑**: M11

**说明**: 快速操作栏、音量快捷键、数字键盘

**验收标准**:
- AC-065: 主机快速操作栏 ✅
- AC-066: 流媒体中音量快捷调节 ✅
- AC-067: PIN 输入数字键盘优化 ✅
- AC-068: 设置快捷入口 ✅

---

### F-023: iPad 触摸操作友好化 ✅

**优先级**: P1 | **完成里程碑**: M11

**说明**: 触摸目标、间距、手势、无障碍优化

**验收标准**:
- AC-069: 触摸目标尺寸 ≥44×44pt ✅
- AC-070: 控件间距优化 ≥16pt ✅
- AC-071: Slider 交互区域扩大到 44pt ✅
- AC-072: 触觉反馈一致性 ✅
- AC-073: 虚拟控制器无障碍 ✅
- AC-074: 长按手势支持 ✅
- AC-075: 滑动快捷调节 ✅

---

### F-024: HDR 设置优化 ✅

**优先级**: P1 | **完成里程碑**: M12

**说明**: EDR 强度调整、色彩空间选项简化

**验收标准**:
- AC-076: HDR 精调：在"设置-视频"中添加 EDR 强度滑块（0.5x - 2.0x，默认 1.0x），仅当 HDR 开启时显示 ✅
- AC-077: EDR 强度实时预览：调整滑块时实时应用到当前流媒体画面（如已连接）✅
- AC-078: 色彩空间简化：HDR 开启时隐藏色彩空间选项（自动使用 BT.2020）；HDR 关闭时仅显示 SDR 选项（BT.709/BT.601）✅
- AC-079: 设置持久化：EDR 强度设置保存到 UserDefaults，下次启动时恢复 ✅

---

### F-025: HDR 渲染管线优化 ✅

**优先级**: P0 | **完成里程碑**: M12

**说明**: 色域映射、动态 EDR Headroom、性能指标

**验收标准**:
- AC-080: 色域映射：在 Metal Shader 中实现 Rec.2020 → Display P3 色域转换矩阵，修复红色/绿色色偏 ✅
- AC-081: 动态 EDR Headroom：监听屏幕 EDR Headroom（macOS: NSScreen / iOS: UIScreen），实时传入 Shader Uniform ✅
- AC-082: Headroom 自适应：Shader 根据当前 Headroom 值动态调整 EDR 输出范围，避免过曝或过暗 ✅
- AC-083: 元数据抖动抑制：缓存高置信度 HDR 元数据，避免因 PixelFormat 变化导致频繁 pipeline 切换 ✅
- AC-084: Tone Mapping 降级：为不支持 EDR 的设备提供可选的 ACES Tone Mapping 降级路径（HDR→SDR）✅
- AC-085: 渲染性能指标：扩展 StreamStatsManager，新增 decode ms、render ms、P95/P99 延迟指标 ✅

---

### F-026: 渲染模块解耦重构 ✅

**优先级**: P1 | **完成里程碑**: M12

**说明**: 协议抽象、Delegate 分离、HDR 配置统一

**验收标准**:
- AC-086: 协议抽象：提取 `VideoRenderer` 协议，定义 `submitFrame`、`render`、显示模式、色彩调整等纯渲染接口 ✅
- AC-087: Delegate 分离：将 `MTKViewDelegate` 实现从 `MetalVideoRenderer` 移至 `VideoStreamView` 的 Coordinator ✅
- AC-088: HDR 配置统一：创建 `HDRConfiguration` 结构，统一管理 HDR 开关、EDR Headroom、色彩空间、Tonemap 模式 ✅
- AC-089: 依赖注入：`MetalVideoRenderer` 通过 `HDRConfiguration` 和 `edrHeadroom` 属性接收外部配置，不直接依赖 View 层 ✅

---

### F-027: UI 层 MVVM 合规重构 ✅

**优先级**: P1 | **完成里程碑**: M12

**说明**: Singleton 解耦、ViewModel 补全、协议抽象

**验收标准**:
- AC-090: Singleton 解耦 - HostListView：移除直接 `HostManager.shared` 和 `ConsolePinManager.shared` 访问，改为通过 ViewModel 或 `@Environment` 注入 ✅
- AC-091: Singleton 解耦 - AccountSettingsView：创建 `AccountSettingsViewModel` 封装 PSNService 操作，移除 `@State private var psnService = PSNService.shared` ✅
- AC-092: Singleton 解耦 - StreamingView/ControllerSettingsView：移除直接 Manager 访问，通过 ViewModel 代理 ✅
- AC-093: ViewModel 补全：为 `VideoSettingsView` 创建 `VideoSettingsViewModel`，封装 HDR Binding 转换逻辑 ✅
- AC-094: 业务逻辑分离：将 `ConsolesSettingsView` 中的 `hostStore.removeHost(host)` 等操作移至 ViewModel ✅
- AC-095: 协议抽象：为 `ConsolePinManager`、`PSNService` 定义协议（`PinManaging`、`PSNServicing`），支持 Mock 测试 ✅
- AC-096: 目录结构优化：评估并可选地将 Feature 目录拆分为 `Views/` 和 `ViewModels/` 子目录，创建 `Shared/Components/` 和 `Shared/Styles/` ✅

---

### F-028: HDR 配置完全落地 ✅

**优先级**: P0 | **完成里程碑**: M13

**说明**: Shader 动态分支、配置字段接入渲染

**验收标准**:
- AC-097: Shader 动态分支：将 `edrIntensity`、`gamutMappingEnabled` 等字段加入 `VideoUniforms`，Shader 根据配置动态执行 ✅
- AC-098: EDR 强度应用：`edrIntensity` 字段在 Shader 中作为乘数应用于 EDR 输出 ✅
- AC-099: 色域映射开关：`gamutMappingEnabled` 控制是否执行 Rec.2020→P3 色域映射 ✅
- AC-100: 单元测试覆盖：为 `VideoShaderConstants.swift` 补充单元测试，确保矩阵/tonemap 行为可回归 ✅

---

### F-029: MainActor 边界规范化 ✅

**优先级**: P1 | **完成里程碑**: M13

**说明**: Store 类 MainActor 标注、线程安全保障

**验收标准**:
- AC-101: SettingsStore 标注：`SettingsStore` 整体标注 `@MainActor` ✅
- AC-102: HostStore 标注：`HostStore` 整体标注 `@MainActor` ✅
- AC-103: 其他 Observable Store 审查：审查并标注其他作为 Environment 对象的 `@Observable` 类 ✅

---

### F-030: 日志输出规范化 ✅

**优先级**: P2 | **完成里程碑**: M13

**说明**: 统一 Logger 系统、DEBUG 保护、噪声清理

**验收标准**:
- AC-104: Logger 统一：`ChiakiSessionWrapper` 中的 debug `print` 替换为 Logger 系统调用 ✅
- AC-105: DEBUG 保护：确保 verbose 日志使用 `#if DEBUG` 保护 ✅
- AC-106: Bridge 层日志审查：审查其他 Bridge 层文件，统一日志输出方式 ✅

---

### F-031: 主题色系统化 ✅

**优先级**: P2 | **完成里程碑**: M13

**说明**: 迁移至 Apple 系统强调色

**验收标准**:
- AC-107: 品牌色迁移：`ChiakiTheme.brandPurple` 替换为 `Color.accentColor` ✅
- AC-108: 全局颜色更新：所有使用 `Color.chiakiPurple` 的位置迁移为 `Color.accentColor` ✅
- AC-109: 主题适配验证：确保深色/浅色模式下颜色表现正常 ✅
- AC-110: 系统强调色支持：macOS 支持用户自定义系统强调色 ✅

---

### F-032: 自动发现主机 ✅

**优先级**: P2 | **完成里程碑**: M13

**说明**: 进入主机列表自动启动发现，移除手动按钮

**验收标准**:
- AC-111: 自动启动发现：进入 `HostListView` 时自动调用 `startDiscovery()` ✅
- AC-112: 自动停止发现：离开 `HostListView` 或进入流媒体时停止发现 ✅
- AC-113: 移除发现按钮：从工具栏移除 wifi/wifi.slash 发现按钮 ✅
- AC-114: 保留下拉刷新：用户仍可通过下拉刷新手动触发发现 ✅
- AC-115: macOS 菜单保留：macOS 菜单栏的"Refresh Discovery"命令保留 ✅

---

### F-033: macOS TabView 布局 ✅

**优先级**: P2 | **完成里程碑**: M13

**说明**: macOS 采用 TabView 替代侧边栏，跨平台一致

**验收标准**:
- AC-116: TabView 替代侧边栏：macOS 使用 `TabView` 替代 `NavigationSplitView` ✅
- AC-117: Tab 项一致：Tab 项与 iOS/iPadOS 一致（Hosts、Settings）✅
- AC-118: 移除欢迎页：移除 `WelcomeView`（无需侧边栏空状态）✅
- AC-119: 菜单栏保留：macOS 菜单栏功能（Cmd+N 添加主机等）保持不变 ✅
- AC-120: 窗口样式调整：评估是否需要调整 `.windowStyle(.hiddenTitleBar)` ✅

---

### F-034: macOS 设置侧边栏导航 ✅

**优先级**: P2 | **完成里程碑**: M14

**说明**: macOS 设置页采用侧边栏替代顶部 TabView

**验收标准**:
- AC-121: macOS 设置页使用 `NavigationSplitView` + List 替代内部 TabView ✅
- AC-122: 左侧列表显示所有设置分类（General、Video、Audio、Controller、Account、Consoles、Logs、Data）✅
- AC-123: 右侧显示选中分类的设置内容 ✅
- AC-124: iOS/iPadOS/tvOS 保持现有 NavigationStack + Form 结构不变 ✅
- AC-125: 设置分类保持与现有顺序一致 ✅

---

### F-035: Slider 布局规范化 ✅

**优先级**: P2 | **完成里程碑**: M15

**说明**: 统一 Slider 样式、无障碍标签、数值格式

**验收标准**:
- AC-126: 所有 Slider 统一使用或统一省略 `.tint()` 修饰符 ✅
- AC-127: 所有 Slider 提供 label 闭包供 VoiceOver 使用 ✅
- AC-128: 百分比数值统一使用 L10n 本地化字符串格式 ✅

---

### F-036: HostListView UI/UX 优化 ✅

**优先级**: P2 | **完成里程碑**: M15

**说明**: 触摸目标、加载状态、颜色对比度、无障碍

**验收标准**:
- AC-129: HostRowView Wake Up 按钮触摸区域 ≥44pt 高度 ✅
- AC-130: 首次加载使用居中 ProgressView 或全屏 overlay，刷新时保留现有列表 ✅
- AC-131: 运行中应用颜色使用 `Color.accentColor` 替代固定 `.blue` ✅
- AC-132: TVHostCardView 状态徽章添加 accessibilityLabel ✅

---

### F-037: AddHostView/ConsolePinView UI/UX 优化 ✅

**优先级**: P2 | **完成里程碑**: M15

**说明**: 地址验证、Singleton 解耦、错误提示、无障碍、布局修复、本地化

**验收标准**:
- AC-133: AddHostView 添加地址格式验证（IP 地址或主机名）✅
- AC-134: ConsolePinView 通过闭包或 ViewModel 访问 PIN 管理，移除 Singleton 直接访问 ✅
- AC-135: ConsolePinEntryView 错误消息改用 `.callout` 字体 + 红色背景，增强可见性 ✅
- AC-136: PINDisplay 添加 `accessibilityElement` 和 `accessibilityLabel` ✅
- AC-137: AddHostView macOS 添加 `.formStyle(.grouped)` 修饰符 ✅
- AC-138: AddHostView 标题布局优化（macOS 居中或调整显示方式）✅
- AC-139: ConsolePinView placeholder 改为本地化的明确提示文本 ✅
- AC-140: ConsolePinView 底部说明本地化格式修复 ✅
- AC-141: ConsolePinView macOS 添加 `.formStyle(.grouped)` 修饰符 ✅
- AC-142: ConsolePinView 标题布局与 AddHostView 保持一致 ✅

---

### F-038: Swift/C Bridge 安全加固 ✅

**优先级**: P1 | **完成里程碑**: M15

**说明**: 回调生命周期、内存泄漏、线程边界、指针安全

**验收标准**:
- AC-143: DiscoveryService deinit 调用 stopDiscovery()，确保 C 层回调不会触发已释放对象 ✅
- AC-144: ChiakiRegistWrapper.start() 早退路径正确释放 strdup 分配的内存（使用 defer 模式）✅
- AC-145: ChiakiSessionWrapper/ChiakiRegistWrapper 的 updateState() 保证属性写入在 MainActor ✅
- AC-146: ChiakiLogBridge.getLogPointer() 改为稳定存储地址访问，避免 withUnsafeMutablePointer 逃逸 ✅
- AC-147: Bridge 层回调 userdata 所有权策略文档化（注释说明 passUnretained 安全前提）✅

---

## 归档统计

| 指标 | 数量 |
|------|------|
| 归档功能点 | 29 |
| 归档验收标准 | 114 |
| 完成里程碑 | M9, M10, M11, M12, M13, M14, M15 |

---

*归档操作由 `/devdocs-sync --archive` 执行*
