# Bug 修复日志

## BUG-001: HDR 设置失效，视频输出仍为 SDR

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-001 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-03 |
| **状态** | ✅ 已修复 |

### 问题描述

在设置中开启 HDR 并选择 BT.2020 色彩空间后，视频输出依然没有 HDR 效果（峰值亮度受限，色彩暗淡）。

### 复现步骤

1. 连接支持 HDR 的 PS5。
2. 在 Chiaki Apple 设置中开启 HDR 选项。
3. 进入流媒体播放界面。
4. 观察视频画面，发现亮点不亮，整体色彩处于 SDR 范围。

### 根因分析

1. **解码位深不足**：`VideoToolboxDecoder` 硬编码使用 8 位像素格式 (`kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`)，导致 HDR10 的 10 位信息丢失。
2. **渲染表面不支持 EDR**：`MTKView` 使用 8 位格式 (`.bgra8Unorm`)，且未开启扩展动态范围 (EDR) 支持。
3. **着色器处理缺失**：着色器在 YUV 转 RGB 后直接进行了 `clamp(0, 1)` 处理，且缺少 PQ EOTF 转换，导致 BT.2020 信号被错误地当作 SDR 渲染。

### 解决方案

1. **更新解码器**：根据 codec 是否为 HDR 动态选择 10 位像素格式 (`x420`)。
2. **升级渲染表面**：在开启 HDR 时，将 `MTKView` 切换为 16 位浮点格式 (`.rgba16Float` 或 `.rgb10a2Unorm`)，并配置 `CAMetalLayer` 开启 `wantsExtendedDynamicRangeContent`。
3. **优化着色器**：实现 PQ EOTF 转换逻辑，移除针对 HDR 内容的强制裁剪，并按 100 nits = 1.0 的比例缩放输出到 EDR 范围。

### 回归测试

- 手动验证：开启 HDR 后画面亮度与色彩正常。
- 编译验证：Metal 着色器编译通过。

---

## BUG-002: RegistrationView 缺少 hostManager 参数导致编译失败

| 属性 | 内容 |
|------|------|
| **发现来源** | 编译失败 |
| **关联功能** | F-027 (UI 层 MVVM 重构) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-04 |
| **状态** | ✅ 已修复 |

### 问题描述

M12 重构中 `RegistrationView` 的初始化签名从 `init(initialAddress:)` 变更为 `init(hostManager:initialAddress:)`，但 `HostListView` 中的调用未同步更新，导致编译失败。

### 复现步骤

1. 执行 `xcodebuild -scheme Chiaki build`
2. 编译失败，错误信息：`missing argument for parameter 'hostManager' in call`
3. 错误位置：`HostListView.swift:75`

### 根因分析

在 F-027 MVVM 重构过程中，`RegistrationView` 改为通过构造函数注入 `HostManager` 依赖（替代直接使用 `HostManager.shared`），但遗漏了更新 `HostListView` 中的调用点。

### 解决方案

1. 将 `HostListViewModel.hostManager` 从 `private` 改为 `internal`，使视图可以访问
2. 更新 `HostListView` 中 `RegistrationView` 的调用，传入 `viewModel.hostManager`

### 回归测试

- 编译验证：`xcodebuild build` 成功
- 关联测试：UT-047 (RegistrationView 初始化测试)

### 经验教训

重构 API 签名时，应使用 IDE 的"Find Usages"功能确保所有调用点都已更新，或在 CI 中启用增量编译验证。

---

## BUG-003: nonisolated(unsafe) 在 @Observable 类中产生编译警告

| 属性 | 内容 |
|------|------|
| **发现来源** | 编译警告 |
| **关联功能** | F-025 (HDR 渲染管线优化) |
| **Issue** | N/A |
| **严重程度** | P2 |
| **修复日期** | 2026-02-04 |
| **状态** | ✅ 已修复 |

### 问题描述

`EDRHeadroomMonitor` 类中使用 `nonisolated(unsafe)` 标注的属性产生编译警告：`'nonisolated(unsafe)' has no effect on property, consider using 'nonisolated'`。

### 复现步骤

1. 执行 `xcodebuild -scheme Chiaki build`
2. 观察到警告：
   - `EDRHeadroomMonitor.swift:40:5: warning: 'nonisolated(unsafe)' has no effect on property 'displayLink'`
   - `EDRHeadroomMonitor.swift:41:5: warning: 'nonisolated(unsafe)' has no effect on property 'observation'`

### 根因分析

Swift 6.2 中，`@Observable` 宏与 `nonisolated(unsafe)` 存在兼容性问题：
1. `nonisolated(unsafe)` 在 `@Observable @MainActor` 类的存储属性上被认为"无效"
2. 直接使用 `nonisolated` 会导致错误：`'nonisolated' cannot be applied to mutable stored properties`
3. 移除标注会导致 `deinit` 无法访问这些属性（`deinit` 是 nonisolated 上下文）

### 解决方案

将需要在 `deinit` 中清理的资源（`CADisplayLink`、`NSKeyValueObservation`）移到独立的辅助类 `EDRMonitorResources` 中：

1. 创建 `private final class EDRMonitorResources: @unchecked Sendable`
2. 在辅助类的 `deinit` 中执行资源清理
3. `EDRHeadroomMonitor` 持有 `let resources = EDRMonitorResources()`

这种模式避免了 `@Observable` 宏与 `nonisolated` 的冲突。

### 回归测试

- 编译验证：`xcodebuild build` 成功且无警告
- 功能验证：EDR headroom 监控功能正常

### 经验教训

在 `@Observable @MainActor` 类中需要 `deinit` 清理的资源，应使用独立的辅助类持有，而不是直接使用 `nonisolated(unsafe)` 标注。

---

## BUG-005: 音频播放异常（咯哒声/杂音）

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-001 (核心流媒体) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-04 |
| **状态** | ✅ 已修复 |

### 问题描述

音频播放异常，有声音但不正常，类似"咯哒"声或杂音。这是典型的音频数据格式错误症状。

### 复现步骤

1. 连接 PS5 主机
2. 进入串流播放界面
3. 观察音频输出，听到"咯哒"声而非正常游戏音频

### 根因分析

Swift 端直接将 Opus 压缩数据当作 PCM Int16 传给 AudioPlayer，未经 Opus 解码。

**数据流对比**：

| 客户端 | 数据流 |
|--------|--------|
| Qt/Android | audioreceiver → OpusDecoder.frame_cb → 解码 PCM → AudioPlayer |
| **Swift (当前)** | audioreceiver → audioFrameCallback → 原始 Opus 数据 → AudioPlayer ❌ |

**关键代码分析**：

1. `audioreceiver.c:123` - `audio_sink.frame_cb(buf, buf_size, ...)` 传递的是 Opus 压缩数据
2. `ChiakiSession.swift:781` - `audioFrameCallback` 直接将 buf 作为 Int16 PCM 处理
3. `AudioPlayer.swift:173` - `receiveAudio()` 期望接收 Int16 PCM，但实际收到 Opus 数据

**对比 Qt 客户端** (`streamsession.cpp:356-358`):
```cpp
chiaki_opus_decoder_set_cb(&opus_decoder, AudioSettingsCb, AudioFrameCb, this);
chiaki_opus_decoder_get_sink(&opus_decoder, &audio_sink);
chiaki_session_set_audio_sink(session, &audio_sink);
```

Qt 客户端通过 `chiaki_opus_decoder_get_sink()` 获取包装后的 sink，Opus 解码器在 `frame_cb` 中先解码再调用用户回调。

### 解决方案

集成 Opus 解码器到 Swift 端，方案如下：

**方案 A: 复用 C 层 OpusDecoder** (推荐)
- 在 Swift 端初始化 `ChiakiOpusDecoder`
- 使用 `chiaki_opus_decoder_get_sink()` 获取解码 sink
- 设置回调接收解码后的 PCM 数据

**方案 B: Swift 原生 Opus 解码**
- 集成 Swift Opus 库 (如 Opus-iOS)
- 在 `audioFrameCallback` 中进行解码
- 解码后传递给 AudioPlayer

**选择方案 A**：复用现有 C 层实现，减少维护成本。

### 任务拆分

详见 `04-dev-tasks.md` T-185~T-188

### 回归测试

- 手动验证：音频正常播放无杂音 ✅
- 待新增测试：UT-048 (OpusDecoder 集成测试)
- 关联 commit：`12e570c`, `8999532`

### 修改文件清单

1. `Chiaki/Core/Audio/OpusDecoderBridge.swift` (新建) - Opus 解码器桥接类
2. `Chiaki/Core/Bridge/ChiakiSession.swift` (修改) - 集成 Opus 解码器

### 经验教训

1. **理解 API 返回值语义**：`opus_decode` 返回的是"帧数"（per-channel samples），而非"总样本数"。在对接不同层级的 API 时，必须仔细确认参数含义。
2. **症状分析**：
   - "咯哒声" = 播放压缩数据（未解码）
   - "颤音" = 数据量错误（只播放一半）
   - 正常 = 解码正确 + 数据量正确

---

## BUG-004: 唤醒主机后首次连接失败

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-003 (串流会话管理) |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-04 |
| **状态** | ✅ 已修复 |

### 问题描述

在主机列表唤醒 PS5 后，点击进入串流界面会出现 error。返回后再次连接则成功。

### 复现步骤

1. 主机处于待机状态（standby）
2. 在主机列表点击唤醒
3. 唤醒成功后，点击进入串流
4. 观察到 error 提示
5. 返回主机列表，再次点击进入串流
6. 连接成功

### 根因分析

`StreamingViewModel.wakeAndConnect()` 唤醒主机后，轮询 `HostManager.shared.host(byId:)` 检查主机状态。但：

1. 如果发现服务（DiscoveryService）没有运行，主机状态不会更新
2. 等待超时后显示错误
3. 用户返回主界面时，可能触发了发现服务启动
4. 再次连接时主机已被发现，状态为 online，连接成功

### 解决方案

在 `wakeAndConnect()` 方法开始时检查并启动发现服务：

1. 检查 `HostManager.shared.isDiscovering` 状态
2. 如果发现服务未运行，调用 `startDiscovery()` 启动
3. 等待 200ms 让发现服务初始化
4. 然后发送唤醒信号并开始轮询

修改文件：`Chiaki/Features/Streaming/StreamingViewModel.swift`

### 回归测试

- 手动验证：唤醒主机后首次连接成功
- 关联 commit：T-184

---

## BUG-006: 进入串流后 PS5 立即断开连接

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-001 (核心流媒体) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-04 |
| **状态** | ✅ 已修复 |

### 问题描述

进入串流界面后，PS5 很快显示断开连接（通常在 5 秒内）。Chiaki Apple 端画面停留在最后一帧，但 PS5 电视显示连接已断开。

### 复现步骤

1. 从主机列表进入串流界面
2. 成功看到游戏画面
3. 约 5 秒后，PS5 显示客户端已断开
4. Chiaki Apple 画面冻结在最后一帧

### 根因分析

PS5 期望客户端定期发送控制器状态作为心跳信号，以确认客户端仍然活跃。Chiaki Apple 仅在用户输入时发送控制器状态，导致 PS5 认为客户端已断开连接。

**对比 Qt 客户端** (`streamsession.cpp:19,415`):
```cpp
#define SETSU_UPDATE_INTERVAL_MS 4

// Timer 每 4ms 调用一次
connect(&setsu_update_timer, &QTimer::timeout, this, [this]{ SendFeedbackState(); });
setsu_update_timer.start(SETSU_UPDATE_INTERVAL_MS);
```

Qt 客户端使用 4ms 定时器定期发送控制器状态，即使没有输入变化。这作为心跳信号保持连接活跃。

**Chiaki Apple (修复前)**:
- 仅在 `handleInput()` 或 `sendControllerInput()` 被调用时发送控制器状态
- 没有定时器机制发送周期性心跳
- PS5 在未收到心跳后超时断开连接

### 解决方案

在 `StreamingViewModel` 中添加周期性反馈定时器：

1. 新增 `feedbackTimer` 属性
2. 在进入 `streaming` 状态时启动定时器 (`startFeedbackTimer()`)
3. 每 8ms 发送当前控制器状态（比 Qt 的 4ms 略长，减少开销同时保持连接）
4. 在断开连接、错误或退出时停止定时器 (`stopFeedbackTimer()`)

修改文件：`Chiaki/Features/Streaming/StreamingViewModel.swift`

### 回归测试

- 手动验证：进入串流后连接保持稳定
- 编译验证：`xcodebuild build` 成功

### 经验教训

1. **对比参考实现**：当遇到连接稳定性问题时，应对比 Qt 客户端等成熟实现的机制
2. **心跳机制**：实时流媒体协议通常需要定期心跳信号，不能仅依赖用户输入触发
3. **定时器设计**：使用 `RunLoop.main.add(timer, forMode: .common)` 确保定时器在 UI 交互期间也能正常运行

---

## BUG-007: 设置页面国际化字符串显示异常

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-003 (设置界面) |
| **Issue** | N/A |
| **严重程度** | P2 |
| **修复日期** | 2026-02-05 |
| **状态** | ✅ 已修复 |

### 问题描述

设置页面中：
1. "设置-视频"中帧率和码率的值显示异常，标签名重复（如"码率 码率"）
2. "设置-音频"中音量和缓冲区大小的值显示异常，标签名重复（如"音量 音量"）

### 复现步骤

1. 将系统语言设置为中文
2. 打开 Chiaki Apple → 设置 → 视频
3. 观察帧率和码率的显示值
4. 打开设置 → 音频
5. 观察音量百分比和缓冲区大小的显示值

### 根因分析

`Localizable.xcstrings` 中带插值参数的本地化字符串（`settings.video.fps %lld`、`settings.video.mbps %lld`、`settings.audio.percent %lld`、`settings.audio.ms %lld`）只有英文翻译，没有中文翻译。

当中文环境下找不到对应翻译时，SwiftUI 会 fallback 显示 key 本身，导致显示异常。

### 解决方案

在 `Localizable.xcstrings` 中为以下 key 添加中文翻译：

| Key | 英文 | 中文 |
|-----|------|------|
| `settings.video.fps %lld` | `%lld FPS` | `%lld FPS` |
| `settings.video.mbps %lld` | `%lld Mbps` | `%lld Mbps` |
| `settings.audio.percent %lld` | `%lld%%` | `%lld%%` |
| `settings.audio.ms %lld` | `%lld ms` | `%lld 毫秒` |

### 回归测试

- 手动验证：中文环境下设置页面显示正常
- 编译验证：`xcodebuild build` 成功

---

## BUG-008: ControllerSettingsView SwiftUI Preview 崩溃

| 属性 | 内容 |
|------|------|
| **发现来源** | 开发测试 |
| **关联功能** | F-004 (控制器设置) |
| **Issue** | N/A |
| **严重程度** | P2 |
| **修复日期** | 2026-02-05 |
| **状态** | ✅ 已修复 |

### 问题描述

在 Xcode 中打开 `ControllerSettingsView.swift` 文件时，SwiftUI Preview 崩溃无法显示。

### 复现步骤

1. 在 Xcode 中打开 `Chiaki/Features/Settings/ControllerSettingsView.swift`
2. 等待 SwiftUI Preview 加载
3. Preview 崩溃，显示错误

### 根因分析

`ControllerSettingsView` 的 `#Preview` 使用 `ControllerManager.shared` 作为环境依赖。`ControllerManager.shared` 在初始化时会：

1. 调用 `setupNotifications()` 注册 GameController 通知
2. 调用 `scanConnectedControllers()` 扫描 `GCController.controllers()`

在 SwiftUI Preview 环境中，GameController 框架可能不可用或行为异常，导致 Preview 崩溃。

### 解决方案

1. 在 `ControllerManager` 中添加 `preview` 静态实例，使用特殊初始化器跳过 GameController 相关设置：

```swift
static let preview: ControllerManager = {
    let manager = ControllerManager(forPreview: true)
    return manager
}()

private init(forPreview: Bool = false) {
    guard !forPreview else {
        Logger.controller.debug("ControllerManager initialized for preview")
        return
    }
    setupNotifications()
    scanConnectedControllers()
    // ...
}
```

2. 更新 `ControllerSettingsView` 的 Preview 使用 `ControllerManager.preview`

### 回归测试

- 编译验证：`xcodebuild build` 成功
- Preview 验证：SwiftUI Preview 正常显示

### 修改文件清单

1. `Chiaki/Core/Controllers/ControllerManager.swift` - 添加 preview 实例
2. `Chiaki/Features/Settings/ControllerSettingsView.swift` - 使用 preview 实例

---

## BUG-009: ControllerSettingsView 运行时崩溃（缺少环境对象）

| 属性 | 内容 |
|------|------|
| **发现来源** | 手动测试 |
| **关联功能** | F-004 (控制器设置) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-05 |
| **状态** | ✅ 已修复 |

### 问题描述

点击"设置-手柄"时应用崩溃，错误信息：
```
SwiftUICore/Environment+Objects.swift:34: Fatal error: No Observable object of type ControllerManager found. A View.environmentObject(_:) for ControllerManager may be missing as an ancestor of this view.
```

### 复现步骤

1. 启动应用
2. 点击"设置"标签
3. 点击"手柄"设置项
4. 应用崩溃

### 根因分析

`ControllerSettingsView` 使用 `@Environment(ControllerManager.self)` 获取控制器管理器，但 `ChiakiApp.swift` 中只注入了 `settingsStore`、`navigationManager`、`hostStore`，缺少 `ControllerManager` 的环境注入。

**代码对比**：

```swift
// ControllerSettingsView.swift:17
@Environment(ControllerManager.self) var controllerManager

// ChiakiApp.swift (修复前)
ContentView()
    .environment(settingsStore)
    .environment(navigationManager)
    .environment(hostStore)  // 缺少 controllerManager
```

### 解决方案

在 `ChiakiApp.swift` 中添加 `ControllerManager` 环境注入：

1. 添加 `@State private var controllerManager = ControllerManager.shared`
2. 在 `ContentView()` 链式调用中添加 `.environment(controllerManager)`

### 回归测试

- 编译验证：`xcodebuild build` 成功
- 手动验证：点击"设置-手柄"正常显示

### 经验教训

在使用 `@Environment` 注入依赖时，必须确保在视图层级的祖先视图中通过 `.environment()` 提供对应的实例。建议：

1. 在添加新的 `@Environment` 依赖时，检查 App 入口是否已注入
2. 考虑使用编译时检查或运行时断言提前发现缺失的依赖

---

## BUG-010: MetalVideoRenderer 使用不存在的 CAMetalLayer API 导致编译失败

| 属性 | 内容 |
|------|------|
| **发现来源** | 编译失败 |
| **关联功能** | F-001 (核心流媒体), F-017 (能效管理) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-06 |
| **状态** | ✅ 已修复 |

### 问题描述

iOS 编译报错：`value of type 'CAMetalLayer' has no member 'preferredFrameRateRange'`

### 复现步骤

1. 运行 `xcodebuild build -scheme Chiaki -destination "generic/platform=iOS"`
2. 编译失败，报错位于 `MetalVideoRenderer.swift:272`

### 根因分析

代码错误地尝试在 `CAMetalLayer` 上设置 `preferredFrameRateRange` 属性：

```swift
#if (os(iOS) || os(tvOS)) && !targetEnvironment(simulator)
if #available(iOS 15.0, tvOS 15.0, *) {
    if let metalLayer = view.layer as? CAMetalLayer {
        metalLayer.preferredFrameRateRange = range  // ❌ 此属性不存在
    }
}
#endif
```

**问题**：
1. `preferredFrameRateRange` 是 `CAMetalDisplayLink` 的属性（macOS 14.0+），不是 `CAMetalLayer` 的属性
2. 条件编译 `#if (os(iOS) || os(tvOS))` 是错误的，因为该 API 根本不存在于 `CAMetalLayer`
3. 这段代码是无效的，`MTKView.preferredFramesPerSecond` 已经在前面设置了帧率

参考：[Apple Developer Documentation - CAMetalDisplayLink.preferredFrameRateRange](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/preferredframeraterange)

### 解决方案

移除无效的 `CAMetalLayer.preferredFrameRateRange` 调用，`MTKView.preferredFramesPerSecond` 已足够控制渲染帧率。

### 回归测试

- 编译验证：macOS 和 iOS 均 `BUILD SUCCEEDED`

### 经验教训

1. 使用平台特定 API 前，应查阅官方文档确认 API 的真实可用性和所属类型
2. 条件编译不能替代正确的 API 使用 - 错误的 API 在任何平台都不会工作

---

## BUG-011: PS5 刚启动时首次连接失败

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户手动测试 |
| **关联功能** | F-001, F-002 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

PS5 刚启动时，HostList 显示主机在线，但首次点击连接显示 error。返回 HostList 后再次进入串流可以成功连接。

### 复现步骤

1. 启动 PS5（从关机状态开机）
2. 等待 HostList 显示 PS5 为在线状态
3. 立即点击进入串流
4. 显示连接错误
5. 返回 HostList，再次点击进入串流
6. 连接成功

### 根因分析

PS5 刚启动时，Discovery 协议率先报告主机为 `CHIAKI_DISCOVERY_HOST_STATE_READY`（`.online`），但此时 Remote Play 服务可能尚需数秒完成初始化。`connect()` 方法在 host 为 `.online` 时直接调用 `performConnection()` 无任何重试逻辑，导致首次连接因服务未就绪而被 PS5 拒绝。

与 BUG-004（唤醒后连接失败）不同，BUG-004 是发现服务未启动导致状态未更新，而 BUG-011 是 Discovery 正确报告在线但 Remote Play 服务尚未初始化完成。

### 解决方案

在 `StreamingViewModel` 中添加连接失败自动重试机制：

1. 新增 `connectionRetryCount` 计数器和 `retryOrFail()` 方法
2. 同步路径（`session.connect()` 抛异常）和异步路径（`handleSessionStateChange(.error)`）均走重试
3. 最多重试 3 次，每次间隔 2 秒，重试期间状态保持 `.connecting`
4. 连接成功后重置计数器
5. 所有重试失败后才显示错误

### 回归测试

- 编译验证：macOS 和 iOS 均 `BUILD SUCCEEDED`
- 手动验证：需真机测试

### 修改文件清单

1. `Chiaki/Features/Streaming/StreamingViewModel.swift` — 添加重试逻辑

---

## BUG-012: 物理手柄输入未接入串流管线

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户手动测试 |
| **关联功能** | F-004 |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

物理手柄已连接且设置页正确识别，但在串流界面中手柄输入完全无响应。同时 PS5 侧的振动反馈也无法传递到手柄。

### 复现步骤

1. 通过蓝牙连接 DualSense 手柄
2. 进入设置 → 手柄，确认手柄已识别
3. 进入串流界面
4. 按手柄按钮，PS5 无任何响应

### 根因分析

**双重问题**：

1. **回调未连接**：`ControllerManager.onInputChanged` 回调从未被赋值（始终为 nil），物理手柄输入被丢弃。
2. **feedbackTimer 覆盖**（首次修复后发现）：即使连接了 `onInputChanged` → `sendControllerInput()`，feedbackTimer 每 8ms 用 `currentControllerState`（全零）调用 `session.sendControllerState()` 覆盖了物理手柄刚发送的输入。`sendControllerInput()` 只调用 `session.sendControllerState(input)` 但不更新 `currentControllerState`，导致物理手柄输入在 8ms 内被零状态覆盖。

虚拟手柄正常工作是因为 `handleInput()` 会累积更新 `currentControllerState` 再发送，与 feedbackTimer 的 `currentControllerState` 保持同步。

此外，`handleRumble()` 仅有 TODO 注释，振动反馈从未转发到物理手柄。

### 解决方案

1. 新增 `setupControllerInput()` — 连接 `ControllerManager.onInputChanged` → `sendControllerInput()`
2. 新增 `teardownControllerInput()` — 断开时清除回调
3. **在 `sendControllerInput()` 中同步 `currentControllerState = input`** — 关键修复：确保 feedbackTimer 发送的是最新的物理手柄状态而非全零
4. 修改 `handleRumble()` — 转发到 `ControllerManager.shared.applyRumble()`

### 回归测试

- 编译验证：macOS 和 iOS 均 `BUILD SUCCEEDED`
- 手动验证：需真机测试

### 修改文件清单

1. `Chiaki/Features/Streaming/StreamingViewModel.swift` — 连接物理手柄回调、振动转发

### 经验教训

1. **回调管线必须完整连接**：架构中定义了 `onInputChanged` 回调接口，但如果没有在使用方中赋值，回调就是死代码。
2. **心跳定时器与输入状态必须同步**：当存在周期性发送当前状态的定时器时，所有输入路径都必须更新同一个 `currentControllerState`，否则定时器会用过期状态覆盖有效输入。
3. **TODO 注释不等于实现**：`// TODO: Forward to controller haptics` 长期未被转化为实际代码。

---

## BUG-013: 手柄摇杆 Y 轴颠倒 + 振动反馈无效

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 |
| **关联功能** | F-004, BUG-012 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

BUG-012 修复后手柄按键已有响应，但存在三个子问题：
1. 左右摇杆上下方向颠倒（推上实际向下）
2. 振动反馈完全无效（PS5 发送的 rumble 事件无法驱动物理手柄震动）
3. PS 键无响应（iOS 系统拦截，已知限制）

### 根因分析

**摇杆 Y 轴颠倒**：GCController 框架的 Y 轴约定为正值向上（Y+ = Up），而 PlayStation 协议的 Y 轴约定为正值向下（Y+ = Down）。`handleExtendedGamepadInput()` 直接将 GCController 的 Y 值传递给 PlayStation，未做取反处理。

**振动反馈无效**：`ControllerManager.applyRumble()` 委托给 `HapticsManager.shared.applyRumble()`，后者使用 `CoreHaptics` 的 `CHHapticEngine` —— 这是设备自身的触觉引擎（iPhone 震动马达），而非物理手柄的马达。正确做法是使用 `GCController.haptics` API 获取控制器专属的 `CHHapticEngine` 实例。

**PS 键无响应**：`GCExtendedGamepad.buttonHome` 在 iOS 上被系统拦截用于系统级功能（如截屏/快捷操作），应用层无法接收此按键事件。这是 iOS 平台已知限制。

### 修复方案

1. **摇杆 Y 轴**：在 `handleExtendedGamepadInput()` 中将 Y 轴值乘以 `-32767` 取反
2. **振动反馈**：重写 `ControllerManager.applyRumble()`，优先使用 `GCController.haptics.createEngine(withLocality: .handles)` 获取控制器马达引擎，缓存引擎实例避免重复创建；无物理手柄时回退到 CoreHaptics 设备震动
3. **PS 键**：记录为 iOS 已知限制，暂不修复

### 修改文件清单

1. `Chiaki/Core/Controllers/ControllerManager.swift`:
   - 添加 `import CoreHaptics`
   - 添加 `rumbleEngine: CHHapticEngine?` 缓存属性
   - Y 轴值取反（`* -32767`）
   - 重写 `applyRumble()` 使用 `GCController.haptics` API
   - 新增 `playControllerRumble()` 和 `playRumblePattern()` 方法
   - 控制器断开时清除 `rumbleEngine`

### 回归测试

- 编译验证：macOS 和 iOS 均 `BUILD SUCCEEDED`
- 手动验证：需真机测试

### 经验教训

1. **平台 API 约定差异**：不同框架对同一物理量（如 Y 轴方向）可能有相反的约定，必须在桥接层显式转换。
2. **CoreHaptics 有两种用途**：`CHHapticEngine()` 创建的是设备引擎（手机震动），`GCController.haptics.createEngine()` 创建的是控制器引擎（手柄马达），两者 API 相同但作用对象不同。
3. **iOS 系统级按键拦截**：`buttonHome` 被系统保留，应用层不可用，需在文档中说明此限制。

---
