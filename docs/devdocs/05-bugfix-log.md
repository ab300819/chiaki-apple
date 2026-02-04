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
