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

---

## 4. UI 自动化测试

### E2E-001: 主机列表页面测试

```swift
// HostListUITests.swift
import XCUITest

final class HostListUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testHostListDisplayed() {
        // 验证主机列表可见
        let hostList = app.collectionViews["hostList"]
        XCTAssertTrue(hostList.exists)
    }

    func testAddHostButton() {
        // 点击添加主机按钮
        let addButton = app.buttons["addHost"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        // 验证添加主机表单显示
        let nicknameField = app.textFields["nickname"]
        XCTAssertTrue(nicknameField.exists)
    }

    func testHostRowContent() {
        // 验证主机行包含必要信息
        let hostRow = app.cells.firstMatch
        XCTAssertTrue(hostRow.staticTexts["hostName"].exists)
        XCTAssertTrue(hostRow.staticTexts["hostAddress"].exists)
        XCTAssertTrue(hostRow.images["statusIcon"].exists)
    }
}
```

### E2E-002: 流媒体页面测试

| 编号 | 测试用例 | 步骤 | 预期结果 |
|------|----------|------|----------|
| E2E-002.1 | testEnterStreaming | 点击在线主机 | 进入流媒体页面 |
| E2E-002.2 | testStreamingOverlay | 流媒体中等待 | 显示状态覆盖层 |
| E2E-002.3 | testExitStreaming | 点击返回按钮 | 返回主机列表 |
| E2E-002.4 | testOverlayToggle | 点击屏幕中心 | 覆盖层显示/隐藏 |

### E2E-003: 设置页面测试

| 编号 | 测试用例 | 步骤 | 预期结果 |
|------|----------|------|----------|
| E2E-003.1 | testNavigateToSettings | 点击设置按钮 | 进入设置页面 |
| E2E-003.2 | testResolutionPicker | 选择分辨率 | 设置保存 |
| E2E-003.3 | testFrameRatePicker | 选择帧率 | 设置保存 |
| E2E-003.4 | testHapticToggle | 切换触觉反馈 | 开关状态改变 |

### E2E-004: tvOS 焦点导航测试

| 编号 | 测试用例 | 操作 | 预期结果 |
|------|----------|------|----------|
| E2E-004.1 | testInitialFocus | 启动应用 | 第一个主机获得焦点 |
| E2E-004.2 | testDownNavigation | Siri Remote 下滑 | 焦点移动到下一主机 |
| E2E-004.3 | testSelectAction | Siri Remote 点击 | 选中主机/执行操作 |
| E2E-004.4 | testMenuBack | Siri Remote Menu | 返回上一页面 |

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
| F-002 | PS 主机发现 | US-001 | UT-002, UT-003, UT-004 | - | E2E-001 |
| F-003 | 主机注册 | US-001 | UT-001 | - | E2E-001 |
| F-004 | 游戏控制器 | US-004 | - | IT-003 | - |
| F-005 | DualSense 支持 | US-004 | - | IT-003 | - |
| F-006 | 触屏虚拟控制器 | US-004 | - | - | - |
| F-007 | 流媒体设置 | US-003 | UT-005 | - | E2E-003 |
| F-008 | 多平台支持 | US-005, US-006, US-007, US-008 | - | - | E2E-004 |
| F-009 | PSN 账户集成 | US-001 | - | - | - |

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
| 单元测试 (UT) | 5 组 | 5 | 100% | 部分用例需 Mock 补充 |
| 集成测试 (IT) | 3 组 | 3 | 100% | 部分用例需真机验证 |
| E2E 测试 | 4 组 | 1 | 25% | E2E-001 基础实现 |

> **更新时间**: 2026-01-19
> **实际代码覆盖率**: 19.26% (1540/7997 行)
> **测试用例总数**: 102 个测试通过

### 10.4 测试实现详情

#### 已实现测试文件

| 文件 | 测试数量 | 覆盖用例 |
|------|----------|----------|
| `ChiakiTests.swift` | 39 | UT-003, UT-004, UT-005 + 额外模块 |
| `SessionAndDiscoveryTests.swift` | 31 | UT-001, UT-002 |
| `IntegrationTests.swift` | 28 | IT-001, IT-002, IT-003 |
| `ChiakiUITests.swift` | 4 | E2E-001 基础 |

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

### 10.5 待补充测试

| 优先级 | 测试项 | 阻塞原因 |
|--------|--------|----------|
| P0 | ChiakiSession 连接流程 | 需要 Protocol + Mock |
| P0 | ChiakiDiscovery 发现流程 | 需要网络 Mock |
| P1 | StreamingViewModel 状态机 | 需要 Session Mock |
| P1 | KeychainManager | 需要测试 Keychain |
| P1 | PSNService OAuth | 需要网络 Mock |
| P2 | E2E-002 流媒体页面 | 需要真实主机 |
| P2 | E2E-003 设置页面 | UI 测试补充 |
| P2 | E2E-004 tvOS 焦点导航 | 需要 tvOS 环境 |

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
