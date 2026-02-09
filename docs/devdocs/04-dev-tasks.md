# Chiaki-ng Apple 原生客户端 - 开发任务

> **状态更新**: 2026-02-09
> **当前里程碑**: M16 — iPhone 串流横屏锁定
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

## 任务汇总

| 里程碑 | 任务数 | 完成率 | 状态 |
|--------|--------|--------|------|
| M11 Beta 1 冲刺 | 35 | 97% | ✅ 已归档 |
| M12 HDR/渲染/MVVM | 24 | 100% | ✅ 已归档 |
| M13 HDR落地/MainActor/日志 | 23 | 100% | ✅ 已归档 |
| M14 macOS 设置侧边栏 | 4 | 100% | ✅ 已归档 |
| M15 UI/UX优化/Bridge安全 | 18 | 100% | ✅ 已归档 |
| M16 iPhone 串流横屏锁定 | 2 | 100% | ✅ 已完成 |
| Bug 修复 | 9 | 100% | ✅ |
| **总计** | **115** | — | ✅ |

---

## 下一步

1. T-115 App Icon 资产准备仍待设计师交付
2. 真机验证 BUG-011、BUG-012、BUG-013、BUG-014 修复

---

*文档由 `/devdocs-bugfix` 更新 (2026-02-09)*
