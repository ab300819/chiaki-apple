# Chiaki-ng Apple 原生客户端 - 详细设计文档

> **文档来源**: 改造自 `DESIGN.md`
> **改造时间**: 2026-01-13
> **改造模式**: 完整复制（内容完整无需补充）

## 1. 系统架构

### 1.1 模块依赖图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Application Layer                               │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │  ChiakiApp    │ │ ChiakiTVApp   │ │ ChiakiMacApp  │ │   App Intents   │  │
│  │  (iOS/iPad)   │ │   (tvOS)      │ │   (macOS)     │ │   (Shortcuts)   │  │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └────────┬────────┘  │
│          │                 │                 │                  │           │
│          └─────────────────┴────────┬────────┴──────────────────┘           │
│                                     ▼                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                              Feature Layer                                   │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │  HostList     │ │  Streaming    │ │  Settings     │ │   PSNLogin      │  │
│  │  Feature      │ │  Feature      │ │  Feature      │ │   Feature       │  │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └────────┬────────┘  │
│          │                 │                 │                  │           │
│          └─────────────────┴────────┬────────┴──────────────────┘           │
│                                     ▼                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                              Domain Layer                                    │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │ HostManager   │ │SessionManager │ │SettingsStore  │ │  PSNService     │  │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └────────┬────────┘  │
│          │                 │                 │                  │           │
│          └─────────────────┴────────┬────────┴──────────────────┘           │
│                                     ▼                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                              Bridge Layer (ChiakiBridge)                     │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │ChiakiSession  │ │ChiakiDiscovery│ │ChiakiRegist   │ │ ChiakiController│  │
│  │  Wrapper      │ │   Wrapper     │ │   Wrapper     │ │    Wrapper      │  │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └────────┬────────┘  │
│          │                 │                 │                  │           │
│          └─────────────────┴────────┬────────┴──────────────────┘           │
│                                     ▼                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                              Native Layer                                    │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐  │
│  │ VideoRenderer │ │ AudioPlayer   │ │ Controller    │ │   Haptics       │  │
│  │   (Metal)     │ │(AVAudioEngine)│ │   Manager     │ │ (CoreHaptics)   │  │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └────────┬────────┘  │
│          │                 │                 │                  │           │
│          └─────────────────┴────────┬────────┴──────────────────┘           │
│                                     ▼                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                              C Library Layer                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         libchiaki.xcframework                         │   │
│  │  ┌────────┐ ┌────────┐ ┌──────────┐ ┌────────┐ ┌──────┐ ┌─────────┐  │   │
│  │  │session │ │takion  │ │discovery │ │ regist │ │ rudp │ │  opus   │  │   │
│  │  └────────┘ └────────┘ └──────────┘ └────────┘ └──────┘ └─────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 目录结构

```
chiaki-apple/                               # 独立 Apple 原生客户端仓库
├── chiaki-ng/                              # git submodule (libchiaki 核心库)
├── Chiaki/                                 # 共享代码 (iOS, iPadOS, macOS)
│   ├── App/
│   │   ├── ChiakiApp.swift                # iOS/iPadOS App 入口
│   │   ├── AppDelegate.swift              # App 生命周期
│   │   └── SceneDelegate.swift            # Scene 管理
│   │
│   ├── Features/
│   │   ├── HostList/
│   │   │   ├── HostListView.swift         # 主机列表视图
│   │   │   ├── HostRowView.swift          # 单个主机行
│   │   │   ├── AddHostView.swift          # 添加主机视图
│   │   │   └── HostListViewModel.swift    # 视图模型
│   │   │
│   │   ├── Streaming/
│   │   │   ├── StreamingView.swift        # 流媒体主视图
│   │   │   ├── StreamingOverlay.swift     # 状态覆盖层
│   │   │   ├── StreamingViewModel.swift   # 视图模型
│   │   │   └── VirtualController/
│   │   │       ├── VirtualControllerView.swift
│   │   │       └── VirtualControllerViewModel.swift
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift         # 设置主视图
│   │   │   ├── VideoSettingsView.swift    # 视频设置
│   │   │   ├── AudioSettingsView.swift    # 音频设置
│   │   │   ├── ControllerSettingsView.swift
│   │   │   └── SettingsViewModel.swift
│   │   │
│   │   └── PSNLogin/
│   │       ├── PSNLoginView.swift         # PSN 登录视图
│   │       ├── PSNWebView.swift           # OAuth WebView
│   │       └── PSNLoginViewModel.swift
│   │
│   ├── Core/
│   │   ├── Bridge/
│   │   │   ├── ChiakiBridge.swift         # 桥接层入口
│   │   │   ├── ChiakiSession.swift        # 会话封装
│   │   │   ├── ChiakiDiscovery.swift      # 发现封装
│   │   │   ├── ChiakiRegist.swift         # 注册封装
│   │   │   ├── ChiakiTypes.swift          # 类型定义
│   │   │   ├── ChiakiError.swift          # 错误定义
│   │   │   └── ChiakiBridge.h             # Bridging Header
│   │   │
│   │   ├── Video/
│   │   │   ├── MetalVideoRenderer.swift   # Metal 渲染器
│   │   │   ├── VideoShaders.metal         # Metal 着色器
│   │   │   ├── VideoDecoderBridge.swift   # 解码器桥接
│   │   │   └── PixelBufferPool.swift      # 像素缓冲池
│   │   │
│   │   ├── Audio/
│   │   │   ├── AudioPlayer.swift          # 音频播放器
│   │   │   ├── AudioSessionManager.swift  # 音频会话管理
│   │   │   └── OpusDecoderBridge.swift    # Opus 解码桥接
│   │   │
│   │   ├── Controllers/
│   │   │   ├── ControllerManager.swift    # 控制器管理
│   │   │   ├── ControllerMapper.swift     # 按键映射
│   │   │   ├── HapticsManager.swift       # 触觉反馈
│   │   │   └── MotionManager.swift        # 运动传感器
│   │   │
│   │   ├── Network/
│   │   │   ├── NetworkMonitor.swift       # 网络状态监控
│   │   │   └── LocalNetworkPermission.swift
│   │   │
│   │   └── Storage/
│   │       ├── SettingsStore.swift        # 设置存储
│   │       ├── HostStore.swift            # 主机存储
│   │       ├── KeychainManager.swift      # 钥匙串管理
│   │       └── UserDefaultsKeys.swift     # UserDefaults 键
│   │
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Host.swift                 # 主机模型
│   │   │   ├── PSNAccount.swift           # PSN 账户
│   │   │   ├── StreamSettings.swift       # 流设置
│   │   │   ├── ControllerState.swift      # 控制器状态
│   │   │   └── ConnectionStatus.swift     # 连接状态
│   │   │
│   │   └── Services/
│   │       ├── HostManager.swift          # 主机管理服务
│   │       ├── SessionManager.swift       # 会话管理服务
│   │       └── PSNService.swift           # PSN 服务
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── Localizable.xcstrings          # 多语言
│   │   └── Info.plist
│   │
│   └── Utilities/
│       ├── Logger.swift                   # 日志工具
│       ├── Extensions/                    # Swift 扩展
│       └── Constants.swift                # 常量定义
│
├── ChiakiTV/                              # tvOS 特定代码
│   ├── App/
│   │   └── ChiakiTVApp.swift
│   ├── Features/
│   │   ├── TVHostListView.swift           # tvOS 主机列表
│   │   ├── TVStreamingView.swift          # tvOS 流媒体
│   │   └── TVSettingsView.swift           # tvOS 设置
│   └── Resources/
│       ├── Assets.xcassets/
│       └── TopShelf/                      # Top Shelf 扩展
│
├── ChiakiMac/                             # macOS 特定代码
│   ├── MacMenuBar.swift                   # 菜单栏
│   ├── MacWindowManager.swift             # 窗口管理
│   └── TouchBarSupport.swift              # 触控栏
│
├── Frameworks/                            # 预编译框架
│   ├── libchiaki.xcframework/
│   ├── opus.xcframework/
│   └── mbedtls.xcframework/
│
├── Scripts/
│   ├── build_dependencies.sh              # 构建依赖
│   ├── build_libchiaki.sh                 # 构建 libchiaki
│   └── create_xcframeworks.sh             # 创建 xcframework
│
├── Tests/
│   ├── ChiakiTests/                       # 单元测试
│   └── ChiakiUITests/                     # UI 测试
│
├── Chiaki.xcodeproj                       # Xcode 项目文件
└── README.md
```

---

## 2. 核心模块详细设计

### 2.1 ChiakiBridge 桥接层

#### 2.1.1 Bridging Header

```c
// ChiakiBridge.h
#ifndef ChiakiBridge_h
#define ChiakiBridge_h

#include <chiaki/session.h>
#include <chiaki/discovery.h>
#include <chiaki/regist.h>
#include <chiaki/opusdecoder.h>
#include <chiaki/log.h>
#include <chiaki/controller.h>
#include <chiaki/remote/holepunch.h>

#endif /* ChiakiBridge_h */
```

#### 2.1.2 ChiakiSession 封装

```swift
// ChiakiSession.swift
import Foundation
import Combine

/// 会话状态枚举
enum SessionState: Equatable {
    case idle
    case connecting
    case connected
    case streaming
    case disconnecting
    case error(SessionError)
}

/// 会话错误
enum SessionError: Error, Equatable {
    case connectionFailed(String)
    case authenticationFailed
    case networkError(String)
    case timeout
    case unknown(Int32)
}

/// Chiaki 会话封装
@Observable
final class ChiakiSession {
    // MARK: - Properties

    private(set) var state: SessionState = .idle
    private(set) var connectionQuality: ConnectionQuality = .unknown
    private(set) var currentFrameRate: Double = 0
    private(set) var latency: TimeInterval = 0

    private var session: UnsafeMutablePointer<ChiakiSession>?
    private var videoCallback: VideoFrameCallback?
    private var audioCallback: AudioFrameCallback?

    // MARK: - Callbacks

    typealias VideoFrameCallback = (CVPixelBuffer, CMTime) -> Void
    typealias AudioFrameCallback = (UnsafePointer<Int16>, Int) -> Void

    var onVideoFrame: VideoFrameCallback?
    var onAudioFrame: AudioFrameCallback?
    var onStateChanged: ((SessionState) -> Void)?

    // MARK: - Initialization

    init() {
        setupLogging()
    }

    deinit {
        disconnect()
    }

    // MARK: - Public Methods

    /// 连接到主机
    func connect(to host: Host, credentials: PSNCredentials?) async throws {
        guard state == .idle || state.isError else {
            throw SessionError.connectionFailed("Invalid state")
        }

        state = .connecting

        // 配置会话
        var connectInfo = ChiakiConnectInfo()
        setupConnectInfo(&connectInfo, host: host, credentials: credentials)

        // 分配会话
        session = UnsafeMutablePointer<ChiakiSession>.allocate(capacity: 1)

        // 设置回调
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        let result = chiaki_session_init(
            session,
            &connectInfo,
            sessionEventCallback,
            pointer
        )

        guard result == CHIAKI_ERR_SUCCESS else {
            state = .error(.connectionFailed("Init failed: \(result)"))
            throw SessionError.connectionFailed("Init failed")
        }

        // 启动会话
        let startResult = chiaki_session_start(session)
        guard startResult == CHIAKI_ERR_SUCCESS else {
            state = .error(.connectionFailed("Start failed: \(startResult)"))
            throw SessionError.connectionFailed("Start failed")
        }
    }

    /// 断开连接
    func disconnect() {
        guard let session = session else { return }

        state = .disconnecting
        chiaki_session_stop(session)
        chiaki_session_join(session)
        chiaki_session_fini(session)
        session.deallocate()
        self.session = nil
        state = .idle
    }

    /// 发送控制器状态
    func sendControllerState(_ controllerState: ControllerState) {
        guard let session = session, state == .streaming else { return }

        var state = ChiakiControllerState()
        state.buttons = controllerState.buttons.rawValue
        state.l2_state = controllerState.l2
        state.r2_state = controllerState.r2
        state.left_x = controllerState.leftStick.x
        state.left_y = controllerState.leftStick.y
        state.right_x = controllerState.rightStick.x
        state.right_y = controllerState.rightStick.y

        chiaki_session_set_controller_state(session, &state)
    }

    /// 发送触摸板事件
    func sendTouchpadEvent(_ touches: [TouchPoint]) {
        guard let session = session, state == .streaming else { return }
        // 实现触摸板事件发送
    }

    // MARK: - Private Methods

    private func setupLogging() {
        // 配置日志回调
    }

    private func setupConnectInfo(
        _ info: inout ChiakiConnectInfo,
        host: Host,
        credentials: PSNCredentials?
    ) {
        // 设置连接信息
        info.ps5 = host.isPS5
        info.host = strdup(host.address)
        // ... 其他配置
    }
}

// MARK: - C Callback

private func sessionEventCallback(
    event: UnsafePointer<ChiakiEvent>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let event = event, let userData = userData else { return }

    let session = Unmanaged<ChiakiSession>.fromOpaque(userData).takeUnretainedValue()

    DispatchQueue.main.async {
        session.handleEvent(event.pointee)
    }
}
```

#### 2.1.3 ChiakiDiscovery 封装

```swift
// ChiakiDiscovery.swift
import Foundation
import Network

/// 发现的主机信息
struct DiscoveredHost: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let macAddress: String
    let isPS5: Bool
    let status: HostStatus

    enum HostStatus {
        case online
        case standby
        case unknown
    }
}

/// Chiaki 发现服务封装
@Observable
final class ChiakiDiscovery {
    // MARK: - Properties

    private(set) var discoveredHosts: [DiscoveredHost] = []
    private(set) var isDiscovering = false

    private var discovery: UnsafeMutablePointer<ChiakiDiscoveryService>?
    private var discoveryThread: Thread?

    // MARK: - Public Methods

    /// 开始发现
    func startDiscovery() {
        guard !isDiscovering else { return }

        isDiscovering = true
        discoveredHosts.removeAll()

        discovery = UnsafeMutablePointer<ChiakiDiscoveryService>.allocate(capacity: 1)

        var options = ChiakiDiscoveryServiceOptions()
        options.ping_ms = 500
        options.hosts_max = 16
        options.host_drop_pings = 3

        let pointer = Unmanaged.passUnretained(self).toOpaque()

        chiaki_discovery_service_init(
            discovery,
            &options,
            discoveryCallback,
            pointer
        )
    }

    /// 停止发现
    func stopDiscovery() {
        guard isDiscovering, let discovery = discovery else { return }

        chiaki_discovery_service_fini(discovery)
        discovery.deallocate()
        self.discovery = nil
        isDiscovering = false
    }

    /// 唤醒主机
    func wakeUp(host: Host) async throws {
        let registKey = host.registKey
        let credential = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        credential.pointee = registKey

        defer { credential.deallocate() }

        let result = chiaki_discovery_wakeup(
            nil, // log
            nil, // discovery
            host.address,
            credential,
            host.isPS5
        )

        guard result == CHIAKI_ERR_SUCCESS else {
            throw DiscoveryError.wakeupFailed(result)
        }

        // 等待主机唤醒
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }

    // MARK: - Private Methods

    private func handleDiscoveryEvent(_ host: ChiakiDiscoveryHost) {
        let discovered = DiscoveredHost(
            id: String(cString: host.host_id),
            name: String(cString: host.host_name),
            address: String(cString: host.host_addr),
            macAddress: formatMacAddress(host.host_mac),
            isPS5: host.ps5,
            status: mapStatus(host.state)
        )

        DispatchQueue.main.async {
            if let index = self.discoveredHosts.firstIndex(where: { $0.id == discovered.id }) {
                self.discoveredHosts[index] = discovered
            } else {
                self.discoveredHosts.append(discovered)
            }
        }
    }
}

// MARK: - C Callback

private func discoveryCallback(
    event: UnsafePointer<ChiakiDiscoveryServiceEvent>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let event = event, let userData = userData else { return }

    let discovery = Unmanaged<ChiakiDiscovery>.fromOpaque(userData).takeUnretainedValue()
    discovery.handleDiscoveryEvent(event.pointee.host.pointee)
}
```

### 2.2 视频渲染模块

#### 2.2.1 Metal 渲染器

```swift
// MetalVideoRenderer.swift
import MetalKit
import CoreVideo

/// Metal 视频渲染器
final class MetalVideoRenderer: NSObject, MTKViewDelegate {
    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache

    private var yTexture: MTLTexture?
    private var uvTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?

    private var currentPixelBuffer: CVPixelBuffer?
    private let lock = NSLock()

    // 顶点数据 (位置 + 纹理坐标)
    private let vertices: [Float] = [
        // 位置          纹理坐标
        -1.0,  1.0,     0.0, 0.0,  // 左上
         1.0,  1.0,     1.0, 0.0,  // 右上
        -1.0, -1.0,     0.0, 1.0,  // 左下
         1.0, -1.0,     1.0, 1.0,  // 右下
    ]

    // MARK: - Initialization

    init(metalView: MTKView) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VideoRendererError.noMetalDevice
        }

        self.device = device
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true

        guard let commandQueue = device.makeCommandQueue() else {
            throw VideoRendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        // 创建纹理缓存
        var textureCache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        guard status == kCVReturnSuccess, let cache = textureCache else {
            throw VideoRendererError.textureCacheCreationFailed
        }
        self.textureCache = cache

        // 创建渲染管线
        self.pipelineState = try Self.createPipelineState(device: device)

        super.init()

        // 创建顶点缓冲
        self.vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        )

        metalView.delegate = self
    }

    // MARK: - Public Methods

    /// 更新视频帧
    func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        currentPixelBuffer = pixelBuffer
        lock.unlock()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // 处理尺寸变化
    }

    func draw(in view: MTKView) {
        lock.lock()
        guard let pixelBuffer = currentPixelBuffer else {
            lock.unlock()
            return
        }
        lock.unlock()

        // 创建纹理
        guard let (yTexture, uvTexture) = createTextures(from: pixelBuffer) else {
            return
        }

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(yTexture, index: 0)
        encoder.setFragmentTexture(uvTexture, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Private Methods

    private func createTextures(from pixelBuffer: CVPixelBuffer) -> (MTLTexture, MTLTexture)? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Y 平面纹理
        var yTextureRef: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .r8Unorm,
            width,
            height,
            0,
            &yTextureRef
        )

        // UV 平面纹理
        var uvTextureRef: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .rg8Unorm,
            width / 2,
            height / 2,
            1,
            &uvTextureRef
        )

        guard let yRef = yTextureRef,
              let uvRef = uvTextureRef,
              let yTexture = CVMetalTextureGetTexture(yRef),
              let uvTexture = CVMetalTextureGetTexture(uvRef)
        else {
            return nil
        }

        return (yTexture, uvTexture)
    }

    private static func createPipelineState(device: MTLDevice) throws -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            throw VideoRendererError.shaderLibraryCreationFailed
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "videoVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "videoFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}
```

#### 2.2.2 Metal 着色器

```metal
// VideoShaders.metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// 顶点着色器
vertex VertexOut videoVertexShader(
    uint vertexID [[vertex_id]],
    constant float4 *vertices [[buffer(0)]]
) {
    VertexOut out;
    float4 vertex = vertices[vertexID];
    out.position = float4(vertex.xy, 0.0, 1.0);
    out.texCoord = vertex.zw;
    return out;
}

// 片段着色器 (NV12 到 RGB 转换)
fragment float4 videoFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> yTexture [[texture(0)]],
    texture2d<float> uvTexture [[texture(1)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float y = yTexture.sample(textureSampler, in.texCoord).r;
    float2 uv = uvTexture.sample(textureSampler, in.texCoord).rg - 0.5;

    // BT.709 YUV 到 RGB 转换
    float3 rgb;
    rgb.r = y + 1.5748 * uv.y;
    rgb.g = y - 0.1873 * uv.x - 0.4681 * uv.y;
    rgb.b = y + 1.8556 * uv.x;

    return float4(rgb, 1.0);
}
```

### 2.3 VideoToolbox 解码器（基于 Android MediaCodec 审查）

> **设计参考**: chiaki-ng/android `video-decoder.c` 的双线程模型

#### 2.3.1 架构概述

```
libchiaki 视频数据流
        │
        ▼
┌───────────────────────────────────────┐
│     VideoToolboxDecoder               │
│  ┌─────────────────────────────────┐  │
│  │      Input Thread (异步)        │  │
│  │  - 接收 H.264/H.265 NAL 单元    │  │
│  │  - VTDecompressionSession       │  │
│  │  - 异步解码提交                  │  │
│  └──────────────┬──────────────────┘  │
│                 │ 解码完成回调         │
│  ┌──────────────▼──────────────────┐  │
│  │      Output Callback            │  │
│  │  - CVPixelBuffer 输出           │  │
│  │  - 帧排序（B 帧重排）            │  │
│  │  - 推送到 Metal 渲染器           │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
        │
        ▼
   MetalVideoRenderer (零拷贝)
```

#### 2.3.2 核心实现

```swift
// VideoToolboxDecoder.swift
import VideoToolbox
import CoreVideo

/// VideoToolbox 硬件解码器
final class VideoToolboxDecoder {
    // MARK: - Properties

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?

    private let outputQueue = DispatchQueue(label: "video.output.queue")
    private let decodeLock = NSLock()

    /// 解码帧输出回调
    var onFrameDecoded: ((CVPixelBuffer, CMTime) -> Void)?

    /// 解码统计
    private(set) var decodedFrameCount: UInt64 = 0
    private(set) var droppedFrameCount: UInt64 = 0

    // 帧重排缓冲（处理 B 帧）
    private var frameReorderBuffer: [(CVPixelBuffer, CMTime)] = []
    private let maxReorderBufferSize = 4

    // MARK: - Codec Configuration

    private let codec: ChiakiVideoCodec
    private let width: Int32
    private let height: Int32

    // MARK: - Initialization

    init(codec: ChiakiVideoCodec, width: Int32, height: Int32) {
        self.codec = codec
        self.width = width
        self.height = height
    }

    deinit {
        shutdown()
    }

    // MARK: - Public Methods

    /// 初始化解码器（收到 SPS/PPS 后调用）
    func initialize(sps: Data, pps: Data, vps: Data? = nil) throws {
        decodeLock.lock()
        defer { decodeLock.unlock() }

        // 创建格式描述
        formatDescription = try createFormatDescription(sps: sps, pps: pps, vps: vps)

        // 创建解码会话
        let destinationAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        var callbacks = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionOutputCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription!,
            decoderSpecification: nil,
            imageBufferAttributes: destinationAttributes as CFDictionary,
            outputCallback: &callbacks,
            decompressionSessionOut: &decompressionSession
        )

        guard status == noErr else {
            throw VideoDecoderError.sessionCreationFailed(status)
        }

        // 启用低延迟模式
        VTSessionSetProperty(
            decompressionSession!,
            key: kVTDecompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )
    }

    /// 提交视频数据进行解码（从 libchiaki 回调调用）
    func decodeFrame(_ data: UnsafePointer<UInt8>, size: Int, timestamp: UInt64) {
        decodeLock.lock()
        guard let session = decompressionSession, let formatDesc = formatDescription else {
            decodeLock.unlock()
            return
        }
        decodeLock.unlock()

        // 创建 CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: UnsafeMutableRawPointer(mutating: data),
            blockLength: size,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: size,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let buffer = blockBuffer else {
            droppedFrameCount += 1
            return
        }

        // 创建 CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = size
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sample = sampleBuffer else {
            droppedFrameCount += 1
            return
        }

        // 异步解码
        let decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        var infoFlags: VTDecodeInfoFlags = []

        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: decodeFlags,
            frameRefcon: UnsafeMutableRawPointer(bitPattern: UInt(timestamp)),
            infoFlagsOut: &infoFlags
        )

        if decodeStatus != noErr {
            droppedFrameCount += 1
        }
    }

    /// 关闭解码器
    func shutdown() {
        decodeLock.lock()
        defer { decodeLock.unlock() }

        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        frameReorderBuffer.removeAll()
    }

    // MARK: - Private Methods

    private func createFormatDescription(sps: Data, pps: Data, vps: Data?) throws -> CMVideoFormatDescription {
        var formatDescription: CMVideoFormatDescription?

        if codec.isH265, let vps = vps {
            // H.265/HEVC
            let parameterSets = [vps, sps, pps]
            let parameterSetPointers = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
            let parameterSetSizes = parameterSets.map { $0.count }

            let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: 3,
                parameterSetPointers: parameterSetPointers,
                parameterSetSizes: parameterSetSizes,
                nalUnitHeaderLength: 4,
                extensions: nil,
                formatDescriptionOut: &formatDescription
            )

            guard status == noErr else {
                throw VideoDecoderError.formatDescriptionFailed(status)
            }
        } else {
            // H.264/AVC
            let parameterSets = [sps, pps]
            let parameterSetPointers = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
            let parameterSetSizes = parameterSets.map { $0.count }

            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: 2,
                parameterSetPointers: parameterSetPointers,
                parameterSetSizes: parameterSetSizes,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDescription
            )

            guard status == noErr else {
                throw VideoDecoderError.formatDescriptionFailed(status)
            }
        }

        return formatDescription!
    }

    /// 处理解码输出帧（帧重排）
    private func handleDecodedFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        outputQueue.async { [weak self] in
            guard let self = self else { return }

            // 添加到重排缓冲
            self.frameReorderBuffer.append((pixelBuffer, presentationTime))

            // 按 PTS 排序
            self.frameReorderBuffer.sort { $0.1 < $1.1 }

            // 输出最旧的帧（当缓冲区满时）
            while self.frameReorderBuffer.count > self.maxReorderBufferSize {
                let (buffer, time) = self.frameReorderBuffer.removeFirst()
                self.decodedFrameCount += 1
                self.onFrameDecoded?(buffer, time)
            }
        }
    }

    /// 刷新重排缓冲区
    func flush() {
        outputQueue.async { [weak self] in
            guard let self = self else { return }

            for (buffer, time) in self.frameReorderBuffer {
                self.onFrameDecoded?(buffer, time)
            }
            self.frameReorderBuffer.removeAll()
        }
    }
}

// MARK: - C Callback

private func decompressionOutputCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    guard status == noErr,
          let refCon = decompressionOutputRefCon,
          let pixelBuffer = imageBuffer else {
        return
    }

    let decoder = Unmanaged<VideoToolboxDecoder>.fromOpaque(refCon).takeUnretainedValue()

    // 从 frameRefcon 恢复时间戳
    let timestamp = sourceFrameRefCon.map { CMTime(value: CMTimeValue(UInt(bitPattern: $0)), timescale: 90000) } ?? presentationTimeStamp

    decoder.handleDecodedFrame(pixelBuffer, presentationTime: timestamp)
}

/// 解码器错误
enum VideoDecoderError: Error {
    case sessionCreationFailed(OSStatus)
    case formatDescriptionFailed(OSStatus)
    case decodeFailed(OSStatus)
}
```

### 2.4 音频模块（基于 Android Oboe 审查）

> **设计参考**: chiaki-ng/android `audio-output.cpp` 的 Lock-free 环形缓冲模型

#### 2.4.1 架构概述

```
libchiaki Opus 解码数据
        │
        ▼
┌───────────────────────────────────────┐
│         AudioPlayer                   │
│  ┌─────────────────────────────────┐  │
│  │    Opus Decode Thread           │  │
│  │  - ChiakiOpusDecoder 解码       │  │
│  │  - PCM Int16 输出               │  │
│  └──────────────┬──────────────────┘  │
│                 │ Push (生产者)        │
│  ┌──────────────▼──────────────────┐  │
│  │    Lock-free Circular Buffer    │  │
│  │  - 32 chunks × 1024 bytes       │  │
│  │  - 原子操作无锁队列              │  │
│  └──────────────┬──────────────────┘  │
│                 │ Pop (消费者)         │
│  ┌──────────────▼──────────────────┐  │
│  │    AVAudioEngine Render         │  │
│  │  - AVAudioSourceNode            │  │
│  │  - 实时回调拉取数据              │  │
│  │  - 低延迟播放 (<10ms)            │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

#### 2.4.2 Lock-free 环形缓冲

```swift
// CircularAudioBuffer.swift
import Foundation

/// Lock-free 环形缓冲区（参考 Android circular-buf.hpp）
final class CircularAudioBuffer<T> {
    // MARK: - Configuration

    private let chunkCount: Int
    private let chunkSize: Int

    // MARK: - Storage

    private var chunks: [UnsafeMutablePointer<T>]
    private var freeQueue: LockFreeQueue<Int>
    private var fullQueue: LockFreeQueue<Int>

    // 当前操作中的 chunk
    private var pushChunk: UnsafeMutablePointer<T>?
    private var pushChunkOffset: Int = 0
    private var popChunk: UnsafeMutablePointer<T>?
    private var popChunkOffset: Int = 0

    // MARK: - Initialization

    /// 初始化环形缓冲
    /// - Parameters:
    ///   - chunkCount: chunk 数量（默认 32）
    ///   - chunkSize: 每个 chunk 的元素数量（默认 512，对应 1024 bytes Int16）
    init(chunkCount: Int = 32, chunkSize: Int = 512) {
        self.chunkCount = chunkCount
        self.chunkSize = chunkSize

        // 分配 chunks
        self.chunks = (0..<chunkCount).map { _ in
            UnsafeMutablePointer<T>.allocate(capacity: chunkSize)
        }

        // 初始化队列
        self.freeQueue = LockFreeQueue(capacity: chunkCount)
        self.fullQueue = LockFreeQueue(capacity: chunkCount)

        // 所有 chunk 初始为空闲
        for i in 0..<chunkCount {
            freeQueue.push(i)
        }
    }

    deinit {
        for chunk in chunks {
            chunk.deallocate()
        }
    }

    // MARK: - Push (生产者)

    /// 推送数据到缓冲区
    /// - Returns: 实际写入的元素数量
    @discardableResult
    func push(_ buffer: UnsafePointer<T>, count: Int) -> Int {
        var pushed = 0

        while pushed < count {
            // 获取空闲 chunk
            if pushChunk == nil {
                guard let chunkIndex = freeQueue.pop() else {
                    // 缓冲区满，丢弃旧数据
                    if let oldIndex = fullQueue.pop() {
                        pushChunk = chunks[oldIndex]
                        pushChunkOffset = 0
                    } else {
                        break
                    }
                } else {
                    pushChunk = chunks[chunkIndex]
                    pushChunkOffset = 0
                }
            }

            // 计算可写入数量
            let toPush = min(count - pushed, chunkSize - pushChunkOffset)

            // 复制数据
            pushChunk!.advanced(by: pushChunkOffset).assign(from: buffer.advanced(by: pushed), count: toPush)

            pushed += toPush
            pushChunkOffset += toPush

            // chunk 写满，放入 full 队列
            if pushChunkOffset == chunkSize {
                let chunkIndex = chunks.firstIndex(of: pushChunk!)!
                fullQueue.push(chunkIndex)
                pushChunk = nil
                pushChunkOffset = 0
            }
        }

        return pushed
    }

    // MARK: - Pop (消费者)

    /// 从缓冲区读取数据
    /// - Returns: 实际读取的元素数量
    @discardableResult
    func pop(_ buffer: UnsafeMutablePointer<T>, count: Int) -> Int {
        var popped = 0

        while popped < count {
            // 获取已填充 chunk
            if popChunk == nil {
                guard let chunkIndex = fullQueue.pop() else {
                    break // 缓冲区空
                }
                popChunk = chunks[chunkIndex]
                popChunkOffset = 0
            }

            // 计算可读取数量
            let toPop = min(count - popped, chunkSize - popChunkOffset)

            // 复制数据
            buffer.advanced(by: popped).assign(from: popChunk!.advanced(by: popChunkOffset), count: toPop)

            popped += toPop
            popChunkOffset += toPop

            // chunk 读完，放回 free 队列
            if popChunkOffset == chunkSize {
                let chunkIndex = chunks.firstIndex(of: popChunk!)!
                freeQueue.push(chunkIndex)
                popChunk = nil
                popChunkOffset = 0
            }
        }

        return popped
    }

    /// 清空缓冲区
    func reset() {
        // 归还所有 chunk 到 free 队列
        while let index = fullQueue.pop() {
            freeQueue.push(index)
        }
        pushChunk = nil
        pushChunkOffset = 0
        popChunk = nil
        popChunkOffset = 0
    }

    /// 当前缓冲的 chunk 数量
    var bufferedChunkCount: Int {
        fullQueue.count
    }
}

// MARK: - Lock-free Queue

/// 简单的 Lock-free 单生产者单消费者队列
final class LockFreeQueue<T> {
    private var buffer: [T?]
    private var head: UnsafeMutablePointer<Int>
    private var tail: UnsafeMutablePointer<Int>
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity + 1  // 需要一个空位区分满/空
        self.buffer = Array(repeating: nil, count: self.capacity)
        self.head = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self.tail = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        head.pointee = 0
        tail.pointee = 0
    }

    deinit {
        head.deallocate()
        tail.deallocate()
    }

    func push(_ value: T) -> Bool {
        let currentTail = tail.pointee
        let nextTail = (currentTail + 1) % capacity

        if nextTail == head.pointee {
            return false  // 队列满
        }

        buffer[currentTail] = value
        OSMemoryBarrier()
        tail.pointee = nextTail
        return true
    }

    func pop() -> T? {
        let currentHead = head.pointee

        if currentHead == tail.pointee {
            return nil  // 队列空
        }

        let value = buffer[currentHead]
        buffer[currentHead] = nil
        OSMemoryBarrier()
        head.pointee = (currentHead + 1) % capacity
        return value
    }

    var count: Int {
        let h = head.pointee
        let t = tail.pointee
        return t >= h ? t - h : capacity - h + t
    }
}
```

#### 2.4.3 音频播放器（使用环形缓冲）

```swift
// AudioPlayer.swift
import AVFoundation
import Accelerate

/// 低延迟音频播放器（基于 Lock-free 环形缓冲）
final class AudioPlayer {
    // MARK: - Properties

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let format: AVAudioFormat

    /// Lock-free 环形缓冲（32 chunks × 512 samples = 约 340ms 缓冲）
    private let circularBuffer = CircularAudioBuffer<Float>(chunkCount: 32, chunkSize: 512)

    private var isPlaying = false

    // 配置
    private let sampleRate: Double = 48000
    private let channelCount: AVAudioChannelCount = 2

    // 统计
    private(set) var underrunCount: UInt64 = 0

    // MARK: - Initialization

    init() throws {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ) else {
            throw AudioPlayerError.formatCreationFailed
        }
        self.format = format

        try setupAudioSession()
        setupEngine()
    }

    // MARK: - Public Methods

    /// 开始播放
    func start() throws {
        guard !isPlaying else { return }

        try engine.start()
        isPlaying = true
    }

    /// 停止播放
    func stop() {
        guard isPlaying else { return }

        engine.stop()
        circularBuffer.reset()
        isPlaying = false
    }

    /// 接收音频数据（从 libchiaki 回调，Int16 PCM）
    func receiveAudio(samples: UnsafePointer<Int16>, frameCount: Int) {
        // Int16 转 Float32（交错格式）
        let floatSamples = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * Int(channelCount))
        defer { floatSamples.deallocate() }

        // 使用 vDSP 加速转换
        var scale: Float = 1.0 / 32768.0
        vDSP_vflt16(samples, 1, floatSamples, 1, vDSP_Length(frameCount * Int(channelCount)))
        vDSP_vsmul(floatSamples, 1, &scale, floatSamples, 1, vDSP_Length(frameCount * Int(channelCount)))

        // 推送到环形缓冲
        circularBuffer.push(floatSamples, count: frameCount * Int(channelCount))
    }

    // MARK: - Private Methods

    private func setupAudioSession() throws {
        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredIOBufferDuration(0.005)  // 5ms 低延迟
        try session.setActive(true)
        #endif
    }

    private func setupEngine() {
        // 使用 AVAudioSourceNode 实现拉取模式（类似 Android Oboe 回调）
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let requestedSamples = Int(frameCount) * Int(self.channelCount)

            // 从环形缓冲读取数据
            let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: requestedSamples)
            defer { tempBuffer.deallocate() }

            let poppedSamples = self.circularBuffer.pop(tempBuffer, count: requestedSamples)

            // 填充静音（如果数据不足）
            if poppedSamples < requestedSamples {
                memset(tempBuffer.advanced(by: poppedSamples), 0, (requestedSamples - poppedSamples) * MemoryLayout<Float>.size)
                self.underrunCount += 1
            }

            // 解交错到各声道
            for channel in 0..<Int(self.channelCount) {
                guard let channelData = ablPointer[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }

                for frame in 0..<Int(frameCount) {
                    channelData[frame] = tempBuffer[frame * Int(self.channelCount) + channel]
                }
            }

            return noErr
        }

        engine.attach(sourceNode!)
        engine.connect(sourceNode!, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }
}

enum AudioPlayerError: Error {
    case formatCreationFailed
    case engineStartFailed
}
```

### 2.5 串流统计（基于 Qt GUI 审查）

```swift
// StreamStatistics.swift
import Foundation

/// 串流统计信息（参考 chiaki-ng/gui StreamView.qml）
@Observable
final class StreamStatistics {
    // MARK: - Video Statistics

    /// 测量的比特率 (Mbps)
    private(set) var measuredBitrate: Double = 0

    /// 丢帧计数
    private(set) var droppedFrames: UInt64 = 0

    /// 解码帧计数
    private(set) var decodedFrames: UInt64 = 0

    // MARK: - Network Statistics

    /// 平均丢包率 (0.0 - 1.0)
    private(set) var averagePacketLoss: Double = 0

    /// 网络延迟 (ms)
    private(set) var networkLatency: Double = 0

    // MARK: - Audio Statistics

    /// 音频缓冲欠载次数
    private(set) var audioUnderruns: UInt64 = 0

    // MARK: - Internal

    private var packetLossHistory: [Double] = []
    private let maxHistorySize = 100
    private var lastBitrateUpdate = Date()
    private var bytesReceivedSinceLastUpdate: UInt64 = 0

    // MARK: - Update Methods

    func recordVideoFrame(size: Int, wasDropped: Bool) {
        if wasDropped {
            droppedFrames += 1
        } else {
            decodedFrames += 1
        }

        bytesReceivedSinceLastUpdate += UInt64(size)
        updateBitrate()
    }

    func recordPacketLoss(_ lossRate: Double) {
        packetLossHistory.append(lossRate)
        if packetLossHistory.count > maxHistorySize {
            packetLossHistory.removeFirst()
        }
        averagePacketLoss = packetLossHistory.reduce(0, +) / Double(packetLossHistory.count)
    }

    func recordAudioUnderrun() {
        audioUnderruns += 1
    }

    func updateLatency(_ latency: Double) {
        networkLatency = latency
    }

    func reset() {
        measuredBitrate = 0
        droppedFrames = 0
        decodedFrames = 0
        averagePacketLoss = 0
        networkLatency = 0
        audioUnderruns = 0
        packetLossHistory.removeAll()
        bytesReceivedSinceLastUpdate = 0
        lastBitrateUpdate = Date()
    }

    // MARK: - Private Methods

    private func updateBitrate() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBitrateUpdate)

        if elapsed >= 1.0 {  // 每秒更新一次
            measuredBitrate = Double(bytesReceivedSinceLastUpdate) * 8 / elapsed / 1_000_000  // Mbps
            bytesReceivedSinceLastUpdate = 0
            lastBitrateUpdate = now
        }
    }
}
```

### 2.6 控制器模块

### 2.4 控制器模块

```swift
// ControllerManager.swift
import GameController
import Combine

/// 控制器状态
struct ControllerState {
    var buttons: ControllerButtons = []
    var leftStick: StickPosition = .zero
    var rightStick: StickPosition = .zero
    var l2: UInt8 = 0
    var r2: UInt8 = 0
    var touchpad: [TouchPoint] = []
    var gyro: GyroData?
    var accel: AccelData?

    struct StickPosition {
        var x: Int16 = 0
        var y: Int16 = 0
        static let zero = StickPosition()
    }
}

/// 控制器按钮
struct ControllerButtons: OptionSet {
    let rawValue: UInt32

    static let cross = ControllerButtons(rawValue: 1 << 0)
    static let circle = ControllerButtons(rawValue: 1 << 1)
    static let square = ControllerButtons(rawValue: 1 << 2)
    static let triangle = ControllerButtons(rawValue: 1 << 3)
    static let l1 = ControllerButtons(rawValue: 1 << 4)
    static let r1 = ControllerButtons(rawValue: 1 << 5)
    static let l2 = ControllerButtons(rawValue: 1 << 6)
    static let r2 = ControllerButtons(rawValue: 1 << 7)
    static let l3 = ControllerButtons(rawValue: 1 << 8)
    static let r3 = ControllerButtons(rawValue: 1 << 9)
    static let options = ControllerButtons(rawValue: 1 << 10)
    static let share = ControllerButtons(rawValue: 1 << 11)
    static let ps = ControllerButtons(rawValue: 1 << 12)
    static let touchpad = ControllerButtons(rawValue: 1 << 13)
    static let dpadUp = ControllerButtons(rawValue: 1 << 14)
    static let dpadDown = ControllerButtons(rawValue: 1 << 15)
    static let dpadLeft = ControllerButtons(rawValue: 1 << 16)
    static let dpadRight = ControllerButtons(rawValue: 1 << 17)
}

/// 控制器管理器
@Observable
final class ControllerManager {
    // MARK: - Properties

    private(set) var connectedControllers: [GCController] = []
    private(set) var activeController: GCController?
    private(set) var currentState = ControllerState()

    var onStateChanged: ((ControllerState) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private let mapper = ControllerMapper()

    // MARK: - Initialization

    init() {
        setupNotifications()
        updateConnectedControllers()
    }

    // MARK: - Public Methods

    /// 设置活跃控制器
    func setActiveController(_ controller: GCController?) {
        activeController = controller
        if let controller = controller {
            setupControllerInput(controller)
        }
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .sink { [weak self] notification in
                self?.updateConnectedControllers()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .sink { [weak self] notification in
                self?.updateConnectedControllers()
            }
            .store(in: &cancellables)
    }

    private func updateConnectedControllers() {
        connectedControllers = GCController.controllers()

        // 自动选择第一个控制器
        if activeController == nil, let first = connectedControllers.first {
            setActiveController(first)
        }
    }

    private func setupControllerInput(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            self?.handleGamepadInput(gamepad)
        }

        // DualSense 特定功能
        if let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad {
            setupDualSenseFeatures(dualSense)
        }
    }

    private func handleGamepadInput(_ gamepad: GCExtendedGamepad) {
        var state = ControllerState()

        // 按钮
        if gamepad.buttonA.isPressed { state.buttons.insert(.cross) }
        if gamepad.buttonB.isPressed { state.buttons.insert(.circle) }
        if gamepad.buttonX.isPressed { state.buttons.insert(.square) }
        if gamepad.buttonY.isPressed { state.buttons.insert(.triangle) }
        if gamepad.leftShoulder.isPressed { state.buttons.insert(.l1) }
        if gamepad.rightShoulder.isPressed { state.buttons.insert(.r1) }
        if gamepad.leftThumbstickButton?.isPressed == true { state.buttons.insert(.l3) }
        if gamepad.rightThumbstickButton?.isPressed == true { state.buttons.insert(.r3) }
        if gamepad.buttonMenu.isPressed { state.buttons.insert(.options) }
        if gamepad.buttonOptions?.isPressed == true { state.buttons.insert(.share) }
        if gamepad.buttonHome?.isPressed == true { state.buttons.insert(.ps) }

        // D-Pad
        if gamepad.dpad.up.isPressed { state.buttons.insert(.dpadUp) }
        if gamepad.dpad.down.isPressed { state.buttons.insert(.dpadDown) }
        if gamepad.dpad.left.isPressed { state.buttons.insert(.dpadLeft) }
        if gamepad.dpad.right.isPressed { state.buttons.insert(.dpadRight) }

        // 摇杆
        state.leftStick.x = Int16(gamepad.leftThumbstick.xAxis.value * 32767)
        state.leftStick.y = Int16(-gamepad.leftThumbstick.yAxis.value * 32767)
        state.rightStick.x = Int16(gamepad.rightThumbstick.xAxis.value * 32767)
        state.rightStick.y = Int16(-gamepad.rightThumbstick.yAxis.value * 32767)

        // 扳机
        state.l2 = UInt8(gamepad.leftTrigger.value * 255)
        state.r2 = UInt8(gamepad.rightTrigger.value * 255)

        currentState = state
        onStateChanged?(state)
    }

    private func setupDualSenseFeatures(_ dualSense: GCDualSenseGamepad) {
        // 触摸板
        // 自适应扳机（如果可用）
    }
}
```

---

## 3. 数据模型

### 3.1 领域模型

```swift
// Host.swift
import Foundation

/// 主机模型
struct Host: Identifiable, Codable, Equatable {
    let id: UUID
    var nickname: String
    var address: String
    var macAddress: String
    var isPS5: Bool
    var registKey: UInt64
    var rpKey: Data
    var rpKeyType: UInt32

    var isRegistered: Bool {
        registKey != 0
    }

    init(
        id: UUID = UUID(),
        nickname: String,
        address: String,
        macAddress: String = "",
        isPS5: Bool = true,
        registKey: UInt64 = 0,
        rpKey: Data = Data(),
        rpKeyType: UInt32 = 0
    ) {
        self.id = id
        self.nickname = nickname
        self.address = address
        self.macAddress = macAddress
        self.isPS5 = isPS5
        self.registKey = registKey
        self.rpKey = rpKey
        self.rpKeyType = rpKeyType
    }
}

// StreamSettings.swift
/// 流媒体设置
struct StreamSettings: Codable, Equatable {
    var resolution: Resolution = .r1080p
    var frameRate: FrameRate = .fps60
    var bitrate: Int = 15000 // kbps
    var codec: VideoCodec = .h265
    var hdrEnabled: Bool = false

    enum Resolution: String, Codable, CaseIterable {
        case r540p = "540p"
        case r720p = "720p"
        case r1080p = "1080p"

        var width: Int {
            switch self {
            case .r540p: return 960
            case .r720p: return 1280
            case .r1080p: return 1920
            }
        }

        var height: Int {
            switch self {
            case .r540p: return 540
            case .r720p: return 720
            case .r1080p: return 1080
            }
        }
    }

    enum FrameRate: Int, Codable, CaseIterable {
        case fps30 = 30
        case fps60 = 60
    }

    enum VideoCodec: String, Codable, CaseIterable {
        case h264 = "H.264"
        case h265 = "H.265 (HEVC)"
    }
}

// PSNAccount.swift
/// PSN 账户
struct PSNAccount: Codable {
    let accountId: String
    let onlineId: String
    var accessToken: String
    var refreshToken: String
    var tokenExpiresAt: Date

    var isTokenExpired: Bool {
        Date() >= tokenExpiresAt
    }
}
```

### 3.2 存储层

```swift
// HostStore.swift
import Foundation

/// 主机存储
actor HostStore {
    private let userDefaults: UserDefaults
    private let key = "saved_hosts"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadHosts() -> [Host] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([Host].self, from: data)) ?? []
    }

    func saveHosts(_ hosts: [Host]) {
        let data = try? JSONEncoder().encode(hosts)
        userDefaults.set(data, forKey: key)
    }

    func addHost(_ host: Host) {
        var hosts = loadHosts()
        hosts.append(host)
        saveHosts(hosts)
    }

    func updateHost(_ host: Host) {
        var hosts = loadHosts()
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
            saveHosts(hosts)
        }
    }

    func removeHost(_ host: Host) {
        var hosts = loadHosts()
        hosts.removeAll { $0.id == host.id }
        saveHosts(hosts)
    }
}

// KeychainManager.swift
import Security

/// 钥匙串管理
final class KeychainManager {
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
    }

    static let shared = KeychainManager()
    private init() {}

    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data, for: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.itemNotFound
        }

        return data
    }

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func update(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

---

## 4. 构建系统

### 4.1 依赖构建脚本

```bash
#!/bin/bash
# build_dependencies.sh
# 构建所有依赖库的 xcframework

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
OUTPUT_DIR="$ROOT_DIR/Frameworks"

# 平台配置
IOS_MIN_VERSION="16.0"
TVOS_MIN_VERSION="16.0"
MACOS_MIN_VERSION="13.0"

# 创建目录
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# 构建 mbedtls
build_mbedtls() {
    echo "Building mbedtls..."

    cd "$BUILD_DIR"

    if [ ! -d "mbedtls" ]; then
        git clone --depth 1 --branch v3.5.0 https://github.com/Mbed-TLS/mbedtls.git
    fi

    cd mbedtls

    # iOS arm64
    cmake -B build-ios-arm64 \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/mbedtls-ios-arm64"
    cmake --build build-ios-arm64 --target install

    # iOS Simulator arm64
    cmake -B build-ios-sim-arm64 \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT=iphonesimulator \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/mbedtls-ios-sim-arm64"
    cmake --build build-ios-sim-arm64 --target install

    # macOS arm64
    cmake -B build-macos-arm64 \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/mbedtls-macos-arm64"
    cmake --build build-macos-arm64 --target install

    # macOS x86_64
    cmake -B build-macos-x86_64 \
        -DCMAKE_OSX_ARCHITECTURES=x86_64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/mbedtls-macos-x86_64"
    cmake --build build-macos-x86_64 --target install

    # tvOS arm64
    cmake -B build-tvos-arm64 \
        -DCMAKE_SYSTEM_NAME=tvOS \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$TVOS_MIN_VERSION \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/mbedtls-tvos-arm64"
    cmake --build build-tvos-arm64 --target install

    # 创建 xcframework
    xcodebuild -create-xcframework \
        -library "$BUILD_DIR/mbedtls-ios-arm64/lib/libmbedcrypto.a" \
        -library "$BUILD_DIR/mbedtls-ios-sim-arm64/lib/libmbedcrypto.a" \
        -library "$BUILD_DIR/mbedtls-macos-arm64/lib/libmbedcrypto.a" \
        -library "$BUILD_DIR/mbedtls-macos-x86_64/lib/libmbedcrypto.a" \
        -library "$BUILD_DIR/mbedtls-tvos-arm64/lib/libmbedcrypto.a" \
        -output "$OUTPUT_DIR/mbedcrypto.xcframework"

    echo "mbedtls built successfully"
}

# 构建 opus
build_opus() {
    echo "Building opus..."

    cd "$BUILD_DIR"

    if [ ! -d "opus" ]; then
        git clone --depth 1 --branch v1.4 https://github.com/xiph/opus.git
    fi

    cd opus

    # 类似的多平台构建...

    echo "opus built successfully"
}

# 构建 libchiaki
build_libchiaki() {
    echo "Building libchiaki..."

    cd "$ROOT_DIR/.."  # chiaki-ng 根目录

    # iOS arm64
    cmake -B build-ios-arm64 -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
        -DCHIAKI_ENABLE_CLI=OFF \
        -DCHIAKI_ENABLE_GUI=OFF \
        -DCHIAKI_ENABLE_TESTS=OFF \
        -DCHIAKI_LIB_ENABLE_MBEDTLS=ON \
        -DCMAKE_PREFIX_PATH="$BUILD_DIR/mbedtls-ios-arm64;$BUILD_DIR/opus-ios-arm64"
    cmake --build build-ios-arm64

    # ... 其他平台构建

    # 创建 xcframework
    xcodebuild -create-xcframework \
        -library build-ios-arm64/lib/libchiaki.a \
        -headers lib/include \
        -library build-ios-sim-arm64/lib/libchiaki.a \
        -headers lib/include \
        -library build-macos-arm64/lib/libchiaki.a \
        -headers lib/include \
        -library build-macos-x86_64/lib/libchiaki.a \
        -headers lib/include \
        -library build-tvos-arm64/lib/libchiaki.a \
        -headers lib/include \
        -output "$OUTPUT_DIR/libchiaki.xcframework"

    echo "libchiaki built successfully"
}

# 主函数
main() {
    echo "Starting dependency build..."

    build_mbedtls
    build_opus
    build_libchiaki

    echo "All dependencies built successfully!"
    echo "Frameworks are located at: $OUTPUT_DIR"
}

main "$@"
```

### 4.2 Xcode 项目配置

```
Targets:
├── Chiaki (iOS/iPadOS)
│   ├── Bundle ID: com.chiaki.app
│   ├── Deployment Target: iOS 16.0
│   ├── Frameworks: libchiaki.xcframework, opus.xcframework, mbedcrypto.xcframework
│   └── Capabilities: Background Modes (Audio), Local Network
│
├── Chiaki (macOS)
│   ├── Bundle ID: com.chiaki.app.mac
│   ├── Deployment Target: macOS 13.0
│   ├── Frameworks: (same)
│   └── Capabilities: App Sandbox (Network, USB)
│
├── ChiakiTV (tvOS)
│   ├── Bundle ID: com.chiaki.app.tv
│   ├── Deployment Target: tvOS 16.0
│   ├── Frameworks: (same)
│   └── Capabilities: Game Controllers
│
└── ChiakiTests
    └── Unit and UI Tests
```

---

## 5. 测试策略

### 5.1 单元测试

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

    func testInitialState() {
        XCTAssertEqual(session.state, .idle)
    }

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
        let loaded = await store.loadHosts()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.nickname, "Test PS5")
    }
}
```

### 5.2 集成测试

```swift
// StreamingIntegrationTests.swift
import XCTest
@testable import Chiaki

final class StreamingIntegrationTests: XCTestCase {
    func testVideoRendererInitialization() throws {
        let view = MTKView()
        let renderer = try MetalVideoRenderer(metalView: view)

        XCTAssertNotNil(renderer)
    }

    func testAudioPlayerInitialization() throws {
        let player = try AudioPlayer()

        XCTAssertNotNil(player)
    }
}
```

---

## 6. 错误处理

```swift
// ChiakiError.swift
import Foundation

/// Chiaki 错误定义
enum ChiakiError: LocalizedError {
    case sessionError(SessionError)
    case discoveryError(DiscoveryError)
    case registError(RegistError)
    case videoError(VideoError)
    case audioError(AudioError)
    case networkError(NetworkError)

    var errorDescription: String? {
        switch self {
        case .sessionError(let error): return error.localizedDescription
        case .discoveryError(let error): return error.localizedDescription
        case .registError(let error): return error.localizedDescription
        case .videoError(let error): return error.localizedDescription
        case .audioError(let error): return error.localizedDescription
        case .networkError(let error): return error.localizedDescription
        }
    }
}

enum SessionError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case timeout
    case invalidState

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "连接失败: \(reason)"
        case .authenticationFailed: return "认证失败"
        case .timeout: return "连接超时"
        case .invalidState: return "无效状态"
        }
    }
}

enum DiscoveryError: LocalizedError {
    case wakeupFailed(Int32)
    case hostNotFound

    var errorDescription: String? {
        switch self {
        case .wakeupFailed(let code): return "唤醒失败: \(code)"
        case .hostNotFound: return "未找到主机"
        }
    }
}

enum VideoError: LocalizedError {
    case noMetalDevice
    case commandQueueCreationFailed
    case textureCacheCreationFailed
    case shaderLibraryCreationFailed
    case decodingFailed
}

enum AudioError: LocalizedError {
    case formatCreationFailed
    case engineStartFailed
}

enum NetworkError: LocalizedError {
    case noNetwork
    case localNetworkDenied
}
```

---

## 7. 日志系统

```swift
// Logger.swift
import os.log

/// 日志管理
enum Logger {
    static let subsystem = "com.chiaki.app"

    static let session = os.Logger(subsystem: subsystem, category: "session")
    static let discovery = os.Logger(subsystem: subsystem, category: "discovery")
    static let video = os.Logger(subsystem: subsystem, category: "video")
    static let audio = os.Logger(subsystem: subsystem, category: "audio")
    static let controller = os.Logger(subsystem: subsystem, category: "controller")
    static let network = os.Logger(subsystem: subsystem, category: "network")

    static func log(_ message: String, level: OSLogType = .default, category: os.Logger = session) {
        category.log(level: level, "\(message)")
    }
}

// 使用示例
// Logger.session.info("Session started")
// Logger.video.error("Failed to decode frame: \(error)")
```

---

## 8. 架构优化设计 [增量]

### 8.1 StreamingViewModel 拆分

为了解决 `StreamingViewModel` 职责过重的问题，采用以下拆分策略：

#### 8.1.1 StreamStatsManager (核心逻辑)
- **职责**: 负责每秒从 `libchiaki` 获取统计数据并更新状态。
- **接口**: 
  - `update()`: 触发统计更新。
  - 属性: `bitrate`, `latency`, `packetLoss`, `droppedFrames`, `recoveredFrames` 等。

#### 8.1.2 ControllerInputMapper (核心逻辑)
- **职责**: 将 SwiftUI 的 `VirtualControllerInput` 或系统 `GCController` 输入转换为 `libchiaki` 的协议格式。
- **接口**:
  - `map(_ input: VirtualControllerInput) -> ChiakiControllerInput`

### 8.2 现代化 UI 规范

- **状态管理**: 所有的服务类（如 `DiscoveryService`, `PSNService`）必须从 `ObservableObject` 迁移至 `@Observable`，移除对 `Combine` 的显式依赖（除非是系统框架必须）。
- **视图性能**: 子视图（如 `StreamingOverlay`）应尽可能引用原子类型（如 `Double`, `String`），避免直接持有大型 ViewModel 对象导致的不必要重绘。
- **API 规范**: 统一使用 iOS 17+ 推荐的 API（`.foregroundStyle`, `.clipShape`, `.tint` 等）。

---

## 9. 生产就绪设计 [增量]

### 9.1 网络弹性架构

引入 `NetworkMonitor` 单例：
- **技术栈**: `Network` 框架 (NWPathMonitor)。
- **逻辑**: 
  - 当 `path.status == .satisfied` 变为不满足时，通知 `StreamingViewModel` 进入 `reconnecting` 状态。
  - 恢复后，自动调用 `session.reconnect()`。

### 9.2 本地化方案

- **工具**: 使用 Xcode 15+ `String Catalogs` (.xcstrings)。
- **规范**: 
  - 所有的 UI 字符串必须使用 `String(localized: "key")` 或 `Text("key")`。
  - 所有的 Accessibility Label 必须通过本地化文件配置。

### 9.3 性能管理

- **渲染控制**: 在 `MetalVideoRenderer` 中增加 `isStatic` 检测，若连续 5 帧无变化且非游戏状态，降低 Metal 刷新频率。

---

## 10. 完善日志系统 [增量]

> **变更来源**: F-019 完善日志系统
> **变更日期**: 2026-01-28
> **关联验收标准**: AC-049 ~ AC-053

### 10.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `Logger` | 修改 | 新增 FileLogHandler，修改日志记录流程 |
| `LogViewerView` | 修改 | 新增诊断包导出按钮，读取文件日志 |
| `DiagnosticsExporter` | **新增** | 诊断包生成与敏感信息脱敏 |
| `FileLogHandler` | **新增** | 日志文件持久化与轮换 |
| `CrashReporter` | **新增** | 崩溃捕获与上次崩溃查看 |
| `ChiakiApp` | 修改 | 启动时初始化崩溃捕获 |

#### 兼容性评估

| 变更类型 | 向后兼容 | 说明 |
|----------|----------|------|
| 新增 FileLogHandler | ✅ 兼容 | 新增 handler，不影响现有日志接口 |
| 新增 DiagnosticsExporter | ✅ 兼容 | 新增独立服务 |
| 新增诊断包导出 UI | ✅ 兼容 | 新增按钮，不影响现有功能 |
| 崩溃捕获 | ✅ 兼容 | 仅捕获异常，不影响正常流程 |

### 10.2 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    日志系统架构                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐   ┌──────────────┐   ┌─────────────────┐  │
│  │ logInfo()   │   │ Logger.      │   │ ChiakiLogBridge │  │
│  │ logError()  │──▶│ shared       │◀──│ (libchiaki)     │  │
│  │ Logger.xxx  │   │ @MainActor   │   │                 │  │
│  └─────────────┘   └──────┬───────┘   └─────────────────┘  │
│                           │                                 │
│         ┌─────────────────┼─────────────────┐              │
│         ▼                 ▼                 ▼              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐  │
│  │ OSLogHandler│   │FileLogHandler│   │ logHistory[]   │  │
│  │ (os.log)   │   │ (新增)       │   │ (内存 1000条)   │  │
│  └─────────────┘   └──────┬───────┘   └─────────────────┘  │
│                           │                                 │
│                    ┌──────▼───────┐                        │
│                    │ 日志文件      │                        │
│                    │ Documents/   │                        │
│                    │ Logs/        │                        │
│                    │ ├── chiaki-  │                        │
│                    │ │   current. │                        │
│                    │ │   log      │                        │
│                    │ ├── chiaki-  │                        │
│                    │ │   1.log    │                        │
│                    │ └── ...      │                        │
│                    └──────────────┘                        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    诊断包导出                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐                                       │
│  │DiagnosticsExporter│                                      │
│  └────────┬────────┘                                       │
│           │                                                 │
│    ┌──────┴──────┬──────────────┬──────────────┐          │
│    ▼             ▼              ▼              ▼          │
│ ┌──────┐  ┌───────────┐  ┌───────────┐  ┌─────────────┐  │
│ │日志   │  │设备信息    │  │网络状态    │  │配置快照      │  │
│ │文件   │  │           │  │           │  │(脱敏)       │  │
│ └──────┘  └───────────┘  └───────────┘  └─────────────┘  │
│           │                                                 │
│           ▼                                                 │
│    ┌─────────────────┐                                     │
│    │ 敏感信息脱敏     │                                     │
│    │ - IP 部分遮蔽   │                                     │
│    │ - Token 截断   │                                     │
│    │ - ID 哈希化    │                                     │
│    └────────┬────────┘                                     │
│             ▼                                               │
│    ┌─────────────────┐                                     │
│    │ diagnostics.zip │                                     │
│    └─────────────────┘                                     │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    崩溃捕获                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  App 启动                                                   │
│      │                                                      │
│      ▼                                                      │
│  ┌─────────────────┐                                       │
│  │ CrashReporter   │                                       │
│  │ .initialize()   │                                       │
│  └────────┬────────┘                                       │
│           │                                                 │
│   ┌───────┴───────┐                                        │
│   ▼               ▼                                        │
│ ┌──────────┐  ┌───────────────┐                           │
│ │检查上次   │  │注册信号处理器  │                           │
│ │崩溃日志   │  │SIGABRT/SIGSEGV│                           │
│ └──────────┘  └───────────────┘                           │
│                                                             │
│  运行时异常                                                  │
│      │                                                      │
│      ▼                                                      │
│  ┌─────────────────┐                                       │
│  │ 写入崩溃日志     │                                       │
│  │ crash_report.log│                                       │
│  └─────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 10.3 模块设计

#### 10.3.1 FileLogHandler（新增）

**职责**: 将日志实时写入文件，实现日志轮换策略。

**关联需求**: AC-049 (日志持久化), AC-050 (日志轮换)

```swift
/// 日志文件处理器（关联：AC-049, AC-050）
final class FileLogHandler: LogHandler, @unchecked Sendable {
    // MARK: - Configuration

    /// 单个日志文件最大大小 (5MB)
    static let maxFileSize: UInt64 = 5 * 1024 * 1024

    /// 保留的日志文件数量 (7个)
    static let maxFileCount = 7

    /// 日志目录名
    static let logDirectoryName = "Logs"

    /// 当前日志文件名
    static let currentLogFileName = "chiaki-current.log"

    // MARK: - Properties

    private let fileManager = FileManager.default
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0
    private let writeLock = NSLock()
    private let dateFormatter: DateFormatter

    // MARK: - Initialization

    init() throws

    // MARK: - LogHandler Protocol

    func log(level: ChiakiLogSeverity, message: String,
             file: String, function: String, line: Int)

    // MARK: - File Management

    /// 获取日志目录路径
    func logDirectoryURL() -> URL

    /// 获取所有日志文件（按时间排序）
    func allLogFiles() -> [URL]

    /// 执行日志轮换
    private func rotateIfNeeded()

    /// 清理旧日志文件
    private func cleanupOldLogs()
}
```

**日志轮换策略**:
1. 当 `chiaki-current.log` 超过 5MB 时触发轮换
2. 重命名为 `chiaki-{timestamp}.log`
3. 创建新的 `chiaki-current.log`
4. 删除超过 7 个的旧日志文件
5. 总日志占用空间上限约 35MB

**日志文件格式**:
```
[2026-01-28 10:30:15.123] [INFO] [Session] Connected to PlayStation 5
[2026-01-28 10:30:16.456] [DEBUG] [Network] Packet received, size=1024
[2026-01-28 10:30:17.789] [ERROR] [Video] Decode failed: invalid NAL unit
```

#### 10.3.2 DiagnosticsExporter（新增）

**职责**: 生成诊断包，包含日志、设备信息、网络状态和脱敏后的配置。

**关联需求**: AC-051 (诊断包导出), AC-053 (敏感信息脱敏)

```swift
/// 诊断包导出器（关联：AC-051, AC-053）
@MainActor
final class DiagnosticsExporter {

    // MARK: - Export Content

    struct DiagnosticsPackage {
        let logFiles: [URL]           // 所有日志文件
        let deviceInfo: DeviceInfo    // 设备信息
        let networkInfo: NetworkInfo  // 网络状态
        let configSnapshot: String    // 脱敏后的配置
        let crashReport: String?      // 上次崩溃报告（如有）
    }

    struct DeviceInfo: Codable {
        let model: String             // 设备型号
        let osVersion: String         // 系统版本
        let appVersion: String        // 应用版本
        let buildNumber: String       // 构建号
        let locale: String            // 语言区域
        let timezone: String          // 时区
    }

    struct NetworkInfo: Codable {
        let isConnected: Bool
        let connectionType: String    // WiFi / Cellular / Ethernet
        let isExpensive: Bool
        let isConstrained: Bool
    }

    // MARK: - Public Methods

    /// 生成诊断包 ZIP 文件
    func exportDiagnostics() async throws -> URL

    // MARK: - Sanitization (AC-053)

    /// 脱敏 IP 地址 (192.168.1.100 → 192.168.xxx.xxx)
    func sanitizeIP(_ ip: String) -> String

    /// 脱敏令牌 (显示前8位 + "...")
    func sanitizeToken(_ token: String) -> String

    /// 脱敏用户 ID (SHA256 哈希后取前16位)
    func sanitizeUserID(_ id: String) -> String

    /// 脱敏日志内容
    func sanitizeLogContent(_ content: String) -> String
}
```

**诊断包内容结构**:
```
diagnostics-2026-01-28T103015.zip
├── logs/
│   ├── chiaki-current.log
│   ├── chiaki-1.log
│   └── chiaki-2.log
├── device-info.json
├── network-info.json
├── config-snapshot.json (脱敏后)
└── crash-report.txt (如有)
```

**脱敏规则**:

| 敏感信息类型 | 脱敏规则 | 示例 |
|-------------|---------|------|
| IP 地址 | 保留前两段，后两段替换为 xxx | `192.168.1.100` → `192.168.xxx.xxx` |
| Access Token | 保留前 8 位 + "..." | `eyJhbGciOiJSUzI1NiIsInR5...` → `eyJhbGci...` |
| Refresh Token | 保留前 8 位 + "..." | 同上 |
| PSN ID | SHA256 哈希后取前 16 位 | `player123` → `a1b2c3d4e5f6g7h8` |
| MAC 地址 | 保留前 3 段，后 3 段替换为 XX | `AA:BB:CC:DD:EE:FF` → `AA:BB:CC:XX:XX:XX` |
| 注册密钥 | 完全隐藏 | `[REDACTED]` |

#### 10.3.3 CrashReporter（新增）

**职责**: 捕获应用崩溃，记录崩溃信息供下次启动查看。

**关联需求**: AC-052 (崩溃日志捕获)

```swift
/// 崩溃报告器（关联：AC-052）
final class CrashReporter {
    static let shared = CrashReporter()

    // MARK: - File Paths

    private static let crashReportFileName = "crash_report.log"
    private static let pendingCrashFileName = "pending_crash.log"

    // MARK: - Properties

    private(set) var lastCrashReport: CrashReport?

    struct CrashReport: Codable {
        let timestamp: Date
        let signal: String?           // SIGABRT, SIGSEGV 等
        let exception: String?        // Swift 异常信息
        let stackTrace: [String]      // 调用栈
        let threadInfo: String        // 线程信息
        let lastLogEntries: [String]  // 崩溃前最后 50 条日志
    }

    // MARK: - Initialization

    /// 在 App 启动时调用
    func initialize()

    // MARK: - Signal Handling

    /// 注册信号处理器
    private func registerSignalHandlers()

    /// 信号处理回调
    private static func handleSignal(_ signal: Int32)

    // MARK: - Exception Handling

    /// 设置未捕获异常处理器
    private func setupExceptionHandler()

    // MARK: - Report Management

    /// 检查是否有上次崩溃报告
    func checkForPendingCrash() -> CrashReport?

    /// 清除已查看的崩溃报告
    func clearCrashReport()

    /// 写入崩溃报告
    private func writeCrashReport(_ report: CrashReport)
}
```

**崩溃报告格式**:
```
====== CRASH REPORT ======
Timestamp: 2026-01-28 10:30:15
Signal: SIGSEGV
Thread: com.chiaki.streaming (Thread 5)

Exception:
EXC_BAD_ACCESS (SIGSEGV) at address 0x0000000000000000

Stack Trace:
0   Chiaki                  0x1000a1234 VideoToolboxDecoder.decodeFrame + 156
1   Chiaki                  0x1000a5678 ChiakiSessionWrapper.handleVideoData + 89
2   libchiaki               0x1001b1234 chiaki_session_video_cb + 45
...

Last 50 Log Entries:
[10:30:14.123] [DEBUG] [Video] Received video frame, size=15234
[10:30:14.456] [INFO] [Session] Processing video data
[10:30:15.000] [ERROR] [Video] Invalid NAL unit received
==========================
```

### 10.4 核心接口

#### IFileLogHandler（关联：AC-049, AC-050）

| 方法 | 参数 | 返回值 | 关联 | 说明 |
|------|------|--------|------|------|
| `log` | `level, message, file, function, line` | `void` | AC-049 | 写入日志到文件 |
| `logDirectoryURL` | - | `URL` | AC-049 | 获取日志目录 |
| `allLogFiles` | - | `[URL]` | AC-049 | 获取所有日志文件 |
| `rotateIfNeeded` | - | `void` | AC-050 | 检查并执行轮换 |
| `cleanupOldLogs` | - | `void` | AC-050 | 清理旧日志 |

#### IDiagnosticsExporter（关联：AC-051, AC-053）

| 方法 | 参数 | 返回值 | 关联 | 说明 |
|------|------|--------|------|------|
| `exportDiagnostics` | - | `URL` (async) | AC-051 | 生成诊断包 |
| `sanitizeIP` | `String` | `String` | AC-053 | 脱敏 IP |
| `sanitizeToken` | `String` | `String` | AC-053 | 脱敏令牌 |
| `sanitizeUserID` | `String` | `String` | AC-053 | 脱敏用户 ID |
| `sanitizeLogContent` | `String` | `String` | AC-053 | 脱敏日志内容 |

#### ICrashReporter（关联：AC-052）

| 方法 | 参数 | 返回值 | 关联 | 说明 |
|------|------|--------|------|------|
| `initialize` | - | `void` | AC-052 | 初始化崩溃捕获 |
| `checkForPendingCrash` | - | `CrashReport?` | AC-052 | 检查上次崩溃 |
| `clearCrashReport` | - | `void` | AC-052 | 清除崩溃报告 |

### 10.5 代码结构变更

```
Chiaki/
├── Utilities/
│   ├── Logger.swift                    # 修改：集成 FileLogHandler
│   ├── FileLogHandler.swift            # 新增：日志文件持久化
│   ├── CrashReporter.swift             # 新增：崩溃捕获
│   └── DiagnosticsExporter.swift       # 新增：诊断包导出
│
├── Features/
│   └── Settings/
│       ├── LogViewerView.swift         # 修改：新增诊断包导出按钮
│       └── CrashReportView.swift       # 新增：崩溃报告查看
│
└── App/
    └── ChiakiApp.swift                 # 修改：启动时初始化 CrashReporter
```

### 10.6 Logger 修改

需要修改现有 `Logger` 类以集成 `FileLogHandler`：

```swift
// Logger.swift 修改

@MainActor
final class Logger: Sendable {
    static let shared = Logger()

    private var handlers: [LogHandler]
    // ... existing code ...

    private init() {
        #if DEBUG
        self.levelMask = .all
        #else
        self.levelMask = .production
        #endif

        var initialHandlers: [LogHandler] = []

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            let osLogHandler = OSLogHandler(subsystem: "ltd.hotter.chiaki", category: "App")
            initialHandlers.append(osLogHandler)

            // 新增：文件日志处理器 (AC-049)
            if let fileHandler = try? FileLogHandler() {
                initialHandlers.append(fileHandler)
            }
        }

        self.handlers = initialHandlers
    }

    // 新增：获取 FileLogHandler 以访问日志文件
    var fileLogHandler: FileLogHandler? {
        handlers.compactMap { $0 as? FileLogHandler }.first
    }
}
```

### 10.7 UI 变更

#### LogViewerView 修改

```swift
// LogViewerView.swift 新增按钮

HStack {
    // 现有的级别筛选...

    Spacer()

    // 现有的导出按钮
    Button(action: { exportLogs() }) {
        Label(L10n.Settings.Logs.export, systemImage: "square.and.arrow.up")
    }

    // 新增：诊断包导出按钮 (AC-051)
    Button(action: { exportDiagnostics() }) {
        Label(L10n.Settings.Logs.exportDiagnostics, systemImage: "doc.zipper")
    }
}
```

#### CrashReportView（新增）

```swift
/// 崩溃报告查看视图（关联：AC-052）
struct CrashReportView: View {
    let crashReport: CrashReporter.CrashReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 崩溃时间
                    // 信号/异常信息
                    // 调用栈
                    // 最后日志条目
                }
            }
            .navigationTitle(L10n.CrashReport.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.CrashReport.dismiss) {
                        CrashReporter.shared.clearCrashReport()
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### 10.8 初始化流程

```swift
// ChiakiApp.swift 修改

@main
struct ChiakiApp: App {
    @State private var showCrashReport = false
    @State private var pendingCrashReport: CrashReporter.CrashReport?

    init() {
        // 初始化崩溃捕获 (AC-052)
        CrashReporter.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 检查上次崩溃 (AC-052)
                    if let crash = CrashReporter.shared.checkForPendingCrash() {
                        pendingCrashReport = crash
                        showCrashReport = true
                    }
                }
                .sheet(isPresented: $showCrashReport) {
                    if let report = pendingCrashReport {
                        CrashReportView(crashReport: report)
                    }
                }
        }
    }
}
```

### 10.9 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-049: 日志持久化 | `FileLogHandler` | 日志实时写入文件，重启后可查看 |
| AC-050: 日志轮换 | `FileLogHandler.rotateIfNeeded()` | 5MB/文件，保留 7 个，上限 35MB |
| AC-051: 诊断包导出 | `DiagnosticsExporter` | 一键生成 ZIP 包含完整诊断信息 |
| AC-052: 崩溃捕获 | `CrashReporter` | 信号/异常捕获，下次启动可查看 |
| AC-053: 敏感信息脱敏 | `DiagnosticsExporter.sanitize*()` | IP/Token/ID 自动脱敏 |

---

## 设计变更记录

### v1.3.0 (2026-01-28)

**变更来源**: F-019 完善日志系统 (INS-011 ~ INS-015)

**新增模块**:
- `FileLogHandler` - 日志文件持久化（关联 AC-049, AC-050）
- `DiagnosticsExporter` - 诊断包导出与脱敏（关联 AC-051, AC-053）
- `CrashReporter` - 崩溃捕获（关联 AC-052）
- `CrashReportView` - 崩溃报告查看 UI

**修改模块**:
- `Logger` - 集成 FileLogHandler
- `LogViewerView` - 新增诊断包导出按钮
- `ChiakiApp` - 启动时初始化崩溃捕获

**破坏性变更**: 无

**迁移说明**: 无需迁移，纯增量功能
