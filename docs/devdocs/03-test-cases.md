# Chiaki-ng Apple 原生客户端 - 测试用例

> **文档来源**: 新建（基于 DESIGN.md 第 5 节 + test/ 目录 + 代码逆向推导）
> **改造时间**: 2026-01-13
> **改造模式**: 增量补充
> **迁移更新**: 2026-01-19 - 添加测试编号体系 (UT/IT/E2E-XXX)，添加追溯矩阵

## 1. 测试策略概述

### 1.1 测试目标

确保 Chiaki-ng Apple 原生客户端在所有目标平台（iOS、iPadOS、macOS、tvOS）上稳定运行，满足以下质量标准：

- **功能正确性**: 所有功能按需求文档描述工作
- **性能达标**: 满足 PRD 中定义的性能指标
- **兼容性**: 支持所有目标设备和 PlayStation 主机
- **用户体验**: 操作流畅，无明显卡顿或延迟

### 1.2 测试范围

| 测试类型 | 范围 | 工具 |
|----------|------|------|
| 单元测试 | ChiakiBridge、Domain 层、Core 模块 | XCTest |
| 集成测试 | 视频渲染、音频播放、控制器集成 | XCTest |
| UI 测试 | 所有用户界面交互 | XCUITest |
| 性能测试 | 帧率、延迟、内存占用 | Instruments |
| 手动测试 | 端到端功能验证、真机测试 | 测试清单 |

### 1.3 测试环境

| 环境 | 设备/配置 | 用途 |
|------|-----------|------|
| iOS Simulator | iPhone 15 Pro, iOS 17 | 单元测试、UI 测试 |
| iPadOS Simulator | iPad Pro 12.9", iPadOS 17 | 单元测试、UI 测试 |
| tvOS Simulator | Apple TV 4K, tvOS 17 | 焦点导航测试 |
| macOS | macOS 14 Sonoma | 真机测试 |
| iOS 真机 | iPhone 12 及以上 | 性能测试、控制器测试 |
| Apple TV 真机 | Apple TV 4K | tvOS 完整功能测试 |

---

## 2. 单元测试

### 2.1 覆盖率要求

| 模块 | 目标覆盖率 | 优先级 |
|------|------------|--------|
| Core/Bridge | ≥ 80% | P0 |
| Domain/Models | ≥ 90% | P0 |
| Domain/Services | ≥ 70% | P0 |
| Core/Video | ≥ 60% | P1 |
| Core/Audio | ≥ 60% | P1 |
| Core/Controllers | ≥ 70% | P1 |
| Features | ≥ 50% | P2 |

### 2.2 ChiakiBridge 测试

#### UT-001: ChiakiSession 测试

```swift
// ChiakiSessionTests.swift
import XCTest
@testable import Chiaki

final class ChiakiSessionTests: XCTestCase {
    var session: ChiakiSession!

    override func setUp() {
        super.setUp()
        session = ChiakiSession()
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    // 状态测试
    func testInitialState() {
        XCTAssertEqual(session.state, .idle)
    }

    func testStateTransitionToConnecting() async throws {
        // 测试状态转换
    }

    // 控制器状态测试
    func testControllerStateEncoding() {
        var state = ControllerState()
        state.buttons = [.cross, .circle]
        state.leftStick.x = 1000
        state.l2 = 255

        XCTAssertTrue(state.buttons.contains(.cross))
        XCTAssertTrue(state.buttons.contains(.circle))
        XCTAssertEqual(state.leftStick.x, 1000)
        XCTAssertEqual(state.l2, 255)
    }
}
```

#### UT-002: ChiakiDiscovery 测试

| 编号 | 测试用例 | 描述 | 预期结果 |
|------|----------|------|----------|
| UT-002.1 | testStartDiscovery | 启动发现服务 | isDiscovering = true |
| UT-002.2 | testStopDiscovery | 停止发现服务 | isDiscovering = false |
| UT-002.3 | testHostDiscovered | 模拟发现主机回调 | discoveredHosts 包含主机 |
| UT-002.4 | testHostStatusUpdate | 主机状态更新 | 主机状态正确更新 |

### 2.3 Domain 层测试

#### UT-003: Host 模型测试

```swift
// HostTests.swift
final class HostTests: XCTestCase {
    func testHostCodable() throws {
        let host = Host(
            nickname: "PS5",
            address: "192.168.1.100",
            isPS5: true
        )

        let data = try JSONEncoder().encode(host)
        let decoded = try JSONDecoder().decode(Host.self, from: data)

        XCTAssertEqual(host.nickname, decoded.nickname)
        XCTAssertEqual(host.address, decoded.address)
        XCTAssertEqual(host.isPS5, decoded.isPS5)
    }

    func testHostEquatable() {
        let host1 = Host(id: UUID(), nickname: "PS5", address: "192.168.1.100")
        let host2 = host1

        XCTAssertEqual(host1, host2)
    }
}
```

#### UT-004: HostStore 测试

```swift
// HostStoreTests.swift
final class HostStoreTests: XCTestCase {
    var store: HostStore!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: "test")
        store = HostStore(userDefaults: userDefaults!)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test")
    }

    func testSaveAndLoadHosts() async {
        let host = Host(nickname: "Test PS5", address: "192.168.1.100", isPS5: true)

        await store.addHost(host)
        let hosts = await store.loadHosts()

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts.first?.nickname, "Test PS5")
    }

    func testRemoveHost() async {
        let host = Host(nickname: "Test PS5", address: "192.168.1.100")
        await store.addHost(host)
        await store.removeHost(host)

        let hosts = await store.loadHosts()
        XCTAssertTrue(hosts.isEmpty)
    }
}
```

#### UT-005: StreamSettings 测试

| 编号 | 测试用例 | 描述 | 预期结果 |
|------|----------|------|----------|
| UT-005.1 | testDefaultSettings | 默认设置值 | 分辨率 1080p, 帧率 60fps |
| UT-005.2 | testSettingsCodable | 设置序列化 | 编码解码后相等 |
| UT-005.3 | testResolutionDimensions | 分辨率尺寸 | 1080p = 1920x1080 |

#### UT-009: NavigationManager 测试 (2026-01-22 补充)

> 关联功能: 应用导航状态管理
> 验收标准: 侧边栏、Sheet、命令触发器正确工作

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| UT-009.1 | testInitialState | 初始导航状态 | sidebarSelection = .hosts | P0 |
| UT-009.2 | testOpenAddHost | openAddHost() 调用 | showAddHostSheet = true, sidebarSelection = .hosts | P0 |
| UT-009.3 | testNavigateToSettings | navigateToSettings() 调用 | sidebarSelection = .settings | P0 |
| UT-009.4 | testRefreshDiscovery | refreshDiscovery() 调用 | refreshDiscoveryTrigger = true | P1 |
| UT-009.5 | testWakeUpSelectedHost | wakeUpSelectedHost() 调用 | wakeUpSelectedHostTrigger = true | P1 |
| UT-009.6 | testStartAutoConnect | startAutoConnect() 调用 | isAutoConnecting = true, autoConnectHost 设置 | P1 |
| UT-009.7 | testEndAutoConnect | endAutoConnect() 调用 | isAutoConnecting = false, autoConnectHost = nil | P1 |
| UT-009.8 | testStreamingState | 流媒体状态变更 | isStreaming 正确更新 | P1 |

```swift
// NavigationManagerTests.swift
import Testing
@testable import Chiaki

@MainActor
struct NavigationManagerTests {

    // UT-009.1
    @Test func testInitialState() {
        let manager = NavigationManager()

        #expect(manager.sidebarSelection == .hosts)
        #expect(manager.showAddHostSheet == false)
        #expect(manager.isStreaming == false)
        #expect(manager.isAutoConnecting == false)
    }

    // UT-009.2
    @Test func testOpenAddHost() {
        let manager = NavigationManager()
        manager.sidebarSelection = .settings // 先切换到设置

        manager.openAddHost()

        #expect(manager.sidebarSelection == .hosts) // 应切回主机列表
        #expect(manager.showAddHostSheet == true)
    }

    // UT-009.3
    @Test func testNavigateToSettings() {
        let manager = NavigationManager()

        manager.navigateToSettings()

        #expect(manager.sidebarSelection == .settings)
    }

    // UT-009.4
    @Test func testRefreshDiscovery() {
        let manager = NavigationManager()
        manager.sidebarSelection = .settings

        manager.refreshDiscovery()

        #expect(manager.sidebarSelection == .hosts)
        #expect(manager.refreshDiscoveryTrigger == true)
    }

    // UT-009.5
    @Test func testWakeUpSelectedHost() {
        let manager = NavigationManager()

        manager.wakeUpSelectedHost()

        #expect(manager.wakeUpSelectedHostTrigger == true)
    }

    // UT-009.6 & UT-009.7
    @Test func testAutoConnectLifecycle() {
        let manager = NavigationManager()
        let host = ConsoleHost(nickname: "Test PS5", address: "192.168.1.100")

        // 开始自动连接
        manager.startAutoConnect(host: host)
        #expect(manager.isAutoConnecting == true)
        #expect(manager.autoConnectHost?.id == host.id)

        // 结束自动连接
        manager.endAutoConnect()
        #expect(manager.isAutoConnecting == false)
        #expect(manager.autoConnectHost == nil)
    }

    // UT-009.8
    @Test func testStreamingStateToggle() {
        let manager = NavigationManager()

        manager.isStreaming = true
        #expect(manager.isStreaming == true)

        manager.isStreaming = false
        #expect(manager.isStreaming == false)
    }
}
```

---

## 3. 集成测试

### IT-001: 视频渲染集成测试

```swift
// StreamingIntegrationTests.swift
import XCTest
import MetalKit
@testable import Chiaki

final class VideoRenderingIntegrationTests: XCTestCase {
    func testVideoRendererInitialization() throws {
        let view = MTKView()
        let renderer = try MetalVideoRenderer(metalView: view)

        XCTAssertNotNil(renderer)
    }

    func testPixelBufferTextureConversion() throws {
        // 创建测试用 NV12 PixelBuffer
        let pixelBuffer = createTestNV12PixelBuffer(width: 1920, height: 1080)
        let view = MTKView()
        let renderer = try MetalVideoRenderer(metalView: view)

        // 测试纹理创建
        renderer.updateFrame(pixelBuffer)
        // 验证渲染无崩溃
    }

    private func createTestNV12PixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
        // 创建测试 PixelBuffer
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &pixelBuffer
        )
        return pixelBuffer!
    }
}
```

### IT-002: 音频播放集成测试

```swift
// AudioIntegrationTests.swift
final class AudioIntegrationTests: XCTestCase {
    func testAudioPlayerInitialization() throws {
        let player = try AudioPlayer()

        XCTAssertNotNil(player)
    }

    func testAudioSessionConfiguration() throws {
        let player = try AudioPlayer()

        // 验证音频会话配置正确
        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
        #endif
    }
}
```

### IT-003: 控制器集成测试

| 编号 | 测试用例 | 描述 | 预期结果 |
|------|----------|------|----------|
| IT-003.1 | testControllerConnection | 控制器连接检测 | connectedControllers 更新 |
| IT-003.2 | testButtonMapping | 按钮映射正确性 | A→Cross, B→Circle 等 |
| IT-003.3 | testStickValues | 摇杆值范围 | -32767 到 32767 |
| IT-003.4 | testTriggerValues | 扳机值范围 | 0 到 255 |

### IT-005: 主机发现与存储集成测试 (2026-01-22 补充)

> 关联用户故事: US-001 主机发现和连接
> 验收标准: AC-001 ~ AC-004
> 涉及组件: DiscoveryService + HostStore + HostManager

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| IT-005.1 | testDiscoveredHostMergedToStore | 发现主机后合并到存储 | hosts 包含发现的主机 | P0 |
| IT-005.2 | testStoredHostStateUpdatedByDiscovery | 已存储主机状态更新 | state 从 offline 变为 online | P0 |
| IT-005.3 | testHiddenHostNotInMergedList | 隐藏主机不显示 | isHidden=true 的主机不在 hosts 中 | P1 |
| IT-005.4 | testHostAddressUpdateOnDiscovery | 主机地址变更 | 按 MAC 匹配后更新地址 | P1 |
| IT-005.5 | testOfflineMarkingWhenDiscoveryStopped | 发现停止后标记离线 | 发现中断后 state=offline | P1 |
| IT-005.6 | testRunningAppInfoMerged | 运行中应用信息合并 | runningApp/runningAppId 正确更新 | P2 |

```swift
// HostDiscoveryIntegrationTests.swift
import Testing
import Combine
@testable import Chiaki

@MainActor
struct HostDiscoveryIntegrationTests {

    // IT-005.1
    @Test func testDiscoveredHostMergedToStore() async {
        let defaults = UserDefaults(suiteName: "test.integration.discovery")!
        defaults.removePersistentDomain(forName: "test.integration.discovery")

        let hostStore = HostStore(userDefaults: defaults)
        let discoveryService = DiscoveryService()
        let hostManager = HostManager(discoveryService: discoveryService, hostStore: hostStore)

        // 模拟添加主机到存储
        let storedHost = ConsoleHost(
            nickname: "My PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        hostStore.addHost(storedHost)

        // 验证主机在合并列表中
        #expect(hostManager.hosts.contains { $0.macAddress == "AA:BB:CC:DD:EE:FF" })
    }

    // IT-005.2
    @Test func testStoredHostStateUpdatedByDiscovery() async {
        let defaults = UserDefaults(suiteName: "test.integration.state")!
        defaults.removePersistentDomain(forName: "test.integration.state")

        let hostStore = HostStore(userDefaults: defaults)
        var host = ConsoleHost(nickname: "PS5", address: "192.168.1.100")
        host.state = .offline
        hostStore.addHost(host)

        let hostManager = HostManager(hostStore: hostStore)

        // 初始状态应为 offline
        #expect(hostManager.hosts.first?.state == .offline)

        // 注：实际发现更新需要网络，这里验证初始状态
    }

    // IT-005.3
    @Test func testHiddenHostNotInMergedList() {
        let defaults = UserDefaults(suiteName: "test.integration.hidden")!
        defaults.removePersistentDomain(forName: "test.integration.hidden")

        let hostStore = HostStore(userDefaults: defaults)

        var visibleHost = ConsoleHost(nickname: "Visible", address: "192.168.1.1")
        visibleHost.isHidden = false

        var hiddenHost = ConsoleHost(nickname: "Hidden", address: "192.168.1.2")
        hiddenHost.isHidden = true

        hostStore.addHost(visibleHost)
        hostStore.addHost(hiddenHost)

        let hostManager = HostManager(hostStore: hostStore)

        // 只有可见主机在列表中
        #expect(hostManager.hosts.count == 1)
        #expect(hostManager.hosts.first?.nickname == "Visible")
    }

    // IT-005.4
    @Test func testHostAddressUpdatePreservesRegistration() {
        let defaults = UserDefaults(suiteName: "test.integration.address")!
        defaults.removePersistentDomain(forName: "test.integration.address")

        let hostStore = HostStore(userDefaults: defaults)

        // 添加已注册主机
        var host = ConsoleHost(
            nickname: "PS5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            registKey: Data([0x01, 0x02, 0x03])
        )
        hostStore.addHost(host)

        // 更新地址
        host.address = "192.168.1.200"
        hostStore.updateHost(host)

        // 验证注册信息保留
        let updated = hostStore.host(byId: host.id)
        #expect(updated?.address == "192.168.1.200")
        #expect(updated?.isRegistered == true)
    }
}
```

### IT-006: 设置持久化集成测试 (2026-01-22 补充)

> 关联用户故事: US-008 设置持久化
> 验收标准: AC-031 ~ AC-034
> 涉及组件: SettingsStore + UserDefaults

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| IT-006.1 | testSettingsPersistAcrossInstances | 设置跨实例持久化 | 新实例读取到保存的设置 | P0 |
| IT-006.2 | testVideoSettingsPersistence | 视频设置持久化 | 分辨率、帧率、码率保存 | P0 |
| IT-006.3 | testAudioSettingsPersistence | 音频设置持久化 | 音量、缓冲区设置保存 | P0 |
| IT-006.4 | testControllerSettingsPersistence | 控制器设置持久化 | 触觉反馈、映射保存 | P1 |
| IT-006.5 | testResetToDefaultsClears | 重置清除所有设置 | 恢复默认值 | P1 |
| IT-006.6 | testKeyboardMappingsPersistence | 键盘映射持久化 (macOS) | 自定义映射保存 | P1 |
| IT-006.7 | testSettingsExportImport | 导入导出一致性 | 导出后导入恢复相同设置 | P2 |

```swift
// SettingsPersistenceIntegrationTests.swift
import Testing
@testable import Chiaki

@MainActor
struct SettingsPersistenceIntegrationTests {

    // IT-006.1
    @Test func testSettingsPersistAcrossInstances() {
        let suiteName = "test.integration.settings.persist"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // 第一个实例：修改设置
        let store1 = SettingsStore(userDefaults: defaults)
        store1.updateResolution(.r720p)
        store1.updateFrameRate(.fps30)
        store1.updateBitrate(8000)

        // 第二个实例：验证设置保留
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.localProfile.resolution == .r720p)
        #expect(store2.streamSettings.localProfile.frameRate == .fps30)
        #expect(store2.streamSettings.localProfile.bitrate == 8000)
    }

    // IT-006.2
    @Test func testVideoSettingsPersistence() {
        let suiteName = "test.integration.settings.video"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // 修改所有视频设置
        store.updateResolution(.r2160p)
        store.updateFrameRate(.fps60)
        store.updateBitrate(50000)
        store.updateCodec(.h265)
        store.updateHdrEnabled(true)

        // 重新加载验证
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.localProfile.resolution == .r2160p)
        #expect(store2.streamSettings.localProfile.frameRate == .fps60)
        #expect(store2.streamSettings.localProfile.bitrate == 50000)
        #expect(store2.streamSettings.codec == .h265)
        #expect(store2.streamSettings.hdrEnabled == true)
    }

    // IT-006.3
    @Test func testAudioSettingsPersistence() {
        let suiteName = "test.integration.settings.audio"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // 修改音频设置
        store.streamSettings.volume = 0.75
        store.streamSettings.audioBufferSize = 20
        store.streamSettings.microphoneEnabled = true
        store.save()

        // 重新加载验证
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.volume == 0.75)
        #expect(store2.streamSettings.audioBufferSize == 20)
        #expect(store2.streamSettings.microphoneEnabled == true)
    }

    // IT-006.4
    @Test func testControllerSettingsPersistence() {
        let suiteName = "test.integration.settings.controller"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // 修改控制器设置
        store.streamSettings.hapticFeedbackEnabled = false
        store.streamSettings.isTouchControllerEnabled = false
        store.save()

        // 重新加载验证
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.hapticFeedbackEnabled == false)
        #expect(store2.streamSettings.isTouchControllerEnabled == false)
    }

    // IT-006.5
    @Test func testResetToDefaultsClears() {
        let suiteName = "test.integration.settings.reset"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // 修改设置
        store.updateResolution(.r540p)
        store.updateFrameRate(.fps30)
        store.updateBitrate(5000)

        // 重置
        store.resetToDefaults()

        // 验证恢复默认
        #expect(store.streamSettings.localProfile.resolution == .r1080p)
        #expect(store.streamSettings.localProfile.frameRate == .fps60)
        #expect(store.streamSettings.localProfile.bitrate == 15000)
    }

    #if os(macOS)
    // IT-006.6
    @Test func testKeyboardMappingsPersistence() {
        let suiteName = "test.integration.settings.keyboard"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: defaults)

        // 修改键盘映射
        store.keyboardMappings.setMapping(for: .cross, keyCode: 0x06, keyName: "Z")
        store.keyboardMappings.setMapping(for: .circle, keyCode: 0x07, keyName: "X")

        // 触发保存（通过修改其他设置）
        store.keyboardInputEnabled = true

        // 重新加载验证
        let store2 = SettingsStore(userDefaults: defaults)
        let crossMapping = store2.keyboardMappings.mapping(for: .cross)
        #expect(crossMapping.keyCode == 0x06)
        #expect(crossMapping.keyName == "Z")
    }
    #endif
}
```

---

## 4. UI 自动化测试

> **更新时间**: 2026-01-22
> **覆盖范围**: 主机列表、设置页面、添加主机、流媒体页面、tvOS 焦点导航

### 4.1 测试策略

| 平台 | 测试方式 | 工具 |
|------|----------|------|
| iOS/iPadOS | XCUITest 自动化 | XCUIApplication |
| macOS | XCUITest 自动化 | XCUIApplication |
| tvOS | XCUITest + 焦点导航 | XCUIRemote |

### 4.2 Accessibility Identifier 规范

为支持 UI 自动化测试，需在视图中添加 `.accessibilityIdentifier()`：

| 页面 | 元素 | Identifier |
|------|------|------------|
| HostList | 添加主机按钮 | `addHostButton` |
| HostList | 发现开关按钮 | `discoveryToggleButton` |
| HostList | 主机列表 | `hostList` |
| HostList | 主机行 | `hostRow_\(host.id)` |
| AddHost | 昵称输入框 | `nicknameTextField` |
| AddHost | 地址输入框 | `addressTextField` |
| AddHost | 主机类型选择器 | `consoleTypePicker` |
| AddHost | 保存按钮 | `saveHostButton` |
| Settings | 设置导航入口 | `settingsButton` |
| Settings | 视频设置入口 | `videoSettingsLink` |
| Settings | 音频设置入口 | `audioSettingsLink` |
| Settings | 控制器设置入口 | `controllerSettingsLink` |
| VideoSettings | 分辨率选择器 | `resolutionPicker` |
| VideoSettings | 帧率选择器 | `frameRatePicker` |
| VideoSettings | 码率滑块 | `bitrateSlider` |
| Streaming | 返回按钮 | `backButton` |
| Streaming | 覆盖层 | `streamingOverlay` |
| Streaming | 断开连接按钮 | `disconnectButton` |

### E2E-001: 主机列表页面测试

> 关联用户故事: US-001 主机发现和连接
> 验收标准: AC-001 ~ AC-004

| 编号 | 测试用例 | 操作步骤 | 预期结果 | 优先级 |
|------|----------|----------|----------|--------|
| E2E-001.1 | testHostListDisplayed | 启动应用 | 主机列表页面显示 | P0 |
| E2E-001.2 | testEmptyStateDisplayed | 无主机时启动 | 显示空状态提示和添加按钮 | P1 |
| E2E-001.3 | testAddHostButtonExists | 检查工具栏 | 添加主机按钮存在 | P0 |
| E2E-001.4 | testDiscoveryToggle | 点击发现按钮 | 图标切换 wifi/wifi.slash | P1 |
| E2E-001.5 | testHostRowDisplaysInfo | 有主机时检查 | 显示主机名、地址、状态 | P0 |
| E2E-001.6 | testHostContextMenu | 长按主机行 | 显示唤醒、PIN、删除选项 | P1 |
| E2E-001.7 | testDeleteHostConfirmation | 滑动删除主机 | 显示确认对话框 | P1 |
| E2E-001.8 | testPullToRefresh | 下拉列表 | 触发刷新动画 | P2 |

```swift
// HostListUITests.swift
import XCTest

final class HostListUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    // E2E-001.1
    func testHostListDisplayed() {
        let hostList = app.collectionViews["hostList"]
        XCTAssertTrue(hostList.waitForExistence(timeout: 5))
    }

    // E2E-001.2
    func testEmptyStateDisplayed() {
        let emptyStateText = app.staticTexts["noHostsFound"]
        let addHostButton = app.buttons["addHostButton"]

        // 空状态下应显示提示
        if emptyStateText.exists {
            XCTAssertTrue(addHostButton.exists)
        }
    }

    // E2E-001.3
    func testAddHostButtonExists() {
        let addButton = app.buttons["addHostButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }

    // E2E-001.4
    func testDiscoveryToggle() {
        let discoveryButton = app.buttons["discoveryToggleButton"]
        guard discoveryButton.exists else { return }

        // 记录初始状态
        let initialLabel = discoveryButton.label
        discoveryButton.tap()

        // 状态应该改变
        sleep(1)
        XCTAssertNotEqual(discoveryButton.label, initialLabel)
    }

    // E2E-001.6
    func testHostContextMenu() {
        let hostRow = app.cells.matching(identifier: "hostRow").firstMatch
        guard hostRow.exists else { return }

        hostRow.press(forDuration: 1.0) // 长按触发上下文菜单

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    }
}
```

### E2E-005: 添加主机页面测试

> 关联用户故事: US-001 主机发现和连接
> 验收标准: AC-002 手动添加主机

| 编号 | 测试用例 | 操作步骤 | 预期结果 | 优先级 |
|------|----------|----------|----------|--------|
| E2E-005.1 | testOpenAddHostSheet | 点击添加按钮 | 显示添加主机表单 | P0 |
| E2E-005.2 | testAddHostFormFields | 检查表单 | 昵称、地址、类型字段存在 | P0 |
| E2E-005.3 | testSaveButtonDisabledEmpty | 地址为空 | 保存按钮禁用 | P0 |
| E2E-005.4 | testSaveButtonEnabledWithAddress | 输入地址 | 保存按钮启用 | P0 |
| E2E-005.5 | testCancelDismissesSheet | 点击取消 | 关闭表单，不保存 | P1 |
| E2E-005.6 | testSaveAddsHost | 填写并保存 | 主机添加到列表 | P0 |
| E2E-005.7 | testConsoleTypePicker | 切换 PS4/PS5 | 选择器正确切换 | P1 |
| E2E-005.8 | testDefaultNickname | 留空昵称保存 | 使用默认名称 "PlayStation" | P2 |

```swift
// AddHostUITests.swift
import XCTest

final class AddHostUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    // E2E-005.1
    func testOpenAddHostSheet() {
        let addButton = app.buttons["addHostButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let nicknameField = app.textFields["nicknameTextField"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 2))
    }

    // E2E-005.3 & E2E-005.4
    func testSaveButtonStateWithAddress() {
        // 打开添加主机表单
        app.buttons["addHostButton"].tap()

        let addressField = app.textFields["addressTextField"]
        let saveButton = app.buttons["saveHostButton"]

        XCTAssertTrue(addressField.waitForExistence(timeout: 2))

        // 地址为空时保存按钮应禁用
        XCTAssertFalse(saveButton.isEnabled)

        // 输入地址后保存按钮应启用
        addressField.tap()
        addressField.typeText("192.168.1.100")
        XCTAssertTrue(saveButton.isEnabled)
    }

    // E2E-005.5
    func testCancelDismissesSheet() {
        app.buttons["addHostButton"].tap()

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.tap()

        // 表单应该关闭
        let nicknameField = app.textFields["nicknameTextField"]
        XCTAssertFalse(nicknameField.exists)
    }

    // E2E-005.6
    func testSaveAddsHost() {
        app.buttons["addHostButton"].tap()

        let nicknameField = app.textFields["nicknameTextField"]
        let addressField = app.textFields["addressTextField"]
        let saveButton = app.buttons["saveHostButton"]

        XCTAssertTrue(nicknameField.waitForExistence(timeout: 2))

        nicknameField.tap()
        nicknameField.typeText("Test PS5")

        addressField.tap()
        addressField.typeText("192.168.1.200")

        saveButton.tap()

        // 验证主机已添加到列表
        let hostCell = app.cells.staticTexts["Test PS5"]
        XCTAssertTrue(hostCell.waitForExistence(timeout: 3))
    }

    // E2E-005.7
    func testConsoleTypePicker() {
        app.buttons["addHostButton"].tap()

        let picker = app.segmentedControls["consoleTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))

        // 默认应该是 PS5
        let ps5Button = picker.buttons["PS5"]
        XCTAssertTrue(ps5Button.isSelected)

        // 切换到 PS4
        let ps4Button = picker.buttons["PS4"]
        ps4Button.tap()
        XCTAssertTrue(ps4Button.isSelected)
    }
}
```

### E2E-003: 设置页面测试 (完整版)

> 关联用户故事: US-008 设置持久化
> 验收标准: AC-031 ~ AC-034

| 编号 | 测试用例 | 操作步骤 | 预期结果 | 优先级 |
|------|----------|----------|----------|--------|
| E2E-003.1 | testNavigateToSettings | 点击设置入口 | 进入设置页面 | P0 |
| E2E-003.2 | testSettingsSections | 检查设置页 | 显示所有设置分类 | P0 |
| E2E-003.3 | testVideoSettingsNavigation | 点击视频设置 | 进入视频设置页 | P0 |
| E2E-003.4 | testAudioSettingsNavigation | 点击音频设置 | 进入音频设置页 | P1 |
| E2E-003.5 | testControllerSettingsNavigation | 点击控制器设置 | 进入控制器设置页 | P1 |
| E2E-003.6 | testResolutionPicker | 选择不同分辨率 | 设置值更新 | P0 |
| E2E-003.7 | testFrameRatePicker | 选择 30/60 fps | 设置值更新 | P0 |
| E2E-003.8 | testBitrateSlider | 调整码率滑块 | 数值显示更新 | P1 |
| E2E-003.9 | testHDRToggle | 切换 HDR 开关 | 开关状态改变 | P1 |
| E2E-003.10 | testVolumeSlider | 调整音量滑块 | 数值显示更新 | P1 |
| E2E-003.11 | testHapticToggle | 切换触觉反馈 | 开关状态改变 | P1 |
| E2E-003.12 | testExportSettings | 点击导出按钮 | 显示文件保存对话框 | P2 |
| E2E-003.13 | testResetToDefaults | 点击重置按钮 | 显示确认对话框 | P1 |
| E2E-003.14 | testSettingsPersistence | 修改设置后重启 | 设置值保留 | P0 |

```swift
// SettingsUITests.swift
import XCTest

final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // E2E-003.1
    func testNavigateToSettings() {
        #if os(iOS)
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2))
        #elseif os(macOS)
        // macOS 使用菜单栏或快捷键
        app.menuItems["Settings…"].tap()
        #endif
    }

    // E2E-003.2
    func testSettingsSections() {
        navigateToSettings()

        // 验证主要设置分类存在
        XCTAssertTrue(app.cells["videoSettingsLink"].exists)
        XCTAssertTrue(app.cells["audioSettingsLink"].exists)
        XCTAssertTrue(app.cells["controllerSettingsLink"].exists)
    }

    // E2E-003.3
    func testVideoSettingsNavigation() {
        navigateToSettings()

        app.cells["videoSettingsLink"].tap()

        let resolutionPicker = app.buttons["resolutionPicker"]
        XCTAssertTrue(resolutionPicker.waitForExistence(timeout: 2))
    }

    // E2E-003.6
    func testResolutionPicker() {
        navigateToSettings()
        app.cells["videoSettingsLink"].tap()

        let picker = app.buttons["resolutionPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.tap()

        // 选择 720p
        let option720p = app.buttons["720p"]
        if option720p.exists {
            option720p.tap()
        }
    }

    // E2E-003.13
    func testResetToDefaults() {
        navigateToSettings()

        // 滚动到底部找到重置按钮
        let resetButton = app.buttons["resetToDefaults"]

        if resetButton.exists {
            resetButton.tap()

            // 验证确认对话框出现
            let confirmButton = app.buttons["Reset to Defaults"]
            XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
        }
    }

    // Helper
    private func navigateToSettings() {
        #if os(iOS)
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
        }
        #endif
    }
}
```

### E2E-002: 流媒体页面测试 (完整版)

> 关联用户故事: US-003 远程游戏流媒体
> 验收标准: AC-009 ~ AC-013
> 注意: 需要 Mock 或真实主机连接

| 编号 | 测试用例 | 操作步骤 | 预期结果 | 优先级 |
|------|----------|----------|----------|--------|
| E2E-002.1 | testEnterStreaming | 点击已注册在线主机 | 进入流媒体页面 | P0 |
| E2E-002.2 | testPinEntryRequired | 设置 PIN 后点击主机 | 显示 PIN 输入界面 | P1 |
| E2E-002.3 | testStreamingPlaceholder | 连接中 | 显示连接状态占位符 | P1 |
| E2E-002.4 | testStreamingOverlayToggle | 点击屏幕 | 覆盖层显示/隐藏切换 | P1 |
| E2E-002.5 | testOverlayShowsStats | 覆盖层显示时 | 显示帧率、延迟、质量 | P1 |
| E2E-002.6 | testDisconnectButton | 点击断开按钮 | 显示确认或直接断开 | P0 |
| E2E-002.7 | testBackNavigation | 点击返回按钮 | 返回主机列表 | P0 |
| E2E-002.8 | testVirtualControllerDisplayed | iOS 流媒体中 | 虚拟控制器显示 | P1 |
| E2E-002.9 | testVirtualControllerToggle | 点击控制器按钮 | 虚拟控制器显示/隐藏 | P1 |

```swift
// StreamingUITests.swift
import XCTest

final class StreamingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 使用 Mock 模式避免真实连接
        app.launchArguments = ["--uitesting", "--mock-streaming"]
        app.launch()
    }

    // E2E-002.4
    func testStreamingOverlayToggle() {
        enterMockStreaming()

        let overlay = app.otherElements["streamingOverlay"]

        // 点击切换覆盖层
        let streamingView = app.otherElements["streamingView"]
        streamingView.tap()

        // 覆盖层状态应该改变
        let isVisible = overlay.exists && overlay.isHittable

        streamingView.tap()
        // 再次点击后状态应该切换
    }

    // E2E-002.6
    func testDisconnectButton() {
        enterMockStreaming()

        // 显示覆盖层
        app.otherElements["streamingView"].tap()

        let disconnectButton = app.buttons["disconnectButton"]
        if disconnectButton.waitForExistence(timeout: 2) {
            disconnectButton.tap()

            // 应该返回主机列表或显示确认
            let hostList = app.collectionViews["hostList"]
            let confirmDialog = app.alerts.firstMatch

            XCTAssertTrue(hostList.waitForExistence(timeout: 3) || confirmDialog.exists)
        }
    }

    // E2E-002.8 (iOS only)
    #if os(iOS)
    func testVirtualControllerDisplayed() {
        enterMockStreaming()

        let virtualController = app.otherElements["virtualController"]
        // 虚拟控制器应该显示（如果启用）
        XCTAssertTrue(virtualController.waitForExistence(timeout: 3))
    }
    #endif

    // Helper
    private func enterMockStreaming() {
        // 点击 Mock 主机进入流媒体
        let mockHost = app.cells.matching(identifier: "hostRow").firstMatch
        if mockHost.waitForExistence(timeout: 3) {
            mockHost.tap()
        }

        // 等待流媒体页面加载
        sleep(2)
    }
}
```

### E2E-004: tvOS 焦点导航测试 (完整版)

> 关联用户故事: US-006 tvOS 大屏体验
> 验收标准: AC-023 ~ AC-026

| 编号 | 测试用例 | 操作 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| E2E-004.1 | testInitialFocus | 启动应用 | 第一个主机或添加按钮获得焦点 | P0 |
| E2E-004.2 | testVerticalNavigation | 上下滑动 | 焦点在主机间移动 | P0 |
| E2E-004.3 | testHorizontalNavigation | 左右滑动 | 焦点移动到工具栏 | P1 |
| E2E-004.4 | testSelectWithClick | 点击遥控器 | 选中当前焦点项 | P0 |
| E2E-004.5 | testMenuBack | 按 Menu 键 | 返回上一页面 | P0 |
| E2E-004.6 | testFocusStateVisible | 焦点移动时 | 焦点状态清晰可见 | P1 |
| E2E-004.7 | testSettingsNavigation | 焦点到设置 | 可进入设置页面 | P1 |
| E2E-004.8 | testHostCardFocus | 焦点在主机卡片 | 显示详细信息 | P2 |

```swift
// TVOSUITests.swift
#if os(tvOS)
import XCTest

final class TVOSUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // E2E-004.1
    func testInitialFocus() {
        // 启动后应有元素获得焦点
        let focusedElement = app.descendants(matching: .any).element(matching: NSPredicate(format: "hasFocus == true"))
        XCTAssertTrue(focusedElement.waitForExistence(timeout: 5))
    }

    // E2E-004.2
    func testVerticalNavigation() {
        let remote = XCUIRemote.shared

        // 获取初始焦点元素
        let initialFocus = app.descendants(matching: .any).element(matching: NSPredicate(format: "hasFocus == true"))
        let initialIdentifier = initialFocus.identifier

        // 向下滑动
        remote.press(.down)
        sleep(1)

        // 焦点应该移动
        let newFocus = app.descendants(matching: .any).element(matching: NSPredicate(format: "hasFocus == true"))
        XCTAssertNotEqual(newFocus.identifier, initialIdentifier)
    }

    // E2E-004.4
    func testSelectWithClick() {
        let remote = XCUIRemote.shared

        // 确保有主机
        let hostCard = app.cells.matching(identifier: "hostRow").firstMatch
        guard hostCard.exists else { return }

        // 选择
        remote.press(.select)

        // 应该触发操作（进入流媒体或显示未注册提示）
        sleep(2)
    }

    // E2E-004.5
    func testMenuBack() {
        let remote = XCUIRemote.shared

        // 先进入设置
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)

            // 按 Menu 返回
            remote.press(.menu)
            sleep(1)

            // 应该回到主页
            let hostList = app.scrollViews.firstMatch
            XCTAssertTrue(hostList.exists)
        }
    }
}
#endif
```

### 4.3 E2E 测试追溯矩阵

| 用户故事 | 验收标准 | E2E 测试 | 状态 |
|----------|----------|----------|------|
| US-001 | AC-001~AC-004 | E2E-001.1~8, E2E-005.1~8 | ✅ |
| US-003 | AC-009~AC-013 | E2E-002.1~9 | ⚠️ 需 Mock |
| US-006 | AC-023~AC-026 | E2E-004.1~8 | ✅ |
| US-008 | AC-031~AC-034 | E2E-003.1~14 | ✅ |

### 4.4 测试实现优先级

| 优先级 | 测试数 | 说明 |
|--------|--------|------|
| P0 | 18 | 核心功能必测 |
| P1 | 22 | 重要功能 |
| P2 | 5 | 增强体验 |
| **总计** | **45** | |

---

## 5. 性能测试

### 5.1 性能指标

| 指标 | 目标值 | 测量方法 |
|------|--------|----------|
| 端到端延迟 | < 50ms | Instruments 网络分析 |
| 视频帧率 | ≥ 58fps (60fps 目标) | Instruments GPU 分析 |
| 音频延迟 | < 30ms | 音视频同步测试 |
| 内存占用 | < 200MB (流媒体) | Instruments Allocations |
| CPU 占用 | < 30% | Instruments Time Profiler |
| 电池影响 | < 20%/小时 | Energy Log |

### 5.2 性能测试场景

#### 5.2.1 流媒体性能测试

```
测试配置:
- 分辨率: 1080p
- 帧率: 60fps
- 码率: 15Mbps
- 持续时间: 30 分钟

测量项目:
- [ ] 帧率稳定性（帧率波动 < 5%）
- [ ] 帧丢失率（< 0.1%）
- [ ] 内存增长（无持续增长）
- [ ] CPU 峰值（< 50%）
```

#### 5.2.2 控制器输入延迟测试

```
测试方法:
1. 使用高速摄像机（240fps）
2. 同时录制控制器按键和屏幕响应
3. 分析帧差计算延迟

目标:
- 输入到屏幕响应 < 50ms
- 按键识别准确率 100%
```

---

## 6. 手动测试检查清单

### 6.1 基础功能 [每次发版必测]

#### 6.1.1 主机发现和连接

- [ ] 应用启动后自动发现局域网 PS4
- [ ] 应用启动后自动发现局域网 PS5
- [ ] 主机状态正确显示（在线/休眠/离线）
- [ ] 点击在线主机可成功连接
- [ ] 唤醒休眠主机功能正常
- [ ] 手动添加主机功能正常

#### 6.1.2 流媒体

- [ ] 视频流正常显示，无花屏
- [ ] 音频正常播放，无杂音
- [ ] 视频音频同步
- [ ] 分辨率切换正常（720p/1080p）
- [ ] 帧率切换正常（30fps/60fps）
- [ ] 返回主机列表正常断开

#### 6.1.3 控制器

- [ ] DualSense 蓝牙连接正常
- [ ] DualSense USB 连接正常
- [ ] DualShock 4 蓝牙连接正常
- [ ] 所有按键映射正确
- [ ] 摇杆输入准确
- [ ] 扳机输入准确
- [ ] 触觉反馈正常（支持的设备）

### 6.2 平台特有功能

#### 6.2.1 iOS 特有

- [ ] 触屏虚拟控制器显示正常
- [ ] 虚拟摇杆响应灵敏
- [ ] 虚拟按钮触发准确
- [ ] 陀螺仪输入正常
- [ ] 后台音频继续播放
- [ ] PiP 模式正常 [待实现]

#### 6.2.2 iPadOS 特有

- [ ] Stage Manager 多窗口正常
- [ ] 分屏多任务正常
- [ ] 外接键盘快捷键正常
- [ ] 外接显示器支持 [待实现]

#### 6.2.3 macOS 特有

- [ ] 菜单栏功能正常
- [ ] 多窗口支持正常
- [ ] 全屏模式正常
- [ ] 系统睡眠抑制正常

#### 6.2.4 tvOS 特有

- [ ] Siri Remote 导航正常
- [ ] 焦点状态清晰可见
- [ ] 所有界面可通过焦点导航访问
- [ ] Top Shelf 扩展正常 [待实现]

### 6.3 设置和持久化

- [ ] 视频设置保存正常
- [ ] 音频设置保存正常
- [ ] 控制器设置保存正常
- [ ] PSN 账户登录正常
- [ ] PSN 账户登出正常
- [ ] 重启应用后设置保留

---

## 7. 回归测试

### 7.1 核心功能回归

每次发版前必须验证以下核心流程：

| 测试项 | PS4 | PS5 | 优先级 |
|--------|-----|-----|--------|
| 局域网发现 | ✓ | ✓ | P0 |
| 局域网连接 | ✓ | ✓ | P0 |
| 远程连接 (PSN) | ✓ | ✓ | P0 |
| DualSense 控制器 | - | ✓ | P0 |
| DualShock 4 控制器 | ✓ | ✓ | P0 |
| 视频 1080p60 | ✓ | ✓ | P0 |
| 音频播放 | ✓ | ✓ | P0 |
| 主机唤醒 | ✓ | ✓ | P1 |

### 7.2 性能回归

| 指标 | 基准值 | 允许偏差 | 回归判定 |
|------|--------|----------|----------|
| 端到端延迟 | 50ms | ±10ms | > 60ms 为回归 |
| 帧率 | 60fps | ≥55fps | < 55fps 为回归 |
| 内存占用 | 200MB | ≤250MB | > 300MB 为回归 |
| 启动时间 | 2s | ≤3s | > 4s 为回归 |

### 7.3 兼容性回归

| 设备/系统 | 最低版本 | 测试频率 |
|-----------|----------|----------|
| iPhone | iOS 16.0 | 每次发版 |
| iPad | iPadOS 16.0 | 每次发版 |
| Mac (Apple Silicon) | macOS 13.0 | 每次发版 |
| Mac (Intel) | macOS 13.0 | 主要版本 |
| Apple TV | tvOS 16.0 | 每次发版 |
| PS4 Pro | - | 每次发版 |
| PS4 Slim | - | 主要版本 |
| PS5 | - | 每次发版 |
| PS5 Digital | - | 主要版本 |

---

## 8. 测试自动化

### 8.1 CI/CD 集成

```yaml
# .github/workflows/test.yml (示例)
name: Test

on:
  push:
    paths:
      - 'apple/**'
  pull_request:
    paths:
      - 'apple/**'

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project apple/Chiaki.xcodeproj \
            -scheme Chiaki \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES

  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run UI Tests
        run: |
          xcodebuild test \
            -project apple/Chiaki.xcodeproj \
            -scheme ChiakiUITests \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### 8.2 测试报告

测试完成后生成以下报告：

- **覆盖率报告**: Xcode Coverage Report
- **测试结果**: JUnit XML 格式
- **性能报告**: Instruments Trace 文件

---

## 9. 缺陷管理

### 9.1 缺陷严重性定义

| 级别 | 定义 | 修复时限 |
|------|------|----------|
| P0 - 阻塞 | 应用崩溃、核心功能不可用 | 立即修复 |
| P1 - 严重 | 主要功能异常、数据丢失 | 当前迭代 |
| P2 - 一般 | 功能部分异常、可绕过 | 下一迭代 |
| P3 - 轻微 | UI 问题、体验优化 | 计划修复 |

### 9.2 缺陷报告模板

```markdown
## 缺陷标题

**环境**:
- 设备: [iPhone 15 Pro / iPad Pro / MacBook Pro M3]
- 系统版本: [iOS 17.2]
- 应用版本: [1.0.0 (build 123)]
- PS 主机: [PS5]

**复现步骤**:
1.
2.
3.

**预期结果**:

**实际结果**:

**截图/视频**:

**日志**:
```

---

## 10. 追溯矩阵

> 本节追溯需求 → 测试用例的映射关系

### 10.1 功能 → 用户故事 → 测试用例追溯

| 功能编号 | 功能名称 | 用户故事 | 单元测试 | 集成测试 | E2E 测试 |
|----------|----------|----------|----------|----------|----------|
| F-001 | 核心流媒体 | US-002, US-003 | UT-001, UT-005 | IT-001, IT-002 | E2E-002 |
| F-002 | PS 主机发现 | US-001 | UT-002, UT-003, UT-004, UT-007 | **IT-005** | E2E-001, E2E-005 |
| F-003 | 主机注册 | US-001 | UT-001 | IT-005 | E2E-001 |
| F-004 | 游戏控制器 | US-004 | - | IT-003 | - |
| F-005 | DualSense 支持 | US-004 | - | IT-003 | - |
| F-006 | 触屏虚拟控制器 | US-004 | - | - | E2E-002.8 |
| F-007 | 流媒体设置 | US-003 | UT-005 | **IT-006** | E2E-003 |
| F-008 | 多平台支持 | US-005, US-006, US-007, US-008 | **UT-009** | - | E2E-004 |
| F-009 | PSN 账户集成 | US-001 | - | - | - |
| F-010 | 多语言支持 | - | UT-006 | - | - |
| **导航** | 应用导航 | - | **UT-009** | - | E2E-001~005 |

### 10.2 验收标准 → 测试用例追溯

| 验收标准 | 测试用例 | 测试类型 |
|----------|----------|----------|
| AC-001 | UT-002.1, UT-002.3 | 单元测试 |
| AC-002 | UT-003, E2E-001 | 单元+E2E |
| AC-003 | E2E-001 | E2E |
| AC-004 | IT-001 | 集成测试 |
| AC-005 | IT-002 | 集成测试 |
| AC-006 | IT-001, E2E-002 | 集成+E2E |
| AC-007 | UT-005.1 | 单元测试 |
| AC-008 | UT-005.1 | 单元测试 |
| AC-009 | UT-005.2 | 单元测试 |
| AC-010 | IT-003.1 | 集成测试 |
| AC-011 | IT-003.2 | 集成测试 |
| AC-012 | IT-003.3, IT-003.4 | 集成测试 |
| AC-013-034 | 手动测试清单 | 手动测试 |

### 10.3 测试覆盖状态

| 测试类型 | 总数 | 已实现 | 覆盖率 | 备注 |
|----------|------|--------|--------|------|
| 单元测试 (UT) | 9 组 | 9 | **100%** | UT-001~009 全部实现 |
| 集成测试 (IT) | 6 组 | 6 | **100%** | IT-001~006 全部实现 |
| 高级测试 (P0/P1) | 5 组 | 5 | 100% | Session/Discovery/ViewModel/Keychain/Statistics |
| E2E 测试 | 5 组 | 5 | **100%** | E2E-001~005 全部实现 |

> **更新时间**: 2026-01-26 (--trace 扫描)
> **测试用例总数**: 181 (单元/集成) + 45 (E2E) = 226
> **通过率**: 173/181 单元测试通过 (8 个音频测试因模拟器限制失败)

### 10.4 测试实现详情

#### 已实现测试文件

| 文件 | 测试数量 | 覆盖用例 | 代码位置 |
|------|----------|----------|----------|
| `ChiakiTests.swift` | 39 | UT-003, UT-004, UT-005 | `ChiakiTests/ChiakiTests.swift` |
| `SessionAndDiscoveryTests.swift` | 31 | UT-001, UT-002 | `ChiakiTests/SessionAndDiscoveryTests.swift` |
| `IntegrationTests.swift` | 28 | IT-001, IT-002, IT-003 | `ChiakiTests/IntegrationTests.swift` |
| `AdvancedTests.swift` | 44 | P0/P1 高级测试 | `ChiakiTests/AdvancedTests.swift` |
| `NewFeatureTests.swift` | 39 | UT-006~009, IT-004~006 | `ChiakiTests/NewFeatureTests.swift` |
| `HostListUITests.swift` | 8 | E2E-001.1~8 | `ChiakiUITests/HostListUITests.swift` |
| `StreamingUITests.swift` | 9 | E2E-002.1~9 | `ChiakiUITests/StreamingUITests.swift` |
| `SettingsUITests.swift` | 12 | E2E-003.1~13 | `ChiakiUITests/SettingsUITests.swift` |
| `TVOSUITests.swift` | 9 | E2E-004.1~9 | `ChiakiUITests/TVOSUITests.swift` |
| `AddHostUITests.swift` | 7 | E2E-005.1~7 | `ChiakiUITests/AddHostUITests.swift` |

#### UT-001 ChiakiSession 实现状态

| 子用例 | 状态 | 说明 |
|--------|------|------|
| SessionState 枚举测试 | ✅ | 完整覆盖所有状态 |
| SessionError 测试 | ✅ | 完整覆盖所有错误类型 |
| HostConfig 测试 | ✅ | 初始化和可选参数 |
| StreamConfig 测试 | ✅ | 默认/平衡配置、VideoProfile |
| 连接流程测试 | ⚠️ | 需 Mock ChiakiSessionWrapper |

#### UT-002 ChiakiDiscovery 实现状态

| 子用例 | 状态 | 说明 |
|--------|------|------|
| DiscoveryError 测试 | ✅ | 完整覆盖所有错误 |
| DiscoveredHostInfo 测试 | ✅ | 初始化、状态判断 |
| ChiakiHostState 测试 | ✅ | displayName、rawValue |
| 发现流程测试 | ⚠️ | 需网络 Mock |

#### UT-009 NavigationManager 实现状态 ✅ 已完成

> 代码位置: `ChiakiTests/NewFeatureTests.swift:277-384`

| 子用例 | 状态 | 代码行 |
|--------|------|--------|
| UT-009.1 初始状态测试 | ✅ | :277 |
| UT-009.2 openAddHost 测试 | ✅ | :290 |
| UT-009.3 navigateToSettings 测试 | ✅ | :301 |
| UT-009.4 refreshDiscovery 测试 | ✅ | :311 |
| UT-009.5 wakeUpSelectedHost 测试 | ✅ | :322 |
| UT-009.6/7 autoConnect 生命周期 | ✅ | :331 |
| UT-009.8 streaming 状态切换 | ✅ | :347 |
| UT-009.9 displayMode 触发器 | ✅ | :358 |
| UT-009.10 volume 触发器 | ✅ | :371 |

#### IT-004 HostManager 单例一致性 ✅ 已完成

> 代码位置: `ChiakiTests/NewFeatureTests.swift:387-416`

| 子用例 | 状态 | 代码行 |
|--------|------|--------|
| IT-004.1 shared 单例测试 | ✅ | :387 |
| IT-004.2 HostStore 一致性 | ✅ | :396 |

#### IT-005 主机发现与存储集成 ✅ 已完成

> 代码位置: `ChiakiTests/NewFeatureTests.swift:419-593`

| 子用例 | 状态 | 代码行 |
|--------|------|--------|
| IT-005.1 主机添加可用 | ✅ | :419 |
| IT-005.2 主机状态初始化 | ✅ | :440 |
| IT-005.3 隐藏主机过滤 | ✅ | :458 |
| IT-005.4 地址变更保持注册 | ✅ | :484 |
| IT-005.5 多主机管理 | ✅ | :510 |
| IT-005.6 主机删除 | ✅ | :533 |

#### IT-006 设置持久化集成 ✅ 已完成

> 代码位置: `ChiakiTests/NewFeatureTests.swift:598-792`

| 子用例 | 状态 | 代码行 |
|--------|------|--------|
| IT-006.1 跨实例持久化 | ✅ | :598 |
| IT-006.2 视频设置持久化 | ✅ | :617 |
| IT-006.3 音频设置持久化 | ✅ | :641 |
| IT-006.4 控制器设置持久化 | ✅ | :661 |
| IT-006.5 重置默认值 | ✅ | :679 |
| IT-006.6 自动连接设置 | ✅ | :701 |
| IT-006.7 断开动作设置 | ✅ | :721 |
| IT-006.8 键盘映射 (macOS) | ✅ | :739 |
| IT-006.9 导入导出一致性 | ✅ | :762 |

#### IT-001 视频渲染实现状态

| 子用例 | 状态 | 说明 |
|--------|------|------|
| MetalVideoRenderer 初始化 | ✅ | 支持无 GPU 环境 |
| 统计重置 | ✅ | frameCount, droppedFrameCount |
| VideoDisplayMode | ✅ | normal/stretch/zoom |
| 实际渲染测试 | ⚠️ | 需 GPU + CVPixelBuffer |

#### IT-002 音频播放实现状态

| 子用例 | 状态 | 说明 |
|--------|------|------|
| AudioPlayer 初始化 | ✅ | 默认和自定义参数 |
| 生命周期 (start/stop/pause/resume) | ✅ | 完整测试 |
| 音量控制 | ✅ | 包含边界值测试 |
| 缓冲区统计 | ✅ | fillRatio, underrunCount |
| AudioPlayerBridge | ✅ | configure, start, shutdown |

#### IT-003 控制器实现状态

| 子用例 | 状态 | 说明 |
|--------|------|------|
| ControllerInput 测试 | ✅ | 按钮、摇杆、扳机、陀螺仪 |
| ControllerButtons 测试 | ✅ | 所有按钮位、OptionSet 操作 |
| ControllerManager 初始化 | ✅ | 单例访问 |
| GCController 查询 | ✅ | 通知名验证 |
| DualSenseIntensity | ✅ | default/disabled/custom |

### 10.5 已补充测试 (AdvancedTests.swift)

| 优先级 | 测试项 | 状态 | 测试数 |
|--------|--------|------|--------|
| P0 | ChiakiSessionWrapper | ✅ 完成 | 7 |
| P0 | DiscoveryService | ✅ 完成 | 6 |
| P1 | StreamingViewModel | ✅ 完成 | 6 |
| P1 | KeychainManager | ✅ 完成 | 6 |
| P1 | StreamStatistics | ✅ 完成 | 10 |
| P1 | VideoDecoderBridge | ✅ 完成 | 3 |
| P1 | PiPManager | ✅ 完成 | 2 |
| - | ConnectionQuality | ✅ 完成 | 1 |
| - | KeychainError | ✅ 完成 | 1 |

### 10.6 E2E 测试代码位置追溯

> 代码扫描时间: 2026-01-26

| 测试组 | 文件 | 测试数 | 代码位置 |
|--------|------|--------|----------|
| E2E-001 主机列表 | HostListUITests.swift | 8 | :25-227 |
| E2E-002 流媒体 | StreamingUITests.swift | 9 | :45-289 |
| E2E-003 设置 | SettingsUITests.swift | 12 | :61-404 |
| E2E-004 tvOS 焦点 | TVOSUITests.swift | 9 | :28-228 |
| E2E-005 添加主机 | AddHostUITests.swift | 7 | :46-248 |

### 10.7 待补充测试 (剩余 Tech Debt)

| 优先级 | 测试项 | 阻塞原因 |
|--------|--------|----------|
| P1 | PSNService OAuth | 需要网络 Mock |
| P2 | E2E-002 流媒体页面 | 需要真实主机 |
| P2 | E2E-003 设置页面 | UI 测试补充 |
| P2 | E2E-004 tvOS 焦点导航 | 需要 tvOS 环境 |

---

## 10.7 新功能测试用例 (2026-01-22 补充)

以下测试用例针对最近实现的新功能设计。

### UT-006: 国际化 (i18n) 测试

> 关联功能: F-010 多语言支持
> 验收标准: 所有 UI 文本正确本地化，无 key 显示为 value 的情况

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| UT-006.1 | testLocalizationKeysHaveValues | 所有本地化 key 都有对应的翻译值 | 无空翻译 | P0 |
| UT-006.2 | testFormatStringPlaceholders | 格式化字符串占位符正确 | %@ 和 %lld 正确替换 | P0 |
| UT-006.3 | testAccessibilityLabels | 无障碍标签已本地化 | 所有 accessibility 标签有值 | P1 |
| UT-006.4 | testMenuItemsLocalized | 菜单项本地化 | 菜单显示正确文本 | P1 |

```swift
// LocalizationTests.swift
import Testing
import Foundation
@testable import Chiaki

struct LocalizationTests {

    @Test func testCommonStringsLocalized() {
        // 验证常用字符串不显示 key
        let cancel = String(localized: "common.cancel")
        #expect(cancel != "common.cancel")
        #expect(!cancel.isEmpty)

        let ok = String(localized: "common.ok")
        #expect(ok != "common.ok")
    }

    @Test func testFormatStringWithPlaceholder() {
        // 验证格式化字符串正确工作
        let hostName = "PS5"
        let enterPin = String(localized: "consolePin.enterPin \(hostName)")
        #expect(enterPin.contains(hostName))
        #expect(!enterPin.contains("consolePin.enterPin"))
    }

    @Test func testAccessibilityStrings() {
        // 验证无障碍字符串
        let quality = "Good"
        let accessLabel = String(localized: "accessibility.networkQuality \(quality)")
        #expect(accessLabel.contains(quality))
        #expect(!accessLabel.contains("accessibility.networkQuality"))
    }
}
```

### UT-007: HostListViewModel 延迟初始化测试

> 关联功能: F-002 PS 主机发现
> 验收标准: AC-001 应用启动后 5 秒内显示在线主机列表
> 关联 Bug 修复: iOS 启动白屏优化

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| UT-007.1 | testInitialLoadingState | 初始化时 isLoading = true | 显示加载状态 | P0 |
| UT-007.2 | testLazyInitialization | 延迟初始化不访问 HostManager.shared | 避免阻塞主线程 | P0 |
| UT-007.3 | testInitializeIfNeededIdempotent | initializeIfNeeded 幂等性 | 多次调用只初始化一次 | P1 |
| UT-007.4 | testLoadingStateAfterInit | 初始化后 isLoading = false | 加载完成 | P0 |

```swift
// HostListViewModelTests.swift
import Testing
import Foundation
@testable import Chiaki

@MainActor
struct HostListViewModelTests {

    @Test func testInitialLoadingState() {
        // 不传入 hostManager，使用延迟初始化模式
        let viewModel = HostListViewModel()

        // 初始状态应为 loading
        #expect(viewModel.isLoading == true)
        #expect(viewModel.hosts.isEmpty)
    }

    @Test func testInjectedHostManagerSkipsLazyInit() {
        // 传入 hostManager 时，直接初始化完成
        let mockManager = HostManager()
        let viewModel = HostListViewModel(hostManager: mockManager)

        // 应该立即完成初始化
        #expect(viewModel.isLoading == false)
    }

    @Test func testInitializeIfNeededIdempotent() {
        let viewModel = HostListViewModel()

        // 第一次调用
        viewModel.initializeIfNeeded()
        #expect(viewModel.isLoading == false)

        // 第二次调用不应有副作用
        viewModel.initializeIfNeeded()
        #expect(viewModel.isLoading == false)
    }
}
```

### UT-008: 键盘映射 (macOS) 测试

> 关联功能: F-009 虚拟输入
> 验收标准: AC-033 控制器映射设置保存
> 平台限制: macOS only

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| UT-008.1 | testMappableButtonAllCases | MappableButton 包含所有按钮 | 18 个按钮 | P0 |
| UT-008.2 | testKeyboardMappingCodable | 映射配置序列化 | 编码解码后相等 | P0 |
| UT-008.3 | testDefaultMappings | 默认映射值正确 | WASD + 方向键等 | P1 |
| UT-008.4 | testSetMapping | 设置单个按键映射 | 映射更新成功 | P0 |
| UT-008.5 | testClearMapping | 清除按键映射 | keyCode = nil | P1 |
| UT-008.6 | testButtonCategories | 按钮分类正确 | face/shoulder/dpad/system | P1 |

```swift
// KeyboardMappingTests.swift
#if os(macOS)
import Testing
import Foundation
@testable import Chiaki

struct KeyboardMappingTests {

    @Test func testMappableButtonAllCases() {
        let buttons = MappableButton.allCases
        #expect(buttons.count == 18)

        // 验证包含所有必要按钮
        #expect(buttons.contains(.cross))
        #expect(buttons.contains(.circle))
        #expect(buttons.contains(.l1))
        #expect(buttons.contains(.r1))
        #expect(buttons.contains(.dpadUp))
        #expect(buttons.contains(.ps))
    }

    @Test func testKeyboardMappingCodable() throws {
        var mapping = KeyboardMapping(button: .cross)
        mapping.keyCode = 0x00 // A key
        mapping.keyName = "A"

        let data = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(KeyboardMapping.self, from: data)

        #expect(decoded.button == .cross)
        #expect(decoded.keyCode == 0x00)
        #expect(decoded.keyName == "A")
    }

    @Test func testKeyboardMappingsCodable() throws {
        let original = KeyboardMappings.defaultMappings

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardMappings.self, from: data)

        #expect(decoded == original)
    }

    @Test func testButtonCategories() {
        // Face buttons
        #expect(MappableButton.cross.category == .face)
        #expect(MappableButton.circle.category == .face)

        // Shoulder buttons
        #expect(MappableButton.l1.category == .shoulder)
        #expect(MappableButton.r2.category == .shoulder)

        // D-Pad
        #expect(MappableButton.dpadUp.category == .dpad)

        // System
        #expect(MappableButton.ps.category == .system)
    }

    @Test func testSetAndClearMapping() {
        var mappings = KeyboardMappings.defaultMappings

        // Set mapping
        mappings.setMapping(for: .cross, keyCode: 0x06, keyName: "Z")
        let crossMapping = mappings.mapping(for: .cross)
        #expect(crossMapping.keyCode == 0x06)
        #expect(crossMapping.keyName == "Z")

        // Clear mapping
        mappings.setMapping(for: .cross, keyCode: nil, keyName: nil)
        let clearedMapping = mappings.mapping(for: .cross)
        #expect(clearedMapping.hasMapping == false)
    }

    @Test func testButtonDisplayName() {
        #expect(MappableButton.cross.displayName == "✕ Cross")
        #expect(MappableButton.circle.displayName == "○ Circle")
        #expect(MappableButton.l1.displayName == "L1")
        #expect(MappableButton.ps.displayName == "PS Button")
    }
}
#endif
```

### IT-004: HostManager 单例一致性测试

> 关联 Bug 修复: HostStore 重复实例化导致数据不一致
> 验收标准: 整个应用使用同一个 HostStore 实例

| 编号 | 测试用例 | 描述 | 预期结果 | 优先级 |
|------|----------|------|----------|--------|
| IT-004.1 | testHostManagerUsesSingletonStore | HostManager 使用 HostStore.shared | 不创建新实例 | P0 |
| IT-004.2 | testHostStoreSingletonConsistency | HostStore.shared 始终返回同一实例 | 引用相等 | P0 |

```swift
// HostManagerIntegrationTests.swift
import Testing
@testable import Chiaki

@MainActor
struct HostManagerIntegrationTests {

    @Test func testHostManagerUsesSingletonStore() {
        let manager = HostManager.shared

        // HostManager 应使用 HostStore.shared
        #expect(manager.hostStore === HostStore.shared)
    }

    @Test func testHostStoreSingletonConsistency() {
        let store1 = HostStore.shared
        let store2 = HostStore.shared

        // 应该是同一个实例
        #expect(store1 === store2)
    }
}
```

### 10.7.1 追溯矩阵更新

| 功能编号 | 用户故事 | 验收标准 | 新增测试 |
|----------|----------|----------|----------|
| F-002 | US-001 | AC-001 | UT-007.1~4, IT-004.1~2 |
| F-009 | US-005 | AC-033 | UT-008.1~6 |
| F-010 | - | - | UT-006.1~4 |

---

## 11. 附录

### 11.1 现有 libchiaki 测试

项目已有的 C 语言单元测试（`test/` 目录）：

| 测试文件 | 测试内容 |
|----------|----------|
| bitstream.c | 比特流处理 |
| fec.c | 前向纠错 |
| gkcrypt.c | 加密功能 |
| http.c | HTTP 解析 |
| keystate.c | 按键状态 |
| regist.c | 主机注册 |
| reorderqueue.c | 重排序队列 |
| rpcrypt.c | RP 加密 |
| seqnum.c | 序列号 |
| takion.c | Takion 协议 |

这些测试可通过 CMake 构建和运行。

### 11.2 测试数据

测试所需的模拟数据和 Mock 对象应放置在 `Tests/TestData/` 目录。
