# Chiaki-ng Apple 原生客户端 - 开发任务

> **状态更新**: 2026-02-10
> **当前里程碑**: M17 — 控制器架构分层重构
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

## M17 — 控制器架构分层重构

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

### T-229: 定义 ControllerInputProvider + ControllerFeedbackOutput 协议 ⏳

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

### T-230: 实现 GameControllerProvider ⏳

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

### T-231: 重构 DualSenseHIDManager → DualSenseHIDProvider ⏳

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

### T-232: 实现 ControllerOrchestrator ⏳

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

### T-233: StreamingViewModel 集成 Orchestrator ⏳

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

### T-234: 新增 DualShock4HIDProvider ⏳

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

### T-235: 清理旧代码 + 全平台验证 ⏳

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

## 任务汇总

| 里程碑 | 任务数 | 完成率 | 状态 |
|--------|--------|--------|------|
| M11 Beta 1 冲刺 | 35 | 97% | ✅ 已归档 |
| M12 HDR/渲染/MVVM | 24 | 100% | ✅ 已归档 |
| M13 HDR落地/MainActor/日志 | 23 | 100% | ✅ 已归档 |
| M14 macOS 设置侧边栏 | 4 | 100% | ✅ 已归档 |
| M15 UI/UX优化/Bridge安全 | 18 | 100% | ✅ 已归档 |
| M16 iPhone 串流横屏锁定 | 2 | 100% | ✅ 已完成 |
| **M17 控制器架构分层重构** | **7** | **0%** | ⏳ 进行中 |
| Bug 修复 | 11 | 100% | ✅ |
| **总计** | **124** | — | — |

---

## 下一步

1. T-115 App Icon 资产准备仍待设计师交付
2. 真机验证 BUG-011~BUG-019 修复
3. **M17 T-229 开始实施**：定义 Provider 协议

---

*文档由 `/devdocs-feature` 更新 (2026-02-10)*
