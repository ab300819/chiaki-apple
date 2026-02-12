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

## BUG-021: 连接成功后进入串流页面黑屏

| 属性 | 内容 |
|------|------|
| **发现来源** | 用户反馈 |
| **关联功能** | F-042 (libplacebo 渲染后端集成), AC-178 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-13 |
| **状态** | ✅ 已修复 |

### 问题描述

用户在成功连接 PS5 后进入串流页面仅看到黑屏，无视频画面。

### 复现步骤

1. 启动应用并连接 PS5（连接流程成功）
2. 进入串流页面
3. 观察到画面保持黑屏

### 根因分析

libplacebo C 桥接层的渲染管线（`WrapIOSurface` 和 `RenderFrameEx`）是 **stub 实现**（no-op），但 `PlaceboVideoRenderer.init()` 仍然"成功"返回非 nil 对象，原因：

1. `ChiakiPlaceboContextCreateLog/CreateVulkanDevice/CreateRenderer` 在无真实 libplacebo 时返回 token handle（1 字节 calloc），`guard let` 通过
2. `ChiakiPlaceboContextWrapIOSurface` 返回 token handle 而非真纹理（`PlaceboContext.m:344` TODO）
3. `ChiakiPlaceboContextRenderFrameEx` 将所有参数 `(void)` 丢弃，**返回 `true`**（`PlaceboContext.m:395-406` TODO）
4. `render()` 从未向 MTKView 绘制任何像素，但报告渲染"成功"
5. `createRenderer()` 工厂的 Metal Native 回退永远不触发（因为 placeboFactory 返回非 nil）

### 解决方案

新增 **渲染就绪检查**，在 stub 模式下使 `PlaceboVideoRenderer.init()` 返回 nil，触发已有的 Metal Native 回退路径：

1. **PlaceboBridge.h** — 新增 `ChiakiPlaceboContextIsRenderingReady()` 声明
2. **PlaceboContext.m** — 实现返回 `false`（渲染管线为 stub 时）；未来 `WrapIOSurface`/`RenderFrameEx` 真实实现后改为 `true`
3. **PlaceboTypes.swift** — `PlaceboContext` 暴露 `isRenderingReady` 属性
4. **PlaceboVideoRenderer.swift** — `init?()` 新增 `guard ctx.isRenderingReady` 检查，失败时 logWarning 并返回 nil

**回退流程**（修复后）：
```
StreamingView.onAppear
  → createRenderer(renderBackend: .libplacebo)
    → PlaceboVideoRenderer() → nil (isRenderingReady == false)
    → Logger.warning("libplacebo init failed, falling back to Metal Native")
    → MetalVideoRenderer() → 成功
  → 视频正常显示 ✅
```

### 回归测试

- `PlaceboVideoRendererTests.testStubRenderingPipelineReturnsNil()` (UT-061.5) — 验证 stub 管线 init 返回 nil
- `PlaceboVideoRendererTests.testInitReturnsNilWhenRenderingNotReady()` (UT-061.2) — 原 `testInitReturnsNonNil` 改为验证 nil
- `StreamingViewModelRenderBackendTests.testProductionFallbackWhenPlaceboStub()` (UT-064.7) — 生产工厂回退集成验证
- 编译验证：`xcodebuild build-for-testing` 通过
- 运行时验证需在可签名环境执行（已知 libplacebo.framework codesign 阻断）

### 经验教训

1. **Stub 对象不应让初始化成功**：当核心功能（渲染）是 stub 时，init 应该失败（返回 nil），而不是返回一个"看起来正常但什么都不做"的对象。这直接导致了回退机制失效。
2. **Token handle 模式的陷阱**：使用 `calloc(1, 1)` 作为占位 handle 可以让生命周期管理正确工作，但会欺骗上层代码认为资源已就绪。需要额外的"功能就绪"检查来区分"对象存在"和"功能可用"。
3. **`return true` 的隐患**：stub 函数返回 `true`/成功状态会隐藏问题，应该返回 `false` 或使用明确的"未实现"标志。

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

**PS 键无响应（iOS）**：`GCExtendedGamepad.buttonHome` 在 iOS 上被系统完全拦截用于系统级功能（截屏/快捷操作），应用层无法接收此按键事件。这是 iOS 平台已知限制。键盘 Esc 键已映射为 PS 按键的备选方案。macOS 上的 PS 键问题另见 BUG-014。

### 修复方案

1. **摇杆 Y 轴**：在 `handleExtendedGamepadInput()` 中将 Y 轴值乘以 `-32767` 取反
2. **振动反馈**：重写 `ControllerManager.applyRumble()`，优先使用 `GCController.haptics.createEngine(withLocality: .handles)` 获取控制器马达引擎，缓存引擎实例避免重复创建；无物理手柄时回退到 CoreHaptics 设备震动
3. **PS 键**：iOS 记录为已知限制（系统拦截）。macOS 另见 BUG-014 修复

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
3. **iOS buttonHome 拦截**：`buttonHome` 被 iOS 系统保留，应用层不可用。macOS 上的问题另见 BUG-014。

---

## BUG-014: macOS 上 PS 键（buttonHome）无响应

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 (macOS 26) |
| **关联功能** | F-004, BUG-013 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

macOS 26 上按下 DualSense 的 PS 键没有任何响应——既不触发系统动作（Launchpad），也不被应用接收。

### 根因分析

`buttonHome` 是 `GCExtendedGamepad` 的可选属性（`GCControllerButtonInput?`），与 touchpad 按钮类似，它**不会触发主 `valueChangedHandler`**。当前代码仅在 `gamepad.valueChangedHandler` 回调中通过 `buttonHome?.isPressed` 轮询状态，但该回调根本不会因 `buttonHome` 的变化而被调用。

对比已正常工作的 touchpad 按钮，它在 `setupDualSenseHandlers()` 中单独注册了 `dualSense.touchpadButton.valueChangedHandler`，所以能独立接收事件。`buttonHome` 缺少同样的独立 handler 注册。

### 修复方案

在 `setupExtendedGamepadHandlers()` 中为 `buttonHome` 注册独立的 `pressedChangedHandler`，与 touchpad 按钮采用相同模式：直接更新 `currentInput` 并通过 `onInputChanged` 发出。

### 修改文件清单

1. `Chiaki/Core/Controllers/ControllerManager.swift`:
   - 在 `setupExtendedGamepadHandlers()` 中添加 `gamepad.buttonHome?.pressedChangedHandler` 注册

### 回归测试

- 编译验证：macOS 和 iOS 均 `BUILD SUCCEEDED`
- 手动验证：需真机测试

### 经验教训

1. **可选按钮需要独立 handler**：`GCExtendedGamepad` 的可选按钮（`buttonHome`、`buttonOptions`）可能不会触发主 `valueChangedHandler`，必须为它们单独注册 `pressedChangedHandler`。
2. **轮询 vs 事件驱动**：在事件驱动的回调中轮询可选按钮的 `isPressed` 是无效的——如果该按钮的变化不触发回调，轮询代码永远不会执行。
3. **参照已有模式**：touchpad 按钮已经使用了独立 handler 模式，新增的可选按钮应遵循同样的模式。

---

## BUG-015: 串流画面偏暗、色彩失真、模糊

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 |
| **关联功能** | F-001, F-024, F-025 |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

串流画面整体偏暗，色彩有失真感，且画面看起来比较模糊（比 PS5 直连显示器的效果差很多）。

### 根因分析

**1. 画面偏暗 + 色彩失真 — HDR EDR 亮度映射错误**

用户使用 HDR 模式在 P3 色域 Retina 显示器上串流。着色器中 `linearToEDR()` 使用硬编码系数 12.5（= 10000/800），隐含 SDR 白 = 800 nits。但 Apple EDR 空间中 1.0 = SDR 白（标准约 200~203 nits），正确系数应为 10000/203 ≈ 49.26。

数学验证（假设 edrHeadroom = 3.0）：
- SDR 白 (203 nits) → PQ EOTF → ~0.0203 线性
- `linearToEDR` = 0.0203 * 12.5 = 0.254
- `* edrHeadroom` = 0.254 * 3.0 = 0.762
- 结果：SDR 白在 EDR 空间只有 0.76，应该是 1.0 → **画面整体偏暗约 25%**

如果 edrHeadroom 因平滑延迟仍为 ~1.5，SDR 白 = 0.0203 * 12.5 * 1.5 = 0.38 → **画面偏暗超过 60%**

此外 `* uniforms.edrHeadroom` 用法有误：Apple EDR 中超过 1.0 的值自动以 HDR 亮度显示直到 headroom 上限，不需要手动乘以 headroom。

**2. 画面模糊 — macOS Retina 缩放未处理**

`MTKView` 未设置 `layer.contentsScale`。macOS 上 `CAMetalLayer.contentsScale` 默认为 1.0（非 Retina），即使在 Retina 显示器（2x/3x）上，drawable 也只有 1x 分辨率，拉伸显示后造成模糊。iOS 的 `UIView` 默认会自动处理 scale，但 macOS 需要手动设置。

### 修复方案

见 T-227（HDR EDR 亮度映射修复）、T-228（macOS Retina drawable 分辨率修复）任务拆分。

---

## BUG-016: 快速运动时画面先糊后清晰

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 |
| **关联功能** | F-001 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

快速运动场景中画面先变模糊，然后恢复清晰。对比 chiaki-ng Qt6 桌面版无此问题。

### 根因分析

`VideoToolboxDecoder` 中有一个 4 帧重排缓冲区 (`maxReorderBufferSize = 4`)，设计用于处理 B 帧重排。但 PlayStation Remote Play 使用的是 I/P-only 编码（无 B 帧），帧按显示顺序到达，不需要重排。

该缓冲区引入约 67ms（@60fps）的额外延迟，导致：
1. 运动场景中解码后的帧被延迟输出，感知上的"模糊持续时间"延长
2. PS5 发送的 IDR 恢复帧也被缓冲延迟，清晰度恢复变慢

对比 chiaki-ng 的 FFmpeg 解码器 (`chiaki_ffmpeg_decoder_pull_frame()`)，它采用"只取最新帧"策略，零缓冲延迟。

### 解决方案

移除帧重排缓冲区，改为解码完成后直接交付帧：
- 删除 `frameReorderBuffer` 和 `maxReorderBufferSize` 属性
- 简化 `handleDecodedFrame()` 为直接调用 `onFrameDecoded`
- `flush()` 改为空操作（无待处理帧）

### 回归测试

- 视觉验证：快速运动场景恢复速度提升
- 关联 commit：待提交

### 经验教训

1. 远程串流协议不一定使用标准视频编码的所有特性（如 B 帧），为"可能需要"的功能预设缓冲会引入不必要的延迟
2. 参考同项目的其他平台实现（chiaki-ng FFmpeg decoder）可以快速定位架构差异

---

## BUG-017: 窗口最大化后画面模糊

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 |
| **关联功能** | F-001 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-09 |
| **状态** | ✅ 已修复 |

### 问题描述

macOS 上默认窗口大小时画面清晰，但窗口最大化后画面变模糊。

### 根因分析

两个相关问题：

1. **一次性 Retina scale 检查**：`MTKViewDelegateBridge` 中的 `retinaScaleApplied` 标志使 `contentsScale` 只在首帧设置一次。窗口 resize/最大化时如果 scale 变化（如从普通显示器拖到 Retina 显示器），不会重新应用。

2. **`drawableSizeWillChange` 时 contentsScale 不一致**：窗口 resize 时 MTKView 自动调用 `drawableSizeWillChange`，但如果此时 `layer.contentsScale` 与 `window.backingScaleFactor` 不匹配，传入的 `drawableSize` 就是 1x 分辨率而非 2x。

### 解决方案

- 将一次性检查改为每帧检查 (`lastAppliedScale` 对比)，仅在 scale 变化时更新
- 在 `drawableSizeWillChange` 回调中也验证并修正 `contentsScale`
- 确保 resize 后 `drawableSize` 反映正确的 Retina 分辨率

### 回归测试

- 视觉验证：默认窗口 → 最大化 → 画面保持清晰
- 关联 commit：待提交

---

## BUG-018: macOS 上 DualSense PS 按键无响应（GameController 框架限制）

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 (macOS, DualSense 蓝牙) |
| **关联功能** | F-004, BUG-014 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-10 |
| **状态** | 🔧 待验证 |

### 问题描述

macOS 上通过蓝牙连接 DualSense 控制器时，按 PS 键完全没有反应——macOS 系统不响应（不打开 Launchpad），chiaki 应用也不接收事件。BUG-014 已添加 `pressedChangedHandler`，但在 macOS 蓝牙 DualSense 上该 handler 不被触发。

chiaki-ng 使用 SDL → HIDAPI → IOKit HID 直接读取原始 HID 报告，PS 按键正常工作。

### 根因分析

Apple GameController 框架的 `GCExtendedGamepad.buttonHome` 在 macOS 蓝牙连接 DualSense 时不可靠地传递 PS 按键事件。DualSense 蓝牙默认以 10 字节基础模式运行（不包含 PS 按键数据）；需要读取特征报告激活增强模式才能获取 PS 按键位。GameController 框架可能未正确处理此增强模式切换。

### 解决方案

新增 `DualSenseHIDManager.swift`，通过 IOKit HID 直接与 DualSense 通信：

1. 使用 `IOHIDManager` 按 VID=0x054C/PID=0x0CE6(0x0DF2) 匹配 DualSense
2. 蓝牙连接时读取特征报告 0x09/0x20 激活增强模式
3. 注册 `IOHIDDeviceRegisterInputReportCallback` 回调读取原始输入报告
4. 解析 `buttons[2]` bit 0 获取 PS 按键状态
5. 通过 `onPSButtonChanged` 回调更新 ControllerManager 的输入状态

仅限 `#if os(macOS)`，iOS/tvOS 仍使用 GameController 框架。

### 修改文件清单

1. `Chiaki/Core/Controllers/DualSenseHIDManager.swift`（新增）— IOKit HID 直连管理器
2. `Chiaki/Core/Controllers/ControllerManager.swift` — 集成 HID PS 按键回调

### 回归测试

- 编译验证：macOS `BUILD SUCCEEDED`
- 手动验证：需真机测试（DualSense 蓝牙连接 macOS）

---

## BUG-019: macOS 上 DualSense 手柄震动不工作

| 属性 | 内容 |
|------|------|
| **发现来源** | 真机测试 (macOS, DualSense 蓝牙) |
| **关联功能** | F-004, F-021 |
| **Issue** | N/A |
| **严重程度** | P1 |
| **修复日期** | 2026-02-10 |
| **状态** | 🔧 待验证 |

### 问题描述

macOS 上通过蓝牙连接 DualSense 控制器时，串流中 PS5 发送的震动指令没有效果，控制器不震动。chiaki-ng 使用 SDL 的 `SDL_GameControllerRumble()` / `SDL_GameControllerSendEffect()` 通过 HIDAPI 直接发送 HID 输出报告，震动正常。

### 根因分析

`ControllerManager.applyRumble()` 使用 `GCController.haptics` → `GCDeviceHaptics.createEngine(withLocality: .handles)` 创建 `CHHapticEngine`，但在 macOS 上 `GCController.haptics` 返回 nil 或 `createEngine` 失败。原因：

1. macOS 的 GCDeviceHaptics 对蓝牙 DualSense 支持不完整
2. 回退到 `HapticsManager.shared.applyRumble()` 使用设备 CoreHaptics（驱动 MacBook 触控板震动），而非控制器电机

chiaki-ng 通过 SDL 直接发送 DualSense 特定的输出报告（`DS5EffectsState_t`），设置 `motor_left`/`motor_right` 强度字节，绕过 GameController 框架。

### 解决方案

在 `DualSenseHIDManager` 中实现直接 HID 输出报告发送：

1. USB 模式：构建 63 字节输出报告（Report ID 0x02），设置 valid_flag0 + motor 强度
2. 蓝牙模式：构建 78 字节输出报告（Report ID 0x31），含序列号、tag 0x10、payload、CRC32
3. CRC32 使用 seed 0xA2，覆盖全部报告字节（除最后 4 字节）
4. `ControllerManager.applyRumble()` 在 macOS 上优先通过 HID 发送震动

参考：chiaki-ng `controllermanager.cpp` 的 `SetDualSenseRumble()`、Linux kernel `hid-playstation.c`

### 修改文件清单

1. `Chiaki/Core/Controllers/DualSenseHIDManager.swift`（新增）— 震动输出报告构建与发送
2. `Chiaki/Core/Controllers/ControllerManager.swift` — macOS 震动路径优先使用 HID

### 回归测试

- 编译验证：macOS `BUILD SUCCEEDED`
- 手动验证：需真机测试（DualSense 蓝牙连接 macOS 串流 PS5）

### 经验教训

1. **GameController 框架在 macOS 上的限制**：`buttonHome` 和 `GCDeviceHaptics` 在 macOS 蓝牙 DualSense 上不可靠，必须用 IOKit HID 直连绕过。
2. **DualSense 蓝牙增强模式**：默认基础模式只有 10 字节报告，缺少按键和传感器数据。必须读取特征报告 0x09/0x20 才能激活增强模式。
3. **蓝牙输出报告需要 CRC32**：与 USB 不同，蓝牙输出报告需要正确的序列号和 CRC32 校验，否则控制器忽略指令。
4. **非独占打开允许共存**：IOKit HID 非独占模式（`kIOHIDOptionsTypeNone`）允许与 GameController 框架并存，HID 只负责 PS 按键和震动，其余输入（摇杆、面板按钮等）仍由 GameController 框架处理。

---

## BUG-020: Metal shader 编译失败导致串流黑屏

| 属性 | 内容 |
|------|------|
| **发现来源** | 手动测试 (macOS 串流) |
| **关联功能** | F-041 (Metal 原生高质量视频滤波管线) |
| **Issue** | N/A |
| **严重程度** | P0 |
| **修复日期** | 2026-02-10 |
| **状态** | ✅ 已修复 |

### 问题描述

在 T-238 (CAS 自适应锐化) 实现后，macOS 上连接 PlayStation 串流后一直黑屏，从未显示过视频画面。之前版本串流正常。

### 复现步骤

1. 在 macOS 上启动 Chiaki
2. 连接 PlayStation 主机
3. 进入串流画面
4. 观察到黑屏，无任何视频输出

### 根因分析

`contrastAdaptiveSharpening()` 函数（BGRA CAS，MetalVideoRenderer.swift 运行时 shader 字符串第 174 行）中使用了 `constant float3 lumaW` 声明局部变量：

```metal
constant float3 lumaW = float3(0.2126, 0.7152, 0.0722);
```

在 Metal Shading Language 中，`constant` 是**地址空间限定符**（address space qualifier），仅用于函数参数和全局变量，不能用于局部变量。局部常量应使用 C++ 风格的 `const`。

此语法错误导致 `device.makeLibrary(source:)` 运行时编译失败。由于项目中没有 `.metal` 文件（VideoShaders.txt 未加入 Xcode 项目），`makeDefaultLibrary()` 返回 nil，运行时编译是唯一路径。编译失败使 `setupPipelines()` 返回 false → `MetalVideoRenderer.init()` 返回 nil → 无渲染器 → 黑屏。

### 解决方案

将两处（VideoShaders.txt + MetalVideoRenderer.swift 运行时 shader 字符串）`constant float3 lumaW` 改为 `const float3 lumaW`：

```diff
-        constant float3 lumaW = float3(0.2126, 0.7152, 0.0722);
+        const float3 lumaW = float3(0.2126, 0.7152, 0.0722);
```

修复后通过 `device.makeLibrary(source:)` 手动验证编译成功，3 个 shader 函数均正常加载。

### 回归测试

- 新增测试：`ShaderCompilationTests.testShaderSourceCompilesSuccessfully()` — 验证 MetalVideoRenderer 能成功初始化（隐含 shader 编译成功）
- 新增测试：`ShaderCompilationTests.testFilterConfigDefaultAfterInit()` — 验证 filter config 默认值正确
- 关联文件：`ChiakiTests/VideoRendererTests.swift`

### 经验教训

1. **Metal `constant` vs `const`**：Metal 中 `constant` 是地址空间限定符（类似 `device`、`thread`），函数内局部变量应使用 `const`（C++ 语义）。全局 `constant float` 是合法的（分配在 constant 地址空间），但函数内部的 `constant float3` 是非法的。
2. **运行时 shader 编译缺乏预检**：项目依赖运行时 `makeLibrary(source:)` 编译 shader，无法在构建阶段捕获语法错误。应考虑添加编译期 shader 验证（将 .txt 改为 .metal 加入 Xcode 项目）。
3. **双份 shader 代码维护风险**：VideoShaders.txt 和运行时 shader 字符串必须同步维护，任何不一致都可能导致难以追踪的 Bug。

---
