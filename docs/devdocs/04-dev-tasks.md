# Chiaki-ng Apple 原生客户端 - 开发任务

> **状态更新**: 2026-02-10
> **当前里程碑**: M17 — 控制器架构分层重构 | M18 — Metal 视频滤波管线
> **归档**: [archive/04-dev-tasks-archive.md](archive/04-dev-tasks-archive.md) (M11: 35 任务, M12: 24 任务, M13: 23 任务, M14: 4 任务, M15: 18 任务)

---

## 归档摘要

### M15 归档 (2026-02-09)

> **阶段目标**: UI/UX 质量优化 + Swift/C Bridge 安全加固 | **完成率**: 100% (18/18)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m15-归档---uiux-质量优化--swiftc-bridge-安全加固)

| 功能 | 任务 | 提交 |
|------|------|------|
| F-035 Slider 规范化 | T-203~T-205 | acfb854, 424b723, d61eefe |
| F-036 HostListView 优化 | T-206~T-209 | f25b371 |
| F-037 AddHost/ConsolePin | T-210~T-215 | 1f7cd13, d18b643, 63eec5d, 6f52cae, b96cb05, 26779d1 |
| F-038 Bridge 安全加固 | T-216~T-220 | e5f6a15, 065cfca, 99f5b59, 14559c6 |

### M14 归档 (2026-02-06)

> **阶段目标**: macOS 设置侧边栏导航 | **完成率**: 100% (4/4)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m14-归档---macos-设置侧边栏导航)

| 功能 | 任务 | 提交 |
|------|------|------|
| F-034 macOS 设置侧边栏 | T-199~T-202 | 9f94de7, 88ba705 |

### M13 归档 (2026-02-05)

> **阶段目标**: HDR 配置落地 + MainActor 边界规范化 + 日志规范化 + 主题色系统化 + 自动发现 + macOS 布局优化 | **完成率**: 100% (23/23)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m13-归档---hdr-配置落地mainactor-边界日志规范化主题色自动发现macos-布局)

| 功能 | 任务 | 提交 |
|------|------|------|
| F-028 HDR 配置落地 | T-171~T-174, T-182 | cf958bd, b736a4c |
| F-029 MainActor 边界 | T-175~T-177, T-183 | 83444ad, 61866a3, 6f6e6eb, 452f1eb |
| F-030 日志规范化 | T-178~T-181 | 8c975cd |
| F-031 主题色系统化 | T-189~T-191 | 6ae26c5 |
| F-032 自动发现主机 | T-192~T-194 | e6a08d7 |
| F-033 macOS TabView | T-195~T-198 | b1ce996 |

### M12 归档 (2026-02-05)

> **阶段目标**: HDR 渲染优化、渲染模块解耦、UI 层 MVVM 合规重构 | **完成率**: 100% (24/24)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m12-归档---hdr-渲染优化渲染模块解耦ui-层-mvvm-重构)

### M11 归档 (2026-02-04)

> **阶段目标**: Beta 1 发布冲刺 | **完成率**: 97% (35/36)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m11-归档---beta-1-发布冲刺)

---

## 遗留任务

### T-115: 分发：多平台 App Icon 资产准备 ⏳

- **关联需求**: F-018, AC-048
- **当前进度**: tvOS 配置已完成，待设计师提供实际图像资产
- **涉及文件**: `Assets.xcassets/AppIcon.appiconset/`

---

## Bug 修复任务

### BUG-005: 音频播放异常（咯哒声/杂音） ✅ 已修复

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-005](05-bugfix-log.md#bug-005-音频播放异常咯哒声杂音)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-185~T-188 | Audio: Opus 解码集成与端到端测试 | ✅ |

### BUG-004: 唤醒主机后首次连接失败 ✅ 已修复

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-004](05-bugfix-log.md#bug-004-唤醒主机后首次连接失败)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-184 | 修复唤醒后连接逻辑 | ✅ |

---

## M16 — iPhone 串流横屏锁定

> **阶段目标**: F-039 iPhone 串流画面锁定横屏方向 | **来源**: INS-077
> **关联需求**: F-039 (US-039, AC-148~AC-150)

### 依赖关系

```
T-221 (AppDelegate 方向控制基础设施)
  └── T-222 (StreamingView 方向锁定集成)
```

### T-221: 创建 AppDelegate 方向控制基础设施 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-039, AC-148 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟢 可选 (UI 基础设施) |
| **依赖** | 无 |

**描述**：

SwiftUI 无原生方向锁定 API，需通过 `UIApplicationDelegate` 桥接。创建最小化 AppDelegate 提供 `supportedInterfaceOrientationsFor` 回调，由全局状态控制返回值。

**涉及文件**：
- `Chiaki/App/ChiakiApp.swift` — 添加 `@UIApplicationDelegateAdaptor`
- `Chiaki/App/OrientationManager.swift` — **新建**，管理方向锁定状态

**实现要点**：
1. 新建 `OrientationManager` 单例（`@Observable`），持有 `lockOrientation: UIInterfaceOrientationMask?` 属性
2. 新建 `AppDelegate: NSObject, UIApplicationDelegate`，实现 `application(_:supportedInterfaceOrientationsFor:)` 方法
3. 当 `lockOrientation` 为 nil 时返回默认值（iPhone: portrait + landscape），非 nil 时返回锁定值
4. 在 `ChiakiApp` 中添加 `@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`
5. 仅 iOS 平台编译（`#if os(iOS)`），macOS/tvOS 不受影响

**验收标准**：
- OrientationManager 可设置/清除方向锁定
- AppDelegate 正确响应方向查询
- 不影响 macOS/tvOS 编译

**Review 要点**：
- AppDelegate 保持最小化，仅处理方向
- OrientationManager 线程安全（MainActor）
- 平台条件编译正确

---

### T-222: StreamingView 方向锁定集成 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-039, AC-148, AC-149, AC-150 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟢 可选 (UI 层) |
| **依赖** | T-221 |

**描述**：

在 StreamingView 中集成方向锁定：进入时锁定横屏，退出时恢复。

**涉及文件**：
- `Chiaki/Features/Streaming/StreamingView.swift` — 添加方向锁定逻辑

**实现要点**：
1. 在 StreamingView 的 `.onAppear` 中调用 `OrientationManager.shared.lockOrientation = .landscape`
2. 在 `.onDisappear` 中调用 `OrientationManager.shared.lockOrientation = nil`
3. 锁定后调用 `UIViewController.attemptRotationToDeviceOrientation()` 强制立即旋转
4. `.landscape` mask 自动支持 Left 和 Right 两个横屏方向
5. 仅 iPhone 生效（`#if os(iOS)` 内），iPad 保持原有行为（可两个方向）

**验收标准**：
- AC-148: 进入串流自动切换到横屏，竖屏状态下也会强制旋转
- AC-149: 退出串流后可自由旋转回竖屏，其他页面不受影响
- AC-150: iPad 不受影响（不锁定），macOS/tvOS 正常编译运行

**Review 要点**：
- onDisappear 清理可靠（包括异常退出路径）
- iPad 行为不受影响
- 无内存泄漏（避免强引用 OrientationManager）

---

## Bug 修复任务（新增）

### BUG-011: PS5 刚启动时首次连接失败 🔧

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-011](05-bugfix-log.md#bug-011-ps5-刚启动时首次连接失败)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-223 | 连接失败自动重试机制 | ✅ |

### T-223: 连接失败自动重试机制 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-001, F-002, BUG-011 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (网络层，需真机验证) |
| **依赖** | 无 |

**描述**：

PS5 刚启动时，Discovery 率先报告 `.online` 状态（网络层已就绪），但 Remote Play 服务可能尚需数秒完成初始化。当前 `connect()` 方法在 host 为 `.online` 时直接调用 `performConnection()` 无任何重试，导致首次连接因服务未就绪而失败。

**涉及文件**：
- `Chiaki/Features/Streaming/StreamingViewModel.swift` — 修改 `connect()` / `performConnection()` 逻辑

**实现要点**：
1. 在 `performConnection()` 捕获连接失败后，不立即设置 `.error` 状态
2. 添加重试逻辑：最多重试 3 次，每次间隔 2 秒
3. 重试期间状态保持 `.connecting`，UI 显示 "Connecting..."
4. 仅当所有重试都失败后才设置 `.error` 状态
5. 在 `session.onStateChanged` 中处理：当收到 `.error` 状态时触发重试而非立即显示错误

**验收标准**：
- PS5 刚启动后首次连接能自动重试并成功
- 重试次数不超过 3 次，避免无限重试
- 如果主机确实不可达（如 IP 错误），3 次重试后正常显示错误
- 不影响从待机唤醒的连接流程（`wakeAndConnect` 路径）

---

### BUG-012: 物理手柄输入未接入串流管线 🔧

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-012](05-bugfix-log.md#bug-012-物理手柄输入未接入串流管线)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-224 | 物理手柄输入转发到串流会话 | ✅ |

### T-224: 物理手柄输入转发到串流会话 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-004, BUG-012 |
| **优先级** | P0 |
| **TDD** | 🟢 可选 (需真机验证) |
| **依赖** | 无 |

**描述**：

`ControllerManager.onInputChanged` 回调从未被赋值。物理手柄输入在 `handleExtendedGamepadInput()` 产生后通过 `onInputChanged?(input)` 发出，但因回调为 nil 而被丢弃。虚拟手柄（触屏）通过 `VirtualControllerView → handleInput()` 正常工作，说明 `sendControllerInput()` 管线本身没问题。

**涉及文件**：
- `Chiaki/Features/Streaming/StreamingViewModel.swift` — 订阅物理手柄输入

**实现要点**：
1. 在 `StreamingViewModel.init()` 或 `setupSession()` 中，将 `ControllerManager.shared.onInputChanged` 赋值为 `sendControllerInput(_:)` 的闭包
2. 确保在 `disconnect()` 中清除回调（`ControllerManager.shared.onInputChanged = nil`），避免悬空引用
3. 同时连接 `session.onRumble` 到 `ControllerManager.shared.applyRumble()`，实现振动反馈
4. 使用 `[weak self]` 防止循环引用

**验收标准**：
- 物理手柄在串流中能正常控制 PS5
- 断开串流后手柄回调被清除
- 虚拟手柄功能不受影响
- DualSense 触控板输入也能正常转发
- 振动反馈能从 PS5 传递到物理手柄

---

### BUG-013: 手柄摇杆 Y 轴颠倒 + 振动反馈无效 🔧

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-013](05-bugfix-log.md#bug-013-手柄摇杆-y-轴颠倒--振动反馈无效)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-225 | 摇杆 Y 轴取反 + 控制器原生振动 | ✅ |

### T-225: 摇杆 Y 轴取反 + 控制器原生振动 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-004, BUG-013 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (需真机验证) |
| **依赖** | T-224 |

**描述**：

BUG-012 修复后手柄按键已有响应，但摇杆 Y 轴颠倒（GCController Y+ 向上 vs PlayStation Y+ 向下），振动反馈使用设备引擎而非控制器引擎。PS 键被 iOS 系统拦截为已知限制。

**涉及文件**：
- `Chiaki/Core/Controllers/ControllerManager.swift` — Y 轴取反、振动引擎重写

**实现要点**：
1. Y 轴值乘以 `-32767` 取反
2. `applyRumble()` 优先使用 `GCController.haptics.createEngine(withLocality: .handles)` 驱动物理手柄马达
3. 缓存 `rumbleEngine` 避免重复创建，控制器断开时清除
4. 无物理手柄时回退到 CoreHaptics 设备震动

**验收标准**：
- 摇杆上下方向与 PS5 一致
- 振动反馈在物理手柄上可感受到
- PS 键 iOS 已知限制已记录

---

### BUG-014: macOS 上 PS 键（buttonHome）无响应 🔧

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-014](05-bugfix-log.md#bug-014-macos-上-ps-键buttonhome无响应)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-226 | 为 buttonHome 注册独立 pressedChangedHandler | ✅ |

### T-226: 为 buttonHome 注册独立 pressedChangedHandler ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-004, BUG-014 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (需真机验证) |
| **依赖** | T-225 |

**描述**：

`buttonHome` 是 `GCExtendedGamepad` 的可选属性，不会触发主 `valueChangedHandler`。需为其注册独立的 `pressedChangedHandler`，与 touchpad 按钮采用相同模式。

**涉及文件**：
- `Chiaki/Core/Controllers/ControllerManager.swift` — `setupExtendedGamepadHandlers()` 添加 handler

**验收标准**：
- macOS 上 PS 键可被应用接收
- iOS 上 PS 键仍为系统拦截（已知限制）

---

### BUG-015: 串流画面偏暗、色彩失真、模糊 ✅

> **关联 Bug 记录**: [05-bugfix-log.md#BUG-015](05-bugfix-log.md#bug-015-串流画面偏暗色彩失真模糊)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-227 | HDR EDR 亮度映射修复 (linearToEDR 缩放因子) | ✅ |
| T-228 | macOS Retina drawable 分辨率修复 | ✅ |

### 依赖关系

```
T-227 (HDR EDR 亮度映射) ← 修复暗/色彩失真
T-228 (Retina drawable 分辨率) ← 修复模糊
两个任务互相独立
```

### T-227: HDR EDR 亮度映射修复 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-001, F-025, BUG-015 |
| **优先级** | P0 |
| **TDD** | 🟢 可选 (视觉验证) |
| **依赖** | 无 |

**描述**：

HDR 模式下 `linearToEDR()` 使用硬编码系数 12.5 (= 10000/800)，隐含 SDR 白 = 800 nits。但 Apple EDR 空间中 1.0 = SDR 白（标准约 200~203 nits），正确系数应为 `10000/203 ≈ 49.26`。当前系数导致 SDR 白 (203 nits) 映射到 ~0.76（当 edrHeadroom=3.0）而非 1.0，画面整体偏暗约 25~50%。

此外，着色器中 `rgb * edrHeadroom` 将 EDR headroom 作为乘数放大 HDR 值，但正确做法是不乘 headroom——Apple EDR 中超过 1.0 的值自动以 HDR 亮度显示直到 headroom 上限，无需手动缩放。

EDRHeadroomMonitor 还有初始化时序问题：`currentHeadroom` 从 1.0 开始，用 0.9/0.1 平滑收敛很慢。

**涉及文件**：
- `Chiaki/Core/Video/VideoShaders.txt` — `linearToEDR()` 缩放因子
- `Chiaki/Core/Video/MetalVideoRenderer.swift` — 内嵌着色器中的 `linearToEDR()` 和 edrHeadroom 用法

**实现要点**：
1. 修改 `linearToEDR()`：将 `linear * 12.5` 改为 `linear * (10000.0 / 203.0)` ≈ `linear * 49.26`
2. 移除 `* uniforms.edrHeadroom`：在 EDR 输出路径中，不应将 headroom 作为乘数；超过 1.0 的值自然以 HDR 显示
3. 保留 `* uniforms.edrIntensity`：这是用户可调的强度控制
4. 同步修改 VideoShaders.txt 和 MetalVideoRenderer.swift 中的内嵌着色器

**验收标准**：
- HDR 串流画面亮度与 PS5 直连 P3 显示器基本一致
- SDR 内容区域（如 PS 菜单）亮度正常（不过亮不过暗）
- SDR 模式不受影响
- 所有平台编译通过

---

### T-228: macOS Retina drawable 分辨率修复 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-001, BUG-015 |
| **优先级** | P0 |
| **TDD** | 🟢 可选 (视觉验证) |
| **依赖** | 无 |

**描述**：

macOS 上 `MTKView` 的 `CAMetalLayer.contentsScale` 默认为 1.0，在 Retina 显示器上 drawable 只有 1x 分辨率。iOS/tvOS 的 `UIView` 默认处理 scale，但 macOS 需要手动设置。

**涉及文件**：
- `Chiaki/Core/Video/VideoStreamView.swift` — macOS Retina 缩放配置

**实现要点**：
1. 在 `createMTKView()` 中，macOS 平台下设置 `mtkView.layer?.contentsScale = mtkView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0`
2. 由于 MTKView 创建时可能还未加入 window，需在 `updateMTKView()` 中也检查并更新 `contentsScale`
3. iOS/tvOS 不需要此处理

**验收标准**：
- macOS Retina 显示器上串流画面清晰锐利
- iOS/tvOS 不受影响
- 所有平台编译通过

---

## M17 — 控制器架构分层重构 ✅

> **阶段目标**: F-040 Controller Provider 分层架构 | **来源**: INS-078~081
> **关联需求**: F-040 (US-040, AC-151~AC-157)
> **关联测试**: UT-049~054, IT-017~018, E2E-013

### 依赖关系

```
T-229 (协议定义)
  ├── T-230 (GameController Provider) ← 依赖协议
  ├── T-231 (DualSense HID Provider) ← 依赖协议
  │
  └── T-232 (Orchestrator) ← 依赖 T-230 + T-231
        │
        └── T-233 (StreamingVM 集成) ← 依赖 T-232
              │
              └── T-234 (DualShock 4 HID Provider, P2) ← 依赖 T-232
                    │
                    └── T-235 (清理 + 验证) ← 依赖 T-233 + T-234
```

### T-229: 定义 ControllerInputProvider + ControllerFeedbackOutput 协议 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-151 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🔴 先测试 (UT-049, UT-050) |
| **依赖** | 无 |

**描述**：

定义控制器层核心协议和能力集类型。纯类型定义，不改动现有代码。

**涉及文件**：
- `Chiaki/Core/Controllers/ControllerInputProvider.swift` — **新建**

**实现要点**：
1. 定义 `ControllerInputProvider` 协议：providerId, displayName, isConnected, capabilities, currentInput, onInputChanged, onConnectionChanged, start(), stop()
2. 定义 `ControllerFeedbackOutput` 协议：sendRumble(left:right:), applyAdaptiveTrigger(effect:side:), setLEDColor(red:green:blue:), supportsFeedback(_:)
3. 定义 `ControllerCapabilities: OptionSet`：standardButtons, analogSticks, analogTriggers, psButton, touchpad, motion, rumble, adaptiveTriggers, ledColor
4. 定义便捷静态属性：`.dualSenseHID`, `.gameController`
5. 定义 `FeedbackType` 枚举

**验收标准**：
- 协议定义完整，可用于后续 Provider 实现
- 能力集正确区分 HID 和 GC 各自的职责
- 所有平台编译通过

---

### T-230: 实现 GameControllerProvider ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-151, AC-157 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟡 先骨架后测试 (UT-049.1) |
| **依赖** | T-229 |

**描述**：

从 ControllerManager 提取 GCController 相关逻辑，封装为 `GameControllerProvider`。

**涉及文件**：
- `Chiaki/Core/Controllers/GameControllerProvider.swift` — **新建**
- `Chiaki/Core/Controllers/ControllerManager.swift` — 提取逻辑（暂不删除）

**实现要点**：
1. 实现 `ControllerInputProvider` + `ControllerFeedbackOutput`
2. 从 ControllerManager 迁移：`setupExtendedGamepadHandlers()`, `handleExtendedGamepadInput()`, `applyRumble()` (GCDeviceHaptics 路径)
3. 添加 `bind(to: GCController)` / `unbind()` 方法
4. 触控板、运动传感器逻辑一并迁移
5. Y 轴取反逻辑保留在此 Provider 内
6. GCDeviceHaptics rumble 作为该 Provider 的 `sendRumble()` 实现

**验收标准**：
- GameControllerProvider 可独立编译
- bind/unbind 生命周期正确
- 所有 GCController 输入正确映射到 ChiakiControllerInput

---

### T-231: 重构 DualSenseHIDManager → DualSenseHIDProvider ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-152, AC-153 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟡 先骨架后测试 (UT-049.2) |
| **依赖** | T-229 |

**描述**：

将现有 `DualSenseHIDManager`（468 行）重构为实现 Provider 协议的 `DualSenseHIDProvider`。

**涉及文件**：
- `Chiaki/Core/Controllers/DualSenseHIDProvider.swift` — **新建** (重命名 + 接口适配)
- `Chiaki/Core/Controllers/DualSenseHIDManager.swift` — **删除** (迁移完成后)

**实现要点**：
1. 保留所有 IOKit HID 逻辑（设备发现、增强 BT 模式、报文解析、CRC32）
2. 实现 `ControllerInputProvider`：onInputChanged 回调替代 `onPSButtonChanged`
3. 实现 `ControllerFeedbackOutput`：`sendRumble()` 复用现有 `sendUSBRumble()`/`sendBTRumble()`
4. 添加 `applyAdaptiveTrigger()` 实现（DualSense 输出报文 byte 11-22）
5. 添加 `setLEDColor()` 实现（DualSense 输出报文 byte 44-46）
6. `supportedDevices` 静态属性声明 VID/PID
7. macOS only (`#if os(macOS)`)

**验收标准**：
- PS button 输入通过 Provider 协议回调
- rumble 通过 Provider 协议发送
- 与 GameControllerProvider 非排他共存
- BT 和 USB 路径均正常

---

### T-232: 实现 ControllerOrchestrator ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-152, AC-154, AC-155 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🔴 先测试 (UT-051, UT-052, UT-053) |
| **依赖** | T-230, T-231 |

**描述**：

实现核心编排器，取代 ControllerManager 的设备管理和输入分发职责。

**涉及文件**：
- `Chiaki/Core/Controllers/ControllerOrchestrator.swift` — **新建**

**实现要点**：
1. `@MainActor @Observable` 标注
2. GCController connect/disconnect 通知处理
3. VID/PID 匹配逻辑：检测 DualSense → 创建 HID + GC 双 Provider
4. 输入合并：HID → PS button，GC → 其他所有，按 capabilities 分配
5. 反馈路由：`feedbackProvider` 优先 HID，fallback GC
6. `applyRumble(left:right:)` 和 `applyAdaptiveTrigger(effect:side:)` 代理方法
7. 目标：< 300 行（不含空行和注释）

**验收标准**：
- AC-155: 代码行数 < 300 行
- 设备连接/断开正确管理 Provider 生命周期
- 输入合并结果与当前行为一致
- HID 优先反馈路由正确

---

### T-233: StreamingViewModel 集成 Orchestrator ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-155, AC-157 |
| **优先级** | P0 |
| **TDD** | 🟢 可选 (集成验证) |
| **依赖** | T-232 |

**描述**：

将 StreamingViewModel 从 `ControllerManager.shared` 切换到 `ControllerOrchestrator`。

**涉及文件**：
- `Chiaki/Features/Streaming/StreamingViewModel.swift` — 替换引用

**实现要点**：
1. 将 `ControllerManager.shared.onInputChanged` 替换为 `ControllerOrchestrator.shared.onInputChanged`
2. 将 `ControllerManager.shared.applyRumble()` 替换为 `ControllerOrchestrator.shared.applyRumble()`
3. 将 `ControllerManager.shared.applyAdaptiveTrigger()` 替换为 Orchestrator 方法
4. 更新 `ControllerSettingsView` 中的手柄列表引用
5. 确保 ControllerShortcutDetector 正常工作

**验收标准**：
- AC-157: 所有平台标准输入回归测试通过
- rumble 在 macOS DualSense 上通过 HID 发送
- rumble 在 iOS/tvOS 通过 GC 发送
- 虚拟手柄输入不受影响

---

### T-234: 新增 DualShock4HIDProvider ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-156 |
| **优先级** | P2 |
| **TDD** | 🔴 先测试 (UT-054) |
| **依赖** | T-232 |

**描述**：

新增 DualShock 4 的 IOKit HID Provider，解决 macOS 上 DS4 的 PS button 和 rumble 问题。

**涉及文件**：
- `Chiaki/Core/Controllers/DualShock4HIDProvider.swift` — **新建**

**实现要点**：
1. 实现 `ControllerInputProvider` + `ControllerFeedbackOutput`
2. VID/PID：0x054C:0x05C4 (v1), 0x054C:0x09CC (v2)
3. DS4 输入报文解析：PS button from buttons[2] bit 0
4. DS4 输出报文构造：
   - USB: Report ID 0x05, 32 bytes, motor_right (byte 4), motor_left (byte 5)
   - BT: Report ID 0x11, 78 bytes, motor_right (byte 6), motor_left (byte 7), CRC32
5. LED 颜色设置（byte 6/7/8 in USB, byte 8/9/10 in BT）
6. 能力集：psButton + rumble + ledColor（不含 adaptiveTriggers）
7. macOS only (`#if os(macOS)`)

**验收标准**：
- DS4 PS button 在 macOS BT 上可被读取
- DS4 rumble 在 macOS 上手柄物理振动
- DS4 LED 颜色可设置
- 不影响 DualSense 和通用手柄

---

### T-235: 清理旧代码 + 全平台验证 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-040, AC-157 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (回归验证) |
| **依赖** | T-233, T-234 |

**描述**：

删除旧 ControllerManager.swift 和 DualSenseHIDManager.swift，全平台编译验证。

**涉及文件**：
- `Chiaki/Core/Controllers/ControllerManager.swift` — **删除**
- `Chiaki/Core/Controllers/DualSenseHIDManager.swift` — **删除** (如 T-231 未删)
- 全项目搜索替换 `ControllerManager` → `ControllerOrchestrator` 残留引用

**实现要点**：
1. 删除 ControllerManager.swift
2. 全局搜索 `ControllerManager` 引用，替换为 `ControllerOrchestrator`
3. macOS / iOS / tvOS 三平台 `xcodebuild` 编译验证
4. 运行 IT-017, IT-018 集成测试
5. 更新 `02-system-design.md` §2.6 控制器模块描述（标注已被 §21 替代）

**验收标准**：
- 全平台编译通过
- 无 `ControllerManager` 残留引用
- 所有测试通过

---

## M18 — Metal 原生高质量视频滤波管线 ✅

> **功能**: F-041 | **来源**: INS-082~INS-084 | **关联 Bug**: BUG-016, BUG-017
> **目标**: 在现有 Metal shader 中实现 Bicubic 上采样、CAS 锐化、去色带抖动，替代纯双线性采样，解决放大模糊和运动模糊残留问题

### 依赖关系

```
T-236 VideoUniforms 扩展 + VideoFilterConfig (P0, 🔴 TDD)
  ├── T-237 Bicubic Catmull-Rom 上采样 (P0, 🔴 TDD)
  ├── T-238 CAS 自适应锐化 (P0, 🔴 TDD)
  ├── T-239 去色带 + 有序抖动 (P0, 🟡)
  │
  └── T-240 预设→渲染参数映射 (P1, 🟡)
        │
        └── T-241 渲染诊断指标 (P1, 🟡)
              │
              └── T-242 全平台验证 + 性能基准 (P1, 🟢)
```

---

### T-236: VideoUniforms 扩展 + VideoFilterConfig 定义 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-159, AC-161, AC-163 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🔴 先测试 (UT-058) |
| **依赖** | 无 |

**描述**：

扩展 Metal VideoUniforms 结构体和 Swift 侧 VideoFilterConfig，为后续滤波器提供参数通道。

**涉及文件**：
- `Chiaki/Core/Video/VideoShaders.txt` — 扩展 `VideoUniforms` struct
- `Chiaki/Core/Video/MetalVideoRenderer.swift` — Swift 侧 uniform 更新逻辑
- `Chiaki/Core/Video/VideoFilterConfig.swift` — **新建** 滤波配置模型

**实现要点**：
1. 在 `VideoUniforms` 新增 5 个字段：`upscaleFilter`, `casStrength`, `debandEnabled`, `debandThreshold`, `debandGrain` + 对齐填充
2. 确保 struct 总大小 16 字节对齐（160 bytes）
3. 定义 `VideoFilterConfig` Swift 结构体，包含默认值
4. 在 `MetalVideoRenderer` 新增 `setFilterConfig(_:)` 方法
5. 在 `updateUniforms()` 中映射 FilterConfig → VideoUniforms 新字段
6. 验证 CPU/GPU struct 大小一致性

**验收标准**：
- CPU `MemoryLayout<VideoUniforms>.size` == GPU struct size
- 新字段默认值匹配 Default 预设（bicubic, CAS 0.5, deband on）
- 全平台编译通过

---

### T-237: Bicubic Catmull-Rom 9-tap 上采样实现 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-158, AC-159, AC-168 |
| **优先级** | P0 (核心画质) |
| **TDD** | 🔴 先测试 (UT-055) |
| **依赖** | T-236 |

**描述**：

在 Metal fragment shader 中实现 Bicubic Catmull-Rom 9-tap 上采样函数，替换 Y 通道的双线性采样。

**涉及文件**：
- `Chiaki/Core/Video/VideoShaders.txt` — 新增 `sampleBicubicCatmullRom()` 函数 + 修改 fragment shader

**实现要点**：
1. 实现 `sampleBicubicCatmullRom(tex, sampler, uv, texSize)` 函数（Horner 形式权重计算 + 3x3 bilinear 优化）
2. 在 `videoBiplanarFragmentShader` 中通过 `uniforms.upscaleFilter` 条件分支选择采样方式
3. Y 通道：`upscaleFilter==1` 时使用 bicubic，`==0` 时保持 bilinear
4. UV 通道：始终保持 bilinear（AC-158 要求）
5. 在 `videoBGRAFragmentShader` 中同样添加条件分支（BGRA 整体使用 bicubic）
6. 保持 `clamp_to_edge` 地址模式，确保纹理边缘无越界

**验收标准**：
- Bicubic 采样在整数纹素位置输出与原值一致
- 权重和 ≈ 1.0（误差 < 1e-5）
- 纹理边缘无伪影
- 零拷贝架构不变（无中间纹理分配）

---

### T-238: CAS 自适应锐化实现 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-160, AC-161 |
| **优先级** | P0 (核心画质) |
| **TDD** | 🔴 先测试 (UT-056) |
| **依赖** | T-236 |

**描述**：

实现 AMD FidelityFX CAS 算法的 Metal 移植，在 YUV→RGB 转换后对 RGB 值进行自适应锐化。

**涉及文件**：
- `Chiaki/Core/Video/VideoShaders.txt` — 新增 `contrastAdaptiveSharpening()` 函数

**实现要点**：
1. 实现 `contrastAdaptiveSharpening(center, tex, sampler, uv, texSize, strength)` 函数
2. 3x3 邻域采样（9 taps），使用 BT.709 亮度计算对比度
3. 软 min/max 计算自适应锐化幅度（amp）
4. `strength=0.0` 时完全 bypass（直接返回 center）
5. 在 SDR 路径：CAS 在 contrast/brightness/saturation 调整之后执行
6. 在 HDR 路径：CAS 在 tone mapping / EDR 之后执行（值域已归一化或 EDR）
7. 使用 `saturate()` 防止 SDR 越界；HDR 路径使用 `max(0.0)` 保留 EDR

**验收标准**：
- 纯色区域输出 ≈ 输入
- 高对比度边缘增强但无光晕
- strength=0 时输出 == 输入
- HDR 路径无 NaN/Inf

---

### T-239: 去色带 + 有序抖动实现 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-162, AC-163 |
| **优先级** | P0 (画质) |
| **TDD** | 🟡 先骨架后测试 (UT-057) |
| **依赖** | T-236 |

**描述**：

实现去色带（随机邻域阈值平滑）和 Bayer 4x4 有序抖动，减少串流压缩色带伪影。

**涉及文件**：
- `Chiaki/Core/Video/VideoShaders.txt` — 新增 `deband()` 函数 + Bayer 矩阵常量

**实现要点**：
1. 定义 `bayer4x4[16]` 常量数组
2. 实现 `deband(color, tex, sampler, uv, texSize, screenPos, threshold, grain)` 函数
3. 随机方向 4-tap 邻域采样（16 pixel 半径）
4. 差值 < threshold 时混合 50% 平均值
5. 最后叠加 Bayer 抖动（grain 强度）
6. `debandEnabled==0` 时完全 bypass
7. HDR 路径：threshold 和 grain 乘以 edrHeadroom（EDR 值域更大）
8. 在 CAS 之后、`return` 之前执行

**验收标准**：
- 线性渐变输入色带减轻
- 高频纹理不被误平滑
- disabled 时输出 == 输入
- Bayer 矩阵 16 个值覆盖 [0, 15/16]

---

### T-240: 视频预设→渲染参数映射 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-164, AC-165 |
| **优先级** | P1 |
| **TDD** | 🟡 先骨架后测试 (UT-058) |
| **依赖** | T-237, T-238, T-239 |

**描述**：

将 `VideoPreset` 枚举（Performance / Default / High Quality）接入真实渲染参数，替换现有 TODO。

**涉及文件**：
- `Chiaki/Features/Streaming/StreamingViewModel.swift` — 修改 `setVideoPreset()`
- `Chiaki/Core/Video/VideoFilterConfig.swift` — 新增 `static` 预设工厂方法
- `Chiaki/Core/Storage/SettingsStore.swift` — 持久化预设选择

**实现要点**：
1. 在 `VideoFilterConfig` 添加三个静态属性：`.performance`, `.default`, `.highQuality`
2. Performance: bilinear + 无锐化 + 无去色带
3. Default: bicubic + CAS 0.5 + 去色带（threshold 0.004, grain 0.003）
4. High Quality: bicubic + CAS 0.7 + 去色带（threshold 0.004, grain 0.004）
5. 在 `StreamingViewModel.setVideoPreset()` 调用 `renderer.setFilterConfig(preset.filterConfig)`
6. 预设切换立即生效（下一帧 uniforms 更新）

**验收标准**：
- 三个预设参数正确映射
- 切换预设下一帧立即反映
- 预设选择可持久化

---

### T-241: 渲染诊断指标扩展 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-166 |
| **优先级** | P1 |
| **TDD** | 🟡 先骨架后测试 (UT-059) |
| **依赖** | T-240 |

**描述**：

在 StreamStatistics 和 StreamingOverlay 中新增渲染管线诊断指标。

**涉及文件**：
- `Chiaki/Core/Streaming/StreamStatistics.swift` — 新增诊断属性
- `Chiaki/Features/Streaming/StreamingOverlay.swift` — 新增诊断显示行
- `Chiaki/Core/Video/MetalVideoRenderer.swift` — 上报 drop/repeat/filter 信息

**实现要点**：
1. 在 `StreamStatistics` 新增：`renderDeltaMs`, `frameDropCount`, `frameRepeatCount`, `presentInterval`, `currentFilter`
2. 在 `MetalVideoRenderer.render()` 中统计 drop/repeat 计数
3. 利用已有 `onRenderTimeRecorded` 回调上报 renderDeltaMs
4. 在 StreamingOverlay 统计面板新增一行：`Filter: bicubic | Render: 0.8ms | Drop: 0 | Repeat: 2 | PresentΔ: 16.7ms`

**验收标准**：
- 所有指标在串流期间正确更新
- currentFilter 与实际 upscaleFilter 设置一致
- Overlay 显示不影响性能

---

### T-242: 全平台验证 + 性能基准 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-041, AC-167, AC-169 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (E2E-014) |
| **依赖** | T-241 |

**描述**：

三平台编译验证、SDR/HDR 路径覆盖、性能基准测量。

**涉及文件**：
- 无新文件，全项目编译+测试

**实现要点**：
1. macOS / iOS / tvOS 三平台 `xcodebuild` 编译验证
2. SDR (BT.709) + HDR (BT.2020 PQ) 两路径均测试
3. 各预设（Performance / Default / HQ）切换验证
4. 通过 Overlay 诊断面板确认 GPU 渲染耗时 ≤ 2ms
5. BUG-016 验证：快速运动场景清晰度
6. BUG-017 验证：macOS 窗口最大化后清晰度
7. 运行 UT-055~059, IT-019 全部测试

**验收标准**：
- 三平台编译通过
- SDR/HDR 双路径无崩溃、无伪影
- Default 预设 GPU 耗时 ≤ 2ms（1080p→4K, Apple Silicon）
- BUG-016, BUG-017 画质改善可感知

---

## M19 — libplacebo 渲染后端集成

> **功能**: F-042 | **来源**: INS-088~INS-091
> **目标**: 集成 libplacebo 作为默认渲染后端（Phase 1 MoltenVK 路径），实现后端切换机制，F-041 Metal 原生 shader 保留为兼容模式

### 依赖关系

```
T-243 libplacebo + MoltenVK 构建系统集成 (P0, 🟡)
  │
  └── T-244 C/Swift 桥接层 (P0, 🟡)
        │
        └── T-245 PlaceboVideoRenderer 核心实现 (P0, 🔴 TDD) ✅
              │
              ├── T-246 零拷贝纹理导入 + 渲染管线 (P0, 🔴 TDD) ⏳
              │
              └── T-247 渲染预设映射 + HDR 支持 (P1, 🔴 TDD)
                    │
                    └── T-248 后端切换机制 + 设置页 (P1, 🟡)
                          │
                          └── T-249 诊断接口 + Shader 缓存 (P1, 🟡)
                                │
                                └── T-250 全平台验证 + 性能基准 (P1, 🟢)
```

---

### T-243: libplacebo + MoltenVK 构建系统集成 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-170, AC-171, AC-172 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟡 先骨架后测试 (UT-060) |
| **依赖** | 无 |

**描述**:

将 libplacebo 和 MoltenVK 作为预编译动态 framework 集成到 Xcode 项目，支持 macOS (arm64/x86_64) 和 iOS (arm64) 双平台。

**涉及文件**:
- `scripts/build-libplacebo.sh` — **新建** 交叉编译脚本
- `Chiaki.xcodeproj/project.pbxproj` — 添加 framework 引用和 embed 配置
- `Frameworks/libplacebo.xcframework/` — **新建** 预编译 framework
- `Frameworks/MoltenVK.xcframework/` — **新建** 预编译 framework

**实现要点**:
1. 编写 Meson 交叉编译配置（macOS arm64/x86_64、iOS arm64）
2. 编译 libplacebo with Vulkan backend，链接 SPIRV-Cross 和 shaderc
3. 编译 MoltenVK（或使用 LunarG Vulkan SDK 预编译版）
4. 打包为 xcframework（`xcodebuild -create-xcframework`）
5. 配置 Xcode：Embed & Sign 动态 framework（LGPL 合规）
6. 验证 macOS + iOS 双平台编译通过
7. 在 Bridging Header 中 `#include <libplacebo/log.h>` 验证头文件可用

**验收标准**:
- macOS (arm64/x86_64) 和 iOS (arm64) 编译通过
- libplacebo 以动态 framework 链接（`otool -L` 确认）
- `pl_log_create` 等符号可从 Swift 通过桥接头访问
- 无静态链接 libplacebo 的情况（LGPL 合规）

---

### T-244: C/Swift 桥接层 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-173 |
| **优先级** | P0 (阻塞) |
| **TDD** | 🟡 先骨架后测试 |
| **依赖** | T-243 |

**描述**:

建立 libplacebo C API 到 Swift 的桥接层，封装不透明指针管理和类型转换。

**涉及文件**:
- `Chiaki/Core/Video/Placebo/PlaceboBridge.h` — **新建** 桥接头
- `Chiaki/Core/Video/Placebo/PlaceboContext.m` — **新建** ObjC 层初始化/销毁封装
- `Chiaki/Core/Video/Placebo/PlaceboTypes.swift` — **新建** Swift 类型映射
- `Chiaki-Bridging-Header.h` — 添加 `#import "PlaceboBridge.h"`

**实现要点**:
1. `PlaceboBridge.h`：暴露 `libplacebo/log.h`, `vulkan.h`, `renderer.h`, `swapchain.h`, `cache.h` 头文件
2. `PlaceboContext`：封装 `pl_log_create`/`pl_vulkan_create`/`pl_renderer_create` 生命周期管理
3. 提供 Swift 友好的初始化/销毁接口（返回 `OpaquePointer?`）
4. `PlaceboTypes.swift`：定义 `PlaceboRenderParams`、`PlaceboDebandParams` 等 Swift 映射类型
5. 封装 MoltenVK VkInstance 创建（含 `VK_EXT_metal_objects` 扩展请求）
6. 错误处理：libplacebo/Vulkan 初始化失败时返回 nil，不崩溃

**验收标准**:
- 从 Swift 可调用 `PlaceboContext.createLog()` → 非 nil OpaquePointer
- `PlaceboContext.createVulkanDevice()` 在有 GPU 的设备上成功
- 所有 OpaquePointer 在 deinit 时正确释放（无内存泄漏）
- 编译无警告

---

### T-245: PlaceboVideoRenderer 核心实现 ✅

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-173, AC-176 |
| **优先级** | P0 |
| **TDD** | 🔴 先测试 (UT-061) |
| **依赖** | T-244 |

**描述**:

实现 `PlaceboVideoRenderer` 类，完整符合 `VideoRenderer` 协议，使用 libplacebo 渲染器输出到 CAMetalLayer。

**涉及文件**:
- `Chiaki/Core/Video/PlaceboVideoRenderer.swift` — **新建** 主实现
- `Chiaki/Core/Video/VideoRenderer.swift` — 不修改（协议已满足）

**实现要点**:
1. `init?()`: 创建 pl_log → pl_vulkan (MoltenVK) → pl_renderer → pl_swapchain
2. 实现 `VideoRenderer` 协议全部属性和方法（displayMode, zoomFactor, hdrConfiguration 等）
3. `mtkView` setter 中从 MTKView 底层 CAMetalLayer 创建 `VkSurfaceKHR` → `pl_swapchain`
4. `render(to:descriptor:)`: 调用 `pl_swapchain_start_frame` → `pl_render_image` → `pl_swapchain_swap_buffers`
5. 线程安全：帧提交和渲染通过锁或串行队列保护
6. `deinit`: 按逆序销毁所有 libplacebo 对象

**验收标准**:
- `PlaceboVideoRenderer()` 初始化成功（GPU 可用时）
- 符合 `VideoRenderer` 协议，可赋值给 `any VideoRenderer`
- 所有默认属性值与 `MetalVideoRenderer` 一致
- 无内存泄漏（Instruments Leaks 验证）

---

### T-246: 零拷贝纹理导入 + 渲染管线 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-174, AC-175, AC-177 |
| **优先级** | P0 |
| **TDD** | 🔴 先测试 (UT-062, IT-020) |
| **依赖** | T-245 |

**描述**:

实现 CVPixelBuffer → IOSurface → VkImage 零拷贝纹理导入路径，完成 `submitFrame` 和 `pl_render_image` 完整管线。

**涉及文件**:
- `Chiaki/Core/Video/PlaceboVideoRenderer.swift` — 扩展帧提交和渲染逻辑
- `Chiaki/Core/Video/Placebo/PlaceboContext.m` — 纹理导入 C 层封装

**实现要点**:
1. `submitFrame`: CVPixelBuffer → `CVPixelBufferGetIOSurface` → IOSurfaceRef
2. IOSurface → VkImage: 通过 `VK_EXT_metal_objects` + `VkImportMetalIOSurfaceInfoEXT`
3. VkImage → `pl_tex`: 通过 `pl_vulkan_wrap` 封装为 libplacebo 纹理
4. 构建 `pl_frame`: Y plane (planes[0]) + UV plane (planes[1])，标注色彩空间
5. NV12 (8-bit) 和 P010 (10-bit HDR) 双格式支持
6. SDR: `PL_COLOR_PRIM_BT_709` + `PL_COLOR_TRC_BT_1886`
7. HDR: `PL_COLOR_PRIM_BT_2020` + `PL_COLOR_TRC_PQ` + HDR 静态元数据
8. IOSurface 引用计数管理：在 render 完成回调中释放

**验收标准**:
- NV12 帧提交后 hasFrame=true，frameSize 正确
- P010 帧提交后 HDR 色彩空间正确设置
- 无 CPU 端像素拷贝（IOSurface 零拷贝路径）
- 60fps 连续 1000 帧无内存泄漏

---

### T-247: 渲染预设映射 + HDR 支持 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-181, AC-182, AC-183, AC-177 |
| **优先级** | P1 |
| **TDD** | 🔴 先测试 (UT-063, IT-022) |
| **依赖** | T-246 |

**描述**:

实现三级视频预设到 libplacebo 渲染参数的映射，以及完整 HDR 色调映射配置。

**涉及文件**:
- `Chiaki/Core/Video/PlaceboVideoRenderer.swift` — 预设映射 + HDR 配置
- `Chiaki/Core/Video/Placebo/PlaceboTypes.swift` — 渲染参数映射类型

**实现要点**:
1. `setFilterConfig`: 根据 VideoFilterConfig 选择 libplacebo 预设
   - Performance → `pl_render_fast_params`（最小开销）
   - Default → `pl_render_default_params` + `pl_deband_default_params`
   - High Quality → `pl_render_high_quality_params` + `ewa_lanczossharp` 上采样
2. HDR 色调映射配置：
   - `pl_color_map_params`: 使用默认色调映射（动态场景检测）
   - EDR headroom 注入：`dst_csp.hdr.max_luma = edrHeadroom * 203.0`
   - SDR 直通：src/dst 均 BT.709 时跳过色调映射
3. `setBrightness/setContrast/setSaturation`: 映射到 `pl_color_adjustment`
4. `setColorSpace`: 映射到 `pl_color_space.primaries`

**验收标准**:
- Performance/Default/HQ 三预设参数映射正确
- HDR PQ 输入 + SDR 输出：色调映射后亮度合理
- EDR headroom 变化时 libplacebo 目标亮度更新
- SDR→SDR 路径无不必要的色调映射

---

### T-248: 后端切换机制 + 设置页 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-178, AC-179, AC-180, AC-184, AC-185 |
| **优先级** | P1 |
| **TDD** | 🟡 先骨架后测试 (UT-064, IT-021) |
| **依赖** | T-247 |

**描述**:

实现渲染后端切换机制（RenderBackend 枚举 + StreamingViewModel 工厂方法）和设置页 UI。

**涉及文件**:
- `Chiaki/Domain/Models/StreamSettings.swift` — 新增 `RenderBackend` 枚举和 `renderBackend` 属性
- `Chiaki/Features/Streaming/StreamingViewModel.swift` — 后端工厂方法 + graceful fallback
- `Chiaki/Features/Settings/VideoSettingsView.swift` — 新增后端选择 Picker
- `Chiaki/Core/Video/VideoRenderer.swift` — 不修改

**实现要点**:
1. `RenderBackend` 枚举：`.metalNative` / `.libplacebo`，Codable，默认 `.libplacebo`
2. `StreamSettings.renderBackend` 属性 + CodingKeys
3. `StreamingViewModel.createRenderer()`: 根据 renderBackend 创建对应渲染器
4. Graceful fallback: PlaceboVideoRenderer() 返回 nil → 自动回退 MetalVideoRenderer
5. Fallback 时记录 Logger.video.warning 日志
6. 设置页 Video 分区新增 "Render Backend" Picker
7. Picker 选项显示 displayName + 简短说明

**验收标准**:
- 默认 renderBackend = .libplacebo
- 切换后端后重启串流使用新后端
- libplacebo 不可用时自动回退到 Metal Native，无崩溃
- 设置持久化（退出重启后保留选择）

---

### T-249: 诊断接口 + Shader 缓存 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-186, AC-187, AC-190 |
| **优先级** | P1 |
| **TDD** | 🟡 先骨架后测试 (UT-065, UT-066) |
| **依赖** | T-248 |

**描述**:

实现 PlaceboVideoRenderer 的诊断统计接口和 libplacebo shader 缓存持久化。

**涉及文件**:
- `Chiaki/Core/Video/PlaceboVideoRenderer.swift` — 统计属性 + 缓存管理
- `Chiaki/Features/Streaming/StreamingOverlay.swift` — 显示后端名称
- `Chiaki/Core/Streaming/StreamStatsManager.swift` — 适配 PlaceboVideoRenderer

**实现要点**:
1. 统计属性：frameCount、droppedFrameCount、frameRepeatCount、presentInterval
2. 在 render 完成回调中更新计数器和时间戳
3. `filterName` 返回 `"libplacebo"` 作为后端标识
4. StreamingOverlay RenderDiagnosticsItem 增加 "Backend:" 显示
5. StreamStatsManager 适配：检测 PlaceboVideoRenderer 类型
6. Shader 缓存：`pl_cache_create` + `pl_gpu_set_cache`
7. 缓存路径：`~/Library/Caches/{bundleId}/placebo_cache.bin`
8. 应用退出时 `pl_cache_save_file`，启动时 `pl_cache_load_file`

**验收标准**:
- Overlay 正确显示 "Backend: libplacebo" 或 "Backend: Metal Native"
- frameCount 在串流期间递增
- Shader 缓存文件写入/读取正确
- 第二次启动串流时 shader 编译时间显著减少

---

### T-250: 全平台验证 + 性能基准 ⏳

| 属性 | 内容 |
|------|------|
| **关联** | F-042, AC-190, AC-191 |
| **优先级** | P1 |
| **TDD** | 🟢 可选 (E2E-015, E2E-016) |
| **依赖** | T-249 |

**描述**:

三平台编译验证、libplacebo 画质评估、性能基准测量、后端切换用户流程验证。

**涉及文件**:
- 无新文件，全项目编译+测试

**实现要点**:
1. macOS / iOS 双平台 `xcodebuild` 编译验证（tvOS 视 MoltenVK 支持情况）
2. libplacebo Default 预设 vs F-041 Metal Native Default 画质对比
3. libplacebo HQ 预设 vs chiaki-ng 默认配置画质对比
4. 帧延迟基准：libplacebo 路径 ≤ 3ms（1080p→4K, Apple Silicon）
5. 后端切换 E2E 流程：设置页选择 → 串流 → Overlay 确认
6. Graceful fallback 验证：模拟 libplacebo 不可用场景
7. 内存基准：libplacebo 渲染期间内存占用合理
8. 运行 UT-060~066, IT-020~022 全部测试

**验收标准**:
- macOS + iOS 编译通过
- libplacebo HQ 预设画质 ≥ chiaki-ng 默认（主观评估）
- 帧延迟 ≤ 3ms（1080p→4K, Apple Silicon）
- 后端切换流程顺畅，fallback 路径无崩溃
- 全部单元测试和集成测试通过

---

## 任务汇总

| 里程碑 | 任务数 | 完成率 | 状态 |
|--------|--------|--------|------|
| M11 Beta 1 冲刺 | 35 | 97% | ✅ 已归档 |
| M12 HDR/渲染/MVVM | 24 | 100% | ✅ 已归档 |
| M13 HDR落地/MainActor/日志 | 23 | 100% | ✅ 已归档 |
| M14 macOS 设置侧边栏 | 4 | 100% | ✅ 已归档 |
| M15 UI/UX优化/Bridge安全 | 18 | 100% | ✅ 已归档 |
| M16 iPhone 串流横屏锁定 | 2 | 100% | ✅ 已完成 |
| M17 控制器架构分层重构 | 7 | 100% | ✅ 已完成 |
| M18 Metal 视频滤波管线 | 7 | 100% | ✅ 已完成 |
| **M19 libplacebo 渲染后端** | **8** | **0%** | ⏳ 待开始 |
| Bug 修复 | 12 | 100% | ✅ |
| **总计** | **140** | — | — |

---

## 下一步

1. T-115 App Icon 资产准备仍待设计师交付
2. **M19 T-243 开始实施**：libplacebo + MoltenVK 构建系统集成
3. M17/M18 可考虑归档（已全部完成）

---

*文档由 `/devdocs-sync` 更新 (2026-02-10): M17/M18 全部标记完成，M19 新增*
