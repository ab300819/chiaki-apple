# 开发任务归档

> **最后更新**: 2026-02-05
> **归档版本**: M11 + M12 + M13

---

# M13 归档 - HDR 配置落地、MainActor 边界、日志规范化、主题色、自动发现、macOS 布局

> **归档时间**: 2026-02-05
> **归档原因**: M13 任务 100% 完成
> **任务数量**: 23

## M13 归档任务汇总

| 编号 | 名称 | 优先级 | 关联需求 | 完成状态 |
|------|------|--------|----------|----------|
| T-171 | HDR: VideoUniforms 扩展 | P0 | F-028, AC-097 | ✅ |
| T-172 | HDR: VideoShaderConstants CPU 验证 | P0 | F-028, AC-100 | ✅ |
| T-173 | HDR: MetalVideoRenderer 配置同步 | P0 | F-028, AC-097~099 | ✅ |
| T-174 | HDR: Shader 动态分支 | P0 | F-028, AC-098~099 | ✅ |
| T-175 | MainActor: SettingsStore 标注 | P0 | F-029, AC-101 | ✅ |
| T-176 | MainActor: HostStore 标注 | P0 | F-029, AC-102 | ✅ |
| T-177 | MainActor: NetworkMonitor 状态隔离 | P1 | F-029, AC-103 | ✅ |
| T-178 | Logging: ChiakiSessionWrapper Logger 替换 | P1 | F-030, AC-104 | ✅ |
| T-179 | Logging: VideoDecoderBridge DEBUG 保护 | P1 | F-030, AC-105 | ✅ |
| T-180 | Logging: AudioPlayerBridge DEBUG 保护 | P1 | F-030, AC-105 | ✅ |
| T-181 | Logging: 其他 Bridge 层审查 | P2 | F-030, AC-106 | ✅ |
| T-182 | Test: VideoShaderConstants 单元测试 | P0 | F-028, AC-100 | ✅ |
| T-183 | Test: MainActor 边界集成测试 | P1 | F-029, AC-101~103 | ✅ |
| T-189 | Theme: ChiakiTheme 品牌色迁移 | P2 | F-031, AC-107 | ✅ |
| T-190 | Theme: 全局 chiakiPurple 替换 | P2 | F-031, AC-108 | ✅ |
| T-191 | Theme: 主题适配验证 | P2 | F-031, AC-109~110 | ✅ |
| T-192 | Discovery: HostListView 自动发现 | P2 | F-032, AC-111, AC-114 | ✅ |
| T-193 | Discovery: 移除发现按钮 | P2 | F-032, AC-113, AC-115 | ✅ |
| T-194 | Discovery: 生命周期优化 | P2 | F-032, AC-112 | ✅ |
| T-195 | Layout: macOS ContentView TabView 迁移 | P2 | F-033, AC-116~117 | ✅ |
| T-196 | Layout: 移除 NavigationSplitView 相关代码 | P2 | F-033, AC-118 | ✅ |
| T-197 | Layout: macOS 窗口样式调整 | P2 | F-033, AC-119~120 | ✅ |
| T-198 | Layout: 跨平台布局验证 | P2 | F-033, AC-116~120 | ✅ |

## M13 关键提交

| 功能 | 任务 | 提交 | 描述 |
|------|------|------|------|
| F-028 HDR | T-171, T-172, T-182 | `cf958bd` | feat(video): add VideoUniforms HDR fields and VideoShaderConstants |
| F-028 HDR | T-173, T-174 | `b736a4c` | feat(video): integrate HDR configuration into shader pipeline |
| F-029 MainActor | T-175 | `83444ad` | feat(storage): add @MainActor to SettingsStore |
| F-029 MainActor | T-176 | `61866a3` | feat(storage): add @MainActor to HostStore |
| F-029 MainActor | T-177 | `6f6e6eb` | feat(network): add @MainActor to NetworkMonitor |
| F-029 MainActor | T-183 | `452f1eb` | test(integration): add MainActor boundary tests |
| F-030 Logging | T-178~T-181 | `8c975cd` | refactor(logging): standardize logging across bridge layer |
| F-031 Theme | T-189~T-191 | `6ae26c5` | refactor(theme): migrate to system accent color |
| F-032 Discovery | T-192~T-194 | `e6a08d7` | feat(discovery): auto-start discovery on view appear |
| F-033 Layout | T-195~T-198 | `b1ce996` | refactor(layout): unify macOS/iOS with TabView |

## M13 涉及文件

**HDR 配置落地 (F-028)**:
- `Chiaki/Core/Video/MetalVideoRenderer.swift` (修改 - VideoUniforms 扩展)
- `Chiaki/Core/Video/VideoShaderConstants.swift` (新建)
- `ChiakiTests/VideoShaderConstantsTests.swift` (新建)
- `ChiakiTests/VideoUniformsTests.swift` (新建)
- `ChiakiTests/MetalVideoRendererHDRTests.swift` (新建)

**MainActor 边界规范化 (F-029)**:
- `Chiaki/Core/Storage/SettingsStore.swift` (修改)
- `Chiaki/Core/Storage/HostStore.swift` (修改)
- `Chiaki/Core/Network/NetworkMonitor.swift` (修改)
- `ChiakiTests/SettingsStoreMainActorTests.swift` (新建)
- `ChiakiTests/HostStoreMainActorTests.swift` (新建)
- `ChiakiTests/MainActorBoundaryTests.swift` (新建)

**日志输出规范化 (F-030)**:
- `Chiaki/Core/Bridge/ChiakiSession.swift` (修改)
- `Chiaki/Core/Video/VideoToolboxDecoder.swift` (修改)
- `Chiaki/Core/Audio/AudioPlayer.swift` (修改)
- `Chiaki/Core/Bridge/ChiakiRegist.swift` (修改)
- `Chiaki/Utilities/Logger.swift` (修改 - 添加 regist 类别)

**主题色系统化 (F-031)**:
- `Chiaki/Utilities/ChiakiTheme.swift` (修改)
- `Chiaki/App/ChiakiApp.swift` (修改)
- `Chiaki/Features/HostList/HostRowView.swift` (修改)
- `Chiaki/Features/HostList/TVHostCardView.swift` (修改)
- `Chiaki/Features/Settings/ControllerSettingsView.swift` (修改)
- `Chiaki/Features/Streaming/StreamingControlsView.swift` (修改)
- `Chiaki/Features/Streaming/QuickSettingsSection.swift` (修改)
- `Chiaki/Features/Streaming/TouchableSlider.swift` (修改)

**自动发现主机 (F-032)**:
- `Chiaki/Features/HostList/HostListView.swift` (修改)
- `Chiaki/Features/HostList/HostListViewModel.swift` (修改)
- `ChiakiTests/DiscoveryLifecycleTests.swift` (新建)

**macOS TabView 布局 (F-033)**:
- `Chiaki/App/ContentView.swift` (修改)
- `Chiaki/App/NavigationManager.swift` (修改)
- `Chiaki/App/ChiakiApp.swift` (修改)

---

# M12 归档 - HDR 渲染优化、渲染模块解耦、UI 层 MVVM 重构

> **归档时间**: 2026-02-05
> **归档原因**: M12 任务 100% 完成
> **任务数量**: 24

## M12 归档任务汇总

| 编号 | 名称 | 优先级 | 关联需求 | 完成状态 |
|------|------|--------|----------|----------|
| T-147 | HDR: HDRConfiguration 统一配置结构 | P0 | F-025, AC-088 | ✅ |
| T-148 | HDR: HDRMetadataCache 抖动抑制 | P0 | F-025, AC-083 | ✅ |
| T-149 | HDR: EDRHeadroomMonitor 动态监听 | P0 | F-025, AC-081 | ✅ |
| T-150 | HDR: Shader 色域映射 (Rec.2020→P3) | P0 | F-025, AC-080 | ✅ |
| T-151 | HDR: Shader ACES Tone Mapping | P1 | F-025, AC-084 | ✅ |
| T-152 | HDR: Shader Uniform 扩展 | P0 | F-025, AC-081~084 | ✅ |
| T-153 | HDR: MetalVideoRenderer 集成 | P0 | F-025, AC-080~083 | ✅ |
| T-154 | HDR: VideoStreamView EDR 集成 | P0 | F-025, AC-081~082 | ✅ |
| T-155 | Stats: 渲染性能指标扩展 | P1 | F-025, AC-085 | ✅ |
| T-156 | Render: VideoRenderer 协议抽象 | P0 | F-026, AC-086 | ✅ |
| T-157 | Render: MetalVideoRenderer 协议实现 | P0 | F-026, AC-086, AC-089 | ✅ |
| T-158 | Render: VideoStreamView.Coordinator 分离 | P1 | F-026, AC-087 | ✅ |
| T-159 | Protocol: PinManaging 协议定义 | P0 | F-027, AC-095 | ✅ |
| T-160 | Protocol: PSNServicing 协议定义 | P0 | F-027, AC-095 | ✅ |
| T-161 | Protocol: ConsolePinManager 协议实现 | P0 | F-027, AC-095 | ✅ |
| T-162 | Protocol: PSNService 协议实现 | P0 | F-027, AC-095 | ✅ |
| T-163 | VM: AccountSettingsViewModel | P0 | F-027, AC-091 | ✅ |
| T-164 | VM: VideoSettingsViewModel | P1 | F-027, AC-093 | ✅ |
| T-165 | VM: ConsolesSettingsViewModel | P1 | F-027, AC-094 | ✅ |
| T-166 | View: AccountSettingsView 重构 | P0 | F-027, AC-091 | ✅ |
| T-167 | View: VideoSettingsView 重构 | P1 | F-027, AC-093 | ✅ |
| T-168 | View: ConsolesSettingsView 重构 | P1 | F-027, AC-094 | ✅ |
| T-169 | View: HostListView Singleton 解耦 | P0 | F-027, AC-090 | ✅ |
| T-170 | View: StreamingView/ControllerSettingsView 解耦 | P1 | F-027, AC-092 | ✅ |

## M12 关键提交

| 任务 | 提交 | 描述 |
|------|------|------|
| T-147 | `11af485` | feat(video): add HDRConfiguration unified structure |
| T-148 | `4e315cb` | feat(video): add HDRMetadataCache jitter suppression |
| T-149 | `f02af86` | feat(video): add EDRHeadroomMonitor dynamic headroom tracking |
| T-150 | `d353a35` | feat(video): add Rec.2020 to P3 gamut mapping |
| T-151 | `47555af` | feat(video): add ACES Filmic tone mapping for HDR→SDR |
| T-152 | `cb61b66` | feat(video): extend shader uniforms with HDR parameters |
| T-153 | `2cd83ef` | feat(video): integrate HDRMetadataCache for jitter suppression |
| T-154 | `ecc9ad7` | feat(video): integrate EDR headroom monitoring in VideoStreamView |
| T-155 | `80c9ffb` | feat(stats): extend performance metrics with decode/render timing |
| T-159 | `3c05c37` | feat(protocol): define PinManaging protocol abstraction |
| T-160/162 | `d081981` | feat(protocol): define PSNServicing protocol abstraction |
| T-163 | `b1bda8a` | feat(viewmodel): add AccountSettingsViewModel for PSN operations |
| T-164 | `46e3b06` | feat(viewmodel): add VideoSettingsViewModel for HDR settings |
| T-165 | `59c5e02` | feat(viewmodel): add ConsolesSettingsViewModel for host management |
| T-166 | `1361575` | refactor(view): use AccountSettingsViewModel in AccountSettingsView |
| T-167 | `079b998` | refactor(view): use VideoSettingsViewModel in VideoSettingsView |
| T-168 | `4360f31` | refactor(view): use ConsolesSettingsViewModel in ConsolesSettingsView |
| T-169 | `4259fc9` | refactor(view): decouple HostListView from singletons |
| T-170 | `08744e3` | refactor(view): decouple StreamingView and ControllerSettingsView |

## M12 涉及文件

**HDR 渲染管线 (F-025)**:
- `Chiaki/Core/Video/HDRConfiguration.swift` (新建)
- `Chiaki/Core/Video/HDRMetadataCache.swift` (新建)
- `Chiaki/Core/Video/EDRHeadroomMonitor.swift` (新建)
- `Chiaki/Core/Video/VideoShaderConstants.swift` (新建)
- `Chiaki/Core/Video/MetalVideoRenderer.swift` (修改)
- `Chiaki/Core/Video/VideoStreamView.swift` (修改)
- `Chiaki/Core/Streaming/StreamStatsManager.swift` (修改)

**渲染模块解耦 (F-026)**:
- `Chiaki/Core/Video/VideoRenderer.swift` (新建/修改)
- `Chiaki/Core/Video/MetalVideoRenderer.swift` (重构)
- `Chiaki/Core/Video/VideoStreamView.swift` (重构)

**UI 层 MVVM 重构 (F-027)**:
- `Chiaki/Shared/Protocols/PinManaging.swift` (新建)
- `Chiaki/Shared/Protocols/PSNServicing.swift` (新建)
- `Chiaki/Features/Settings/ViewModels/AccountSettingsViewModel.swift` (新建)
- `Chiaki/Features/Settings/ViewModels/VideoSettingsViewModel.swift` (新建)
- `Chiaki/Features/Settings/ViewModels/ConsolesSettingsViewModel.swift` (新建)
- `Chiaki/Features/Settings/AccountSettingsView.swift` (重构)
- `Chiaki/Features/Settings/VideoSettingsView.swift` (重构)
- `Chiaki/Features/Settings/ConsolesSettingsView.swift` (重构)
- `Chiaki/Features/HostList/HostListView.swift` (重构)
- `Chiaki/Features/HostList/HostListViewModel.swift` (扩展)
- `Chiaki/Features/Streaming/StreamingView.swift` (重构)
- `Chiaki/Features/Streaming/StreamingViewModel.swift` (扩展)
- `Chiaki/Features/Settings/ControllerSettingsView.swift` (重构)

---

# M11 归档 - Beta 1 发布冲刺

> **归档时间**: 2026-02-04
> **归档原因**: M11 任务已完成
> **归档版本**: M11 (Beta 1 冲刺)

---

## 归档任务汇总

| 编号 | 名称 | 优先级 | 完成状态 |
|------|------|--------|----------|
| T-111 | i18n：深度本地化与 xcstrings 迁移 | P0 | ✅ 已完成 |
| T-112 | 稳定性：NetworkMonitor 与自动重连 | P0 | ✅ 已完成 |
| T-113 | 性能：Metal 渲染器节能调优 (VRR) | P1 | ✅ 已完成 |
| T-114 | 分发：Info.plist 隐私说明与元数据补全 | P1 | ✅ 已完成 |
| T-116 | 体验：语义化触觉反馈 (CoreHaptics) 精调 | P2 | ✅ 已完成 |
| T-117 | 日志：FileLogHandler 文件持久化 | P0 | ✅ 已完成 |
| T-118 | 日志：Logger 集成 FileLogHandler | P0 | ✅ 已完成 |
| T-119 | 日志：DiagnosticsExporter 诊断包导出 | P0 | ✅ 已完成 |
| T-120 | 日志：CrashReporter 崩溃捕获 | P1 | ✅ 已完成 |
| T-121 | 日志：LogViewerView 增强与诊断包 UI | P1 | ✅ 已完成 |
| T-122 | 日志：CrashReportView 崩溃报告 UI | P1 | ✅ 已完成 |
| T-123 | 日志：App 启动集成与本地化 | P1 | ✅ 已完成 |
| T-124 | 日志：核心流程日志覆盖增强 | P1 | ✅ 已完成 |
| T-125 | 手柄：控制菜单焦点管理 | P0 | ✅ 已完成 |
| T-126 | 手柄：tvOS 焦点视觉反馈 | P0 | ✅ 已完成 |
| T-127 | 手柄：控制菜单焦点陷阱 | P1 | ✅ 已完成 |
| T-128 | 手柄：tvOS 方向键导航 | P1 | ✅ 已完成 |
| T-129 | 手柄：组合键快捷操作 | P1 | ✅ 已完成 |
| T-130 | 手柄：焦点恢复逻辑 | P2 | ✅ 已完成 |
| T-131 | GC：DualSense 自适应扳机 | P2 | ✅ 已完成 |
| T-132 | GC：触控板位置追踪 | P2 | ✅ 已完成 |
| T-133 | GC：Haptics 引擎统一 | P1 | ✅ 已完成 |
| T-134 | GC：控制器电池电量显示 | P3 | ✅ 已完成 |
| T-135 | UI：StreamingOverlay HDR 标志 | P2 | ✅ 已完成 |
| T-136 | UI：主机快速操作栏 | P2 | ✅ 已完成 |
| T-137 | UI：流媒体音量快捷调节 | P1 | ✅ 已完成 |
| T-138 | UI：PIN 输入数字键盘 | P2 | ✅ 已完成 |
| T-139 | UI：流媒体快速设置面板 | P2 | ✅ 已完成 |
| T-140 | 触摸：触摸目标尺寸优化 | P0 | 📦 已归档 |
| T-141 | 触摸：控件间距优化 | P0 | 📦 已归档 |
| T-142 | 触摸：Slider 交互区域 | P1 | 📦 已归档 |
| T-143 | 触摸：触觉反馈统一 | P1 | 📦 已归档 |
| T-144 | 触摸：虚拟控制器无障碍 | P1 | 📦 已归档 |
| T-145 | 触摸：长按手势支持 | P2 | ✅ 已完成 |
| T-146 | 触摸：滑动快捷调节 | P2 | ✅ 已完成 |

---

## 任务详情

### T-111: i18n：深度本地化与 xcstrings 迁移 ✅

- **关联需求**: F-015, AC-044
- **完成提交**: `20024d5` feat(i18n): localize PSNLoginView hardcoded strings
- **涉及文件**: `Localizable.xcstrings`, `Localization.swift`, `PSNLoginView.swift`

---

### T-112: 稳定性：NetworkMonitor 与自动重连 ✅

- **关联需求**: F-016, AC-045
- **完成提交**: `d378546` refactor(streaming): extract modules from StreamingViewModel
- **涉及文件**:
  - `Chiaki/Core/Network/NetworkMonitor.swift`
  - `Chiaki/Features/Streaming/StreamingViewModel.swift`

---

### T-113: 性能：Metal 渲染器节能调优 (VRR) ✅

- **关联需求**: F-017, AC-046
- **完成提交**: `f491c92` feat(core): implement Variable Refresh Rate (VRR) for power optimization
- **涉及文件**:
  - `Chiaki/Core/Video/MetalVideoRenderer.swift`
  - `Chiaki/Domain/Models/StreamSettings.swift`
  - `Chiaki/Features/Settings/VideoSettingsView.swift`

---

### T-114: 分发：Info.plist 隐私说明与元数据补全 ✅

- **关联需求**: F-018, AC-047
- **完成提交**: `da63492` chore(meta): add privacy usage descriptions
- **涉及文件**: `Chiaki/Resources/Info.plist`

---

### T-116: 体验：语义化触觉反馈 (CoreHaptics) 精调 ✅

- **关联需求**: F-007, AC-017
- **完成提交**: `d9e98ac` feat(haptics): add semantic haptic feedback manager
- **涉及文件**:
  - `Chiaki/Core/Controllers/HapticsManager.swift`
  - `Chiaki/Core/Bridge/ChiakiSession.swift`
  - `Chiaki/Core/Streaming/StreamStatistics.swift`

---

### T-117 ~ T-124: F-019 日志系统任务 ✅

**完成提交**:
- `f591f60` feat(core): implement FileLogHandler for log persistence (T-117)
- `409317a` feat(core): integrate FileLogHandler into Logger system (T-118)
- `5e9baa7` feat(core): implement DiagnosticsExporter with data anonymization (T-119)
- `0562dcb` feat(core): implement CrashReporter for failure analysis (T-120)
- `fec2b3c` feat(ui): enhance LogViewerView with diagnostic package export (T-121)
- `f491c92` feat(ui): implement CrashReportView and reusable ShareSheet (T-122)
- `3801818` feat(app): integrate crash detection on startup and finalize localization (T-123)
- `19e9623` feat(core): enhance log coverage across core modules (T-124)

**涉及文件**:
- `Chiaki/Utilities/FileLogHandler.swift`
- `Chiaki/Utilities/Logger.swift`
- `Chiaki/Utilities/DiagnosticsExporter.swift`
- `Chiaki/Utilities/CrashReporter.swift`
- `Chiaki/Features/Settings/LogViewerView.swift`
- `Chiaki/Features/Settings/CrashReportView.swift`
- `Chiaki/App/ChiakiApp.swift`

---

### T-125 ~ T-130: F-020 手柄操作友好化任务 ✅

**完成提交**:
- `e47d95c` feat(ui): implement focus management for streaming controls (T-125)
- `bc77fae` feat(ui): add focus visual feedback for tvOS buttons (T-126)
- `f9d3d1e` feat(ui): implement focus trap for streaming control menu (T-127)
- `6a98368` feat(ui): implement tvOS remote navigation commands (T-128)
- `2257e97` feat(core): implement controller shortcut detector (T-129)
- `e91cadd` feat(ui): implement focus restoration for control menu (T-130)

**涉及文件**:
- `Chiaki/Features/Streaming/StreamingControlsView.swift`
- `Chiaki/Features/Streaming/StreamingControlFocus.swift`
- `Chiaki/Shared/Styles/FocusableButtonStyle.swift`
- `Chiaki/Features/Streaming/StreamingView.swift`
- `Chiaki/Core/Controllers/ControllerShortcutDetector.swift`

---

### T-131 ~ T-134: F-021 GameController 深度集成任务 ✅

**完成提交**:
- (T-131): DualSense 自适应扳机支持
- `3953a60` feat(core): implement DualSense touchpad position tracking (T-132)
- `f749b44` feat(core): unify haptics engine in HapticsManager (T-133)
- `b3b48cd` feat(ui): implement controller battery indicator (T-134)

**涉及文件**:
- `Chiaki/Core/Controllers/AdaptiveTriggerEffect.swift`
- `Chiaki/Core/Controllers/ControllerManager.swift`
- `Chiaki/Core/Bridge/ChiakiTypes.swift`
- `Chiaki/Core/Controllers/HapticsManager.swift`
- `Chiaki/Features/Streaming/ControllerBatteryIndicator.swift`

---

### T-135 ~ T-139: F-022 手柄操控 UI/UX 优化任务 ✅

**完成提交**:
- `3241eae` feat(ui): add HDR badge to StreamingOverlay (T-135)
- `dc5e0ac` feat(ui): implement host quick action bar for tvOS (T-136)
- (T-137): 流媒体音量快捷调节
- (T-138): PIN 输入数字键盘
- (T-139): 流媒体快速设置面板

**涉及文件**:
- `Chiaki/Features/Streaming/StreamingOverlay.swift`
- `Chiaki/Features/HostList/HostQuickActionBar.swift`
- `Chiaki/Features/Streaming/VolumeOSD.swift`
- `Chiaki/Features/Common/GamepadNumPad.swift`
- `Chiaki/Features/Streaming/QuickSettingsSection.swift`

---

### T-140 ~ T-146: F-023 iPad 触摸操作友好化任务 ✅

**T-140 ~ T-144 早前已归档** (符合 Apple HIG 44pt 标准)

**T-145 ~ T-146 完成提交**:
- (T-145): VirtualButtonView 长按手势支持
- (T-146): EdgeVolumeGesture 滑动快捷调节

**涉及文件**:
- `Chiaki/Features/Streaming/VirtualController/VirtualButtonView.swift`
- `Chiaki/Features/Streaming/EdgeVolumeGesture.swift`

---

## 归档统计

| 指标 | 数量 |
|------|------|
| 归档任务 | 35 |
| 完成任务 | 30 |
| 早前归档任务 | 5 |
| 进行中任务 | 1 (T-115) |
| Git 提交 | 20+ |

---

*归档操作由 `/devdocs-sync --archive` 执行*
