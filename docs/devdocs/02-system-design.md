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

---

### v1.4.0 (2026-01-30)

**变更来源**: F-020 手柄操作友好化 (INS-017 ~ INS-022), F-021 GameController 深度集成 (INS-023 ~ INS-026)

**新增模块**:
- `FocusableButtonStyle` - tvOS 焦点视觉反馈样式（关联 AC-056）
- `ControllerShortcutDetector` - 手柄组合键检测器（关联 AC-059）

**修改模块**:
- `StreamingControlsView` - 焦点管理、焦点陷阱、焦点恢复（关联 AC-055, AC-057, AC-060）
- `StreamingView` - tvOS 方向键导航（关联 AC-058）
- `ControllerManager` - 自适应扳机、触控板追踪、电池信息、组合键检测（关联 AC-059, AC-061, AC-062, AC-064）
- `HapticsManager` - 统一引擎管理（关联 AC-063）

**破坏性变更**: 无

**迁移说明**: 无需迁移，纯增量功能

---

## 11. 手柄操作友好化设计 [增量]

> **变更来源**: F-020 手柄操作友好化 (INS-017 ~ INS-022)
> **关联需求**: AC-055 ~ AC-060

### 11.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| StreamingControlsView | 修改 | 添加焦点状态管理、焦点陷阱、焦点恢复 |
| StreamingView | 修改 | 添加 tvOS 方向键导航命令处理 |
| ControllerManager | 修改 | 添加组合键检测逻辑 |
| FocusableButtonStyle | 新增 | tvOS 焦点视觉反馈样式 |
| ControllerShortcutDetector | 新增 | 组合键检测器 |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| 新增焦点状态管理 | ✅ 兼容 | 纯 UI 增强 |
| 新增 tvOS 导航命令 | ✅ 兼容 | 平台条件编译 |
| 新增组合键检测 | ✅ 兼容 | 可选功能，默认启用 |

### 11.2 焦点管理设计

#### 焦点状态枚举（关联 AC-055）

```swift
/// 流媒体控制菜单焦点状态
enum StreamingControlFocus: Hashable {
    case disconnectButton
    case micToggle
    case volumeSlider
    case qualityPicker
    case statsToggle
    case closeButton
}
```

#### StreamingControlsView 焦点集成（关联 AC-055, AC-060）

```swift
struct StreamingControlsView: View {
    @FocusState private var focusedControl: StreamingControlFocus?
    @State private var previousFocus: StreamingControlFocus?

    var body: some View {
        VStack {
            // 断开连接按钮
            Button(L10n.Streaming.disconnect) { ... }
                .focused($focusedControl, equals: .disconnectButton)

            // 麦克风切换
            Toggle(L10n.Streaming.microphone, isOn: $micEnabled)
                .focused($focusedControl, equals: .micToggle)

            // 其他控件...
        }
        .onAppear {
            // 菜单打开时聚焦到第一个控件
            focusedControl = .disconnectButton
        }
        .onDisappear {
            // 记录关闭前的焦点位置
            previousFocus = focusedControl
        }
    }

    /// 恢复焦点（关联 AC-060）
    func restoreFocus() {
        focusedControl = previousFocus ?? .disconnectButton
    }
}
```

### 11.3 tvOS 焦点视觉反馈（关联 AC-056）

```swift
/// tvOS 焦点按钮样式
struct FocusableButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .shadow(color: isFocused ? .accentColor.opacity(0.5) : .clear, radius: 10)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
```

### 11.4 焦点陷阱设计（关联 AC-057）

```swift
struct StreamingView: View {
    @State private var showControls = false

    var body: some View {
        ZStack {
            // 视频层
            VideoPlayerView()
                .disabled(showControls)  // 焦点陷阱：菜单打开时禁用背景

            // 控制菜单
            if showControls {
                StreamingControlsView()
                    .focusSection()  // tvOS 焦点边界
            }
        }
    }
}
```

### 11.5 tvOS 方向键导航（关联 AC-058）

```swift
extension StreamingView {
    var body: some View {
        content
            #if os(tvOS)
            .onMoveCommand { direction in
                handleMoveCommand(direction)
            }
            .onExitCommand {
                handleExitCommand()
            }
            .onPlayPauseCommand {
                handlePlayPauseCommand()
            }
            #endif
    }

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up, .down, .left, .right:
            // 方向键导航由 SwiftUI 焦点系统自动处理
            break
        @unknown default:
            break
        }
    }

    private func handleExitCommand() {
        if showControls {
            showControls = false
        } else {
            // 触发退出确认
            showExitConfirmation = true
        }
    }
    #endif
}
```

### 11.6 组合键检测设计（关联 AC-059）

```swift
/// 手柄组合键检测器
@Observable
final class ControllerShortcutDetector {
    // MARK: - Configuration

    /// 组合键防抖时间（毫秒）
    private let debounceInterval: TimeInterval = 0.2

    /// 组合键回调
    var onMenuShortcut: (() -> Void)?        // PS + Options
    var onDisconnectShortcut: (() -> Void)?  // L1 + R1 + PS

    // MARK: - State

    private var lastShortcutTime: Date = .distantPast
    private var currentButtons: ControllerButtons = []

    // MARK: - Detection

    /// 更新按钮状态并检测组合键
    func updateButtons(_ buttons: ControllerButtons) {
        let previousButtons = currentButtons
        currentButtons = buttons

        // 检测新按下的组合键（防止持续触发）
        let newlyPressed = buttons.subtracting(previousButtons)
        guard !newlyPressed.isEmpty else { return }

        // 防抖检查
        let now = Date()
        guard now.timeIntervalSince(lastShortcutTime) > debounceInterval else { return }

        // PS + Options → 打开/关闭菜单
        if buttons.contains([.ps, .options]) {
            lastShortcutTime = now
            onMenuShortcut?()
            return
        }

        // L1 + R1 + PS → 断开连接
        if buttons.contains([.l1, .r1, .ps]) {
            lastShortcutTime = now
            onDisconnectShortcut?()
            return
        }
    }
}
```

#### ControllerManager 集成

```swift
extension ControllerManager {
    private let shortcutDetector = ControllerShortcutDetector()

    func setupShortcuts(
        onMenu: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) {
        shortcutDetector.onMenuShortcut = onMenu
        shortcutDetector.onDisconnectShortcut = onDisconnect
    }

    // 在按钮状态变化时调用
    private func handleButtonChange(_ buttons: ControllerButtons) {
        // 先检测组合键
        shortcutDetector.updateButtons(buttons)

        // 再更新常规状态
        currentState.buttons = buttons
        onStateChanged?(currentState)
    }
}
```

### 11.7 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-055: 焦点导航 | `StreamingControlsView` + `@FocusState` | 方向键在控件间移动焦点 |
| AC-056: 焦点反馈 | `FocusableButtonStyle` | 缩放 + 边框 + 阴影 |
| AC-057: 焦点陷阱 | `StreamingView.disabled()` + `focusSection()` | 菜单打开时禁用背景 |
| AC-058: 方向键导航 | `onMoveCommand` / `onExitCommand` | tvOS 完整导航命令 |
| AC-059: 组合键快捷 | `ControllerShortcutDetector` | PS+Options / L1+R1+PS |
| AC-060: 焦点恢复 | `previousFocus` 状态 | 菜单关闭后恢复焦点 |

---

## 12. GameController 深度集成设计 [增量]

> **变更来源**: F-021 GameController 深度集成 (INS-023 ~ INS-026)
> **关联需求**: AC-061 ~ AC-064

### 12.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| ControllerManager | 修改 | 自适应扳机、触控板追踪、电池信息 |
| HapticsManager | 修改 | 统一 CHHapticEngine 实例 |
| ChiakiSessionWrapper | 修改 | 暴露扳机效果事件回调 |
| StreamingControlsView | 修改 | 显示电池电量指示器 |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| 自适应扳机 | ✅ 兼容 | 可选功能，需 iOS 16+ |
| 触控板追踪 | ✅ 兼容 | 增量数据，不影响现有逻辑 |
| Haptics 统一 | ✅ 兼容 | 内部重构，接口不变 |
| 电池显示 | ✅ 兼容 | 纯 UI 增强 |

### 12.2 自适应扳机设计（关联 AC-061）

#### 扳机效果类型

```swift
/// DualSense 自适应扳机效果
enum AdaptiveTriggerEffect {
    case off                                    // 关闭
    case feedback(startPosition: Float, strength: Float)  // 反馈模式
    case weapon(startPosition: Float, endPosition: Float, strength: Float)  // 武器模式
    case vibration(position: Float, amplitude: Float, frequency: Float)  // 振动模式
}
```

#### ControllerManager 扩展

```swift
extension ControllerManager {
    /// 应用自适应扳机效果（关联 AC-061）
    /// - Parameters:
    ///   - effect: 扳机效果
    ///   - trigger: 目标扳机 (.left / .right)
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, trigger: TriggerSide) {
        guard let dualSense = activeController?.physicalInputProfile as? GCDualSenseGamepad else {
            return
        }

        let triggerInput = trigger == .left ? dualSense.leftTrigger : dualSense.rightTrigger
        guard let adaptiveTrigger = triggerInput.adaptiveTriggers else { return }

        switch effect {
        case .off:
            adaptiveTrigger.setModeOff()
        case .feedback(let start, let strength):
            adaptiveTrigger.setModeFeedbackWithStartPosition(start, resistiveStrength: strength)
        case .weapon(let start, let end, let strength):
            adaptiveTrigger.setModeWeaponWithStartPosition(start, endPosition: end, resistiveStrength: strength)
        case .vibration(let position, let amplitude, let frequency):
            adaptiveTrigger.setModeVibrationWithAmplitude(amplitude, frequency: frequency, position: position)
        }
    }

    enum TriggerSide {
        case left, right
    }
}
```

#### 与 ChiakiSession 集成

```swift
// ChiakiSessionWrapper 扩展
extension ChiakiSessionWrapper {
    /// 扳机效果事件回调
    var onTriggerEffects: ((TriggerEffectsEvent) -> Void)?

    struct TriggerEffectsEvent {
        let leftEffect: AdaptiveTriggerEffect
        let rightEffect: AdaptiveTriggerEffect
    }
}

// StreamingViewModel 集成
func setupTriggerEffects() {
    session.onTriggerEffects = { [weak self] event in
        self?.controllerManager.applyAdaptiveTrigger(effect: event.leftEffect, trigger: .left)
        self?.controllerManager.applyAdaptiveTrigger(effect: event.rightEffect, trigger: .right)
    }
}
```

### 12.3 触控板位置追踪（关联 AC-062）

```swift
extension ControllerManager {
    /// 触控板触摸点
    struct TouchPoint: Equatable {
        let id: Int           // 触摸点 ID（支持多点）
        let x: Float          // 归一化 X 坐标 (0.0 ~ 1.0)
        let y: Float          // 归一化 Y 坐标 (0.0 ~ 1.0)
        let isActive: Bool    // 是否正在触摸
    }

    /// 设置触控板输入处理（关联 AC-062）
    private func setupTouchpadInput(_ dualSense: GCDualSenseGamepad) {
        // 主触摸点
        if let touchpad = dualSense.touchpadPrimary {
            touchpad.touchSurface?.valueChangedHandler = { [weak self] _, x, y, touching, _ in
                self?.updateTouchPoint(id: 0, x: x, y: y, isActive: touching)
            }
        }

        // 次触摸点（如果支持）
        if let touchpad2 = dualSense.touchpadSecondary {
            touchpad2.touchSurface?.valueChangedHandler = { [weak self] _, x, y, touching, _ in
                self?.updateTouchPoint(id: 1, x: x, y: y, isActive: touching)
            }
        }
    }

    private func updateTouchPoint(id: Int, x: Float, y: Float, isActive: Bool) {
        let point = TouchPoint(id: id, x: x, y: y, isActive: isActive)

        // 更新状态
        if let index = currentState.touchpad.firstIndex(where: { $0.id == id }) {
            if isActive {
                currentState.touchpad[index] = point
            } else {
                currentState.touchpad.remove(at: index)
            }
        } else if isActive {
            currentState.touchpad.append(point)
        }

        onStateChanged?(currentState)
    }
}
```

### 12.4 Haptics 引擎统一（关联 AC-063）

```swift
/// 触觉反馈管理器（统一引擎）
@Observable
final class HapticsManager {
    static let shared = HapticsManager()

    // MARK: - Private Properties

    private var engine: CHHapticEngine?
    private var isEngineRunning = false

    // MARK: - Initialization

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                self?.restartEngine()
            }
            engine?.stoppedHandler = { [weak self] _ in
                self?.isEngineRunning = false
            }
        } catch {
            Logger.shared.error("Failed to create haptic engine: \(error)")
        }
    }

    // MARK: - Public Interface

    /// 启动引擎（由 ControllerManager 调用）
    func startEngine() {
        guard let engine = engine, !isEngineRunning else { return }

        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            Logger.shared.error("Failed to start haptic engine: \(error)")
        }
    }

    /// 停止引擎
    func stopEngine() {
        engine?.stop()
        isEngineRunning = false
    }

    /// 应用震动反馈（关联 AC-063）
    /// - Parameters:
    ///   - leftIntensity: 左马达强度 (0-255)
    ///   - rightIntensity: 右马达强度 (0-255)
    func applyRumble(left leftIntensity: UInt8, right rightIntensity: UInt8) {
        guard isEngineRunning, let engine = engine else { return }

        let leftNormalized = Float(leftIntensity) / 255.0
        let rightNormalized = Float(rightIntensity) / 255.0

        // 创建并播放震动事件
        do {
            let events = createRumbleEvents(left: leftNormalized, right: rightNormalized)
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Logger.shared.debug("Rumble playback failed: \(error)")
        }
    }

    private func createRumbleEvents(left: Float, right: Float) -> [CHHapticEvent] {
        // 低频（左马达）+ 高频（右马达）组合
        [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: left),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 0.1
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: right),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0,
                duration: 0.1
            )
        ]
    }

    private func restartEngine() {
        do {
            try engine?.start()
            isEngineRunning = true
        } catch {
            Logger.shared.error("Failed to restart haptic engine: \(error)")
        }
    }
}
```

#### ControllerManager 集成

```swift
extension ControllerManager {
    /// 应用震动（委托给 HapticsManager）
    func applyRumble(left: UInt8, right: UInt8) {
        HapticsManager.shared.applyRumble(left: left, right: right)
    }

    /// 初始化时启动引擎
    func startHaptics() {
        HapticsManager.shared.startEngine()
    }

    /// 断开时停止引擎
    func stopHaptics() {
        HapticsManager.shared.stopEngine()
    }
}
```

### 12.5 控制器电池电量显示（关联 AC-064）

#### 电池信息模型

```swift
extension ControllerManager {
    /// 控制器电池信息
    struct BatteryInfo: Equatable {
        let level: Float           // 电量 (0.0 ~ 1.0)
        let state: BatteryState    // 状态

        enum BatteryState {
            case unknown
            case discharging
            case charging
            case full
        }

        var isLow: Bool { level < 0.2 }

        var iconName: String {
            switch state {
            case .charging: return "battery.100.bolt"
            case .full: return "battery.100"
            default:
                if level > 0.75 { return "battery.100" }
                if level > 0.5 { return "battery.75" }
                if level > 0.25 { return "battery.50" }
                return "battery.25"
            }
        }

        var color: Color {
            if state == .charging { return .green }
            if isLow { return .red }
            return .primary
        }
    }

    /// 当前控制器电池信息
    var batteryInfo: BatteryInfo? {
        guard let controller = activeController,
              let battery = controller.battery else { return nil }

        let state: BatteryInfo.BatteryState = switch battery.batteryState {
        case .charging: .charging
        case .discharging: .discharging
        case .full: .full
        default: .unknown
        }

        return BatteryInfo(level: battery.batteryLevel, state: state)
    }
}
```

#### UI 组件

```swift
/// 控制器电池指示器
struct ControllerBatteryIndicator: View {
    let batteryInfo: ControllerManager.BatteryInfo?

    var body: some View {
        if let info = batteryInfo {
            HStack(spacing: 4) {
                Image(systemName: info.iconName)
                    .foregroundStyle(info.color)

                if info.isLow {
                    Text(String(format: "%.0f%%", info.level * 100))
                        .font(.caption)
                        .foregroundStyle(info.color)
                }
            }
            .accessibilityLabel(L10n.Accessibility.batteryLevel(Int(info.level * 100)))
        }
    }
}

// 在 StreamingControlsView 中使用
struct StreamingControlsView: View {
    @Environment(ControllerManager.self) private var controllerManager

    var body: some View {
        HStack {
            // 其他控件...

            Spacer()

            // 电池指示器
            ControllerBatteryIndicator(batteryInfo: controllerManager.batteryInfo)
        }
    }
}
```

### 12.6 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-061: 自适应扳机 | `ControllerManager.applyAdaptiveTrigger()` | iOS 16+ 扳机效果 |
| AC-062: 触控板追踪 | `setupTouchpadInput()` + `TouchPoint` | 多点触控位置 |
| AC-063: Haptics 统一 | `HapticsManager.shared` | 单例引擎管理 |
| AC-064: 电池显示 | `BatteryInfo` + `ControllerBatteryIndicator` | 电量图标 + 低电量警告 |

---

## 13. 手柄操控 UI/UX 优化设计 [增量]

> **变更来源**: F-022 手柄操控 UI/UX 优化 (INS-028 ~ INS-031)
> **关联需求**: AC-065 ~ AC-068
> **设计版本**: v1.5.0

### 13.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| HostListView / TVHostCardView | 修改 | 添加快速操作栏，替代长按菜单 |
| ControllerShortcutDetector | 修改 | 扩展 PS+L2/R2 音量快捷键检测 |
| StreamingViewModel | 修改 | 添加音量快捷调节逻辑 |
| ConsolePinView | 修改 | 集成数字键盘组件 |
| StreamingControlsView | 修改 | 添加快速设置 Section |
| HostQuickActionBar | 新增 | 主机快速操作栏组件 |
| GamepadNumPad | 新增 | 手柄友好的数字键盘 |
| QuickSettingsSection | 新增 | 流媒体快速设置面板 |
| VolumeOSD | 新增 | 音量调节浮层提示 |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| 快速操作栏 | ✅ 兼容 | 纯 UI 增强，长按菜单保留作为备选 |
| 音量快捷键 | ✅ 兼容 | 可选功能，不影响现有操作 |
| 数字键盘 | ✅ 兼容 | 替代系统键盘，功能等效 |
| 快速设置 | ✅ 兼容 | 增量功能，不影响完整设置页 |

### 13.2 主机快速操作栏设计（关联 AC-065）

#### 设计思路

- 当主机卡片获得焦点时，底部显示快速操作栏
- 操作栏包含：唤醒/连接、PIN 设置、删除
- tvOS 使用 swipe 手势或 Menu 键触发
- iOS/macOS 保留长按上下文菜单作为备选

#### 焦点状态枚举

```swift
/// 主机卡片快速操作焦点
enum HostQuickAction: Hashable {
    case wake       // 唤醒
    case connect    // 连接
    case pin        // 设置 PIN
    case delete     // 删除
}
```

#### HostQuickActionBar 组件

```swift
/// 主机快速操作栏（关联 AC-065）
struct HostQuickActionBar: View {
    let host: Host
    let onWake: () -> Void
    let onConnect: () -> Void
    let onSetPin: () -> Void
    let onDelete: () -> Void

    @FocusState private var focusedAction: HostQuickAction?

    var body: some View {
        HStack(spacing: 16) {
            // 唤醒/连接按钮（根据主机状态）
            if host.state == .standby {
                ActionButton(
                    icon: "power",
                    label: L10n.Host.wake,
                    action: onWake
                )
                .focused($focusedAction, equals: .wake)
            } else if host.state == .ready {
                ActionButton(
                    icon: "play.fill",
                    label: L10n.Host.connect,
                    action: onConnect
                )
                .focused($focusedAction, equals: .connect)
            }

            ActionButton(
                icon: "lock.shield",
                label: L10n.Host.setPin,
                action: onSetPin
            )
            .focused($focusedAction, equals: .pin)

            ActionButton(
                icon: "trash",
                label: L10n.Host.delete,
                role: .destructive,
                action: onDelete
            )
            .focused($focusedAction, equals: .delete)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: ChiakiTheme.Radius.medium))
        .onAppear {
            // 默认聚焦到第一个操作
            focusedAction = host.state == .standby ? .wake : .connect
        }
    }
}

/// 操作按钮子组件
private struct ActionButton: View {
    let icon: String
    let label: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(label, systemImage: icon)
        }
        .buttonStyle(FocusableButtonStyle())
    }
}
```

#### HostListView 集成

```swift
struct HostListView: View {
    @FocusState private var focusedHost: Host.ID?
    @State private var showQuickActions = false

    var body: some View {
        ForEach(hosts) { host in
            VStack(spacing: 8) {
                HostCardView(host: host)
                    .focused($focusedHost, equals: host.id)

                // 快速操作栏：聚焦时显示
                if focusedHost == host.id && showQuickActions {
                    HostQuickActionBar(
                        host: host,
                        onWake: { wakeHost(host) },
                        onConnect: { connectToHost(host) },
                        onSetPin: { showPinSheet(host) },
                        onDelete: { deleteHost(host) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: focusedHost)
        }
        #if os(tvOS)
        .onPlayPauseCommand {
            // Menu 键切换快速操作栏显示
            showQuickActions.toggle()
        }
        #endif
    }
}
```

### 13.3 音量快捷调节设计（关联 AC-066）

#### 设计思路

- 扩展 `ControllerShortcutDetector` 检测 PS+L2/R2
- 音量调节步长为 5%
- 显示临时 OSD 提示当前音量
- 防止快速重复触发（节流 200ms）

#### ControllerShortcutDetector 扩展

```swift
extension ControllerShortcutDetector {
    /// 音量快捷键回调
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    /// 检测音量快捷键（关联 AC-066）
    private func detectVolumeShortcuts(_ buttons: Set<GamepadButton>) {
        let now = Date()

        // PS + L2 → 音量 -5%
        if buttons.contains([.ps, .l2]) && !buttons.contains(.r2) {
            if now.timeIntervalSince(lastVolumeChange) >= volumeThrottleInterval {
                onVolumeDown?()
                lastVolumeChange = now
            }
        }

        // PS + R2 → 音量 +5%
        if buttons.contains([.ps, .r2]) && !buttons.contains(.l2) {
            if now.timeIntervalSince(lastVolumeChange) >= volumeThrottleInterval {
                onVolumeUp?()
                lastVolumeChange = now
            }
        }
    }

    private var lastVolumeChange = Date.distantPast
    private let volumeThrottleInterval: TimeInterval = 0.2  // 200ms 节流
}
```

#### VolumeOSD 组件

```swift
/// 音量调节 OSD 浮层（关联 AC-066）
struct VolumeOSD: View {
    let volume: Float  // 0.0 ~ 1.0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon)
                .font(.system(size: 24))
                .foregroundStyle(.white)

            // 音量条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.3))

                    Capsule()
                        .fill(.white)
                        .frame(width: geo.size.width * CGFloat(volume))
                }
            }
            .frame(width: 120, height: 6)

            Text("\(Int(volume * 100))%")
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8)
    }

    private var volumeIcon: String {
        if volume == 0 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
```

#### StreamingViewModel 集成

```swift
extension StreamingViewModel {
    /// 设置音量快捷键（关联 AC-066）
    func setupVolumeShortcuts() {
        shortcutDetector.onVolumeUp = { [weak self] in
            self?.adjustVolume(by: 0.05)
        }
        shortcutDetector.onVolumeDown = { [weak self] in
            self?.adjustVolume(by: -0.05)
        }
    }

    /// 调节音量
    /// - Parameter delta: 变化量 (-1.0 ~ 1.0)
    func adjustVolume(by delta: Float) {
        let newVolume = max(0, min(1, settings.volume + delta))
        settings.volume = newVolume

        // 显示 OSD
        showVolumeOSD = true

        // 2 秒后自动隐藏
        volumeOSDTask?.cancel()
        volumeOSDTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showVolumeOSD = false
        }
    }

    @Published var showVolumeOSD = false
    private var volumeOSDTask: Task<Void, Never>?
}
```

### 13.4 PIN 输入数字键盘设计（关联 AC-067）

#### 设计思路

- 创建 3×4 数字键盘网格
- 使用 `@FocusState` 管理键位焦点
- 支持方向键导航、确认键输入
- 退格键删除最后一位
- 输入完成 4 位自动提交

#### GamepadNumPad 组件

```swift
/// 手柄友好的数字键盘（关联 AC-067）
struct GamepadNumPad: View {
    @Binding var value: String
    let maxLength: Int = 4
    let onComplete: (String) -> Void

    @FocusState private var focusedKey: NumPadKey?

    enum NumPadKey: String, CaseIterable {
        case key1 = "1", key2 = "2", key3 = "3"
        case key4 = "4", key5 = "5", key6 = "6"
        case key7 = "7", key8 = "8", key9 = "9"
        case empty = "", key0 = "0", backspace = "⌫"

        var displayValue: String { rawValue }
        var isBackspace: Bool { self == .backspace }
        var isEmpty: Bool { self == .empty }
    }

    private let keys: [[NumPadKey]] = [
        [.key1, .key2, .key3],
        [.key4, .key5, .key6],
        [.key7, .key8, .key9],
        [.empty, .key0, .backspace]
    ]

    var body: some View {
        VStack(spacing: 16) {
            // PIN 显示
            HStack(spacing: 12) {
                ForEach(0..<maxLength, id: \.self) { index in
                    PinDigitView(
                        digit: index < value.count ? String(value[value.index(value.startIndex, offsetBy: index)]) : nil,
                        isFilled: index < value.count
                    )
                }
            }
            .padding(.bottom, 8)

            // 数字键盘
            VStack(spacing: 12) {
                ForEach(keys.indices, id: \.self) { rowIndex in
                    HStack(spacing: 12) {
                        ForEach(keys[rowIndex], id: \.rawValue) { key in
                            NumPadButton(key: key) {
                                handleKeyPress(key)
                            }
                            .focused($focusedKey, equals: key)
                            .disabled(key.isEmpty)
                            .opacity(key.isEmpty ? 0 : 1)
                        }
                    }
                }
            }
        }
        .onAppear {
            focusedKey = .key5  // 默认聚焦到中间
        }
    }

    private func handleKeyPress(_ key: NumPadKey) {
        if key.isBackspace {
            if !value.isEmpty {
                value.removeLast()
            }
        } else if !key.isEmpty && value.count < maxLength {
            value.append(key.rawValue)

            // 输入完成自动提交
            if value.count == maxLength {
                onComplete(value)
            }
        }
    }
}

/// PIN 数字显示框
private struct PinDigitView: View {
    let digit: String?
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isFilled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .frame(width: 48, height: 56)

            if let digit {
                Text(digit)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

/// 数字键按钮
private struct NumPadButton: View {
    let key: GamepadNumPad.NumPadKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 64, height: 56)

                if key.isBackspace {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20))
                } else {
                    Text(key.displayValue)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                }
            }
        }
        .buttonStyle(FocusableButtonStyle())
    }
}
```

#### ConsolePinView 集成

```swift
struct ConsolePinView: View {
    @State private var pin = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(L10n.Pin.enterPin)
                .font(.headline)

            #if os(tvOS)
            // tvOS 使用数字键盘
            GamepadNumPad(value: $pin, onComplete: onSubmit)
            #else
            // iOS/macOS 提供两种输入方式
            if UIDevice.current.userInterfaceIdiom == .tv || showNumPad {
                GamepadNumPad(value: $pin, onComplete: onSubmit)

                Button(L10n.Pin.useKeyboard) {
                    showNumPad = false
                }
                .font(.caption)
            } else {
                TextField(L10n.Pin.placeholder, text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)

                Button(L10n.Pin.useNumPad) {
                    showNumPad = true
                }
                .font(.caption)
            }
            #endif
        }
    }

    @State private var showNumPad = false
}
```

### 13.5 快速设置入口设计（关联 AC-068）

#### 设计思路

- 在流媒体控制菜单中添加"快速设置"折叠面板
- 包含可热更新的设置：码率、音量
- 需要重连的设置（分辨率）标注提示
- 设置变更即时生效或标记待重连

#### QuickSettingsSection 组件

```swift
/// 流媒体快速设置面板（关联 AC-068）
struct QuickSettingsSection: View {
    @Environment(SettingsStore.self) private var settings
    @State private var isExpanded = false
    @State private var pendingResolution: Resolution?

    var body: some View {
        DisclosureGroup(L10n.Streaming.quickSettings, isExpanded: $isExpanded) {
            VStack(spacing: 16) {
                // 码率调整（可热更新）
                HStack {
                    Label(L10n.Settings.bitrate, systemImage: "speedometer")
                    Spacer()
                    Stepper(
                        "\(settings.bitrate / 1000) Mbps",
                        value: Binding(
                            get: { settings.bitrate },
                            set: { settings.bitrate = $0 }
                        ),
                        in: 5000...50000,
                        step: 5000
                    )
                }

                // 音量调整（可热更新）
                HStack {
                    Label(L10n.Settings.volume, systemImage: volumeIcon)
                    Slider(value: Binding(
                        get: { Double(settings.volume) },
                        set: { settings.volume = Float($0) }
                    ), in: 0...1)
                    Text("\(Int(settings.volume * 100))%")
                        .font(.caption)
                        .frame(width: 40)
                }

                Divider()

                // 分辨率选择（需要重连）
                HStack {
                    Label(L10n.Settings.resolution, systemImage: "rectangle.on.rectangle")
                    Spacer()
                    Picker("", selection: $pendingResolution.animation()) {
                        Text("720p").tag(Resolution?.some(.r720p))
                        Text("1080p").tag(Resolution?.some(.r1080p))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                if pendingResolution != nil && pendingResolution != settings.resolution {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(L10n.Streaming.resolutionChangeRequiresReconnect)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.Streaming.applyAndReconnect) {
                            applyResolutionChange()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            pendingResolution = settings.resolution
        }
    }

    private var volumeIcon: String {
        if settings.volume == 0 { return "speaker.slash" }
        if settings.volume < 0.5 { return "speaker.wave.1" }
        return "speaker.wave.2"
    }

    private func applyResolutionChange() {
        guard let newResolution = pendingResolution else { return }
        settings.resolution = newResolution
        // 触发重连
        NotificationCenter.default.post(name: .reconnectRequired, object: nil)
    }
}

extension Notification.Name {
    static let reconnectRequired = Notification.Name("reconnectRequired")
}
```

#### StreamingControlsView 集成

```swift
struct StreamingControlsView: View {
    // ... 现有代码 ...

    var body: some View {
        VStack(spacing: 16) {
            // 现有控件...

            Divider()

            // 快速设置（关联 AC-068）
            QuickSettingsSection()
        }
    }
}
```

### 13.6 目录结构更新

```
Chiaki/Features/
├── HostList/
│   ├── HostListView.swift           # [修改] 集成快速操作栏
│   ├── HostQuickActionBar.swift     # [新增] AC-065
│   └── ...
├── Streaming/
│   ├── StreamingView.swift
│   ├── StreamingControlsView.swift  # [修改] 集成快速设置
│   ├── QuickSettingsSection.swift   # [新增] AC-068
│   ├── VolumeOSD.swift              # [新增] AC-066
│   └── ...
├── Common/
│   └── GamepadNumPad.swift          # [新增] AC-067
└── PSNLogin/
    └── ConsolePinView.swift         # [修改] 集成数字键盘

Chiaki/Core/Controllers/
└── ControllerShortcutDetector.swift # [修改] 音量快捷键
```

### 13.7 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-065: 快速操作栏 | `HostQuickActionBar` + `HostListView` | 替代长按菜单，1 步操作 |
| AC-066: 音量快捷键 | `ControllerShortcutDetector` + `VolumeOSD` | PS+L2/R2 调节音量 |
| AC-067: 数字键盘 | `GamepadNumPad` + `ConsolePinView` | 方向键输入 PIN |
| AC-068: 快速设置 | `QuickSettingsSection` + `StreamingControlsView` | 流媒体中调整设置 |

---

### v1.5.0 (2026-01-30)

**变更来源**: F-022 手柄操控 UI/UX 优化 (INS-028 ~ INS-031)

**新增模块**:
- `HostQuickActionBar` - 主机快速操作栏（关联 AC-065）
- `GamepadNumPad` - 手柄友好数字键盘（关联 AC-067）
- `QuickSettingsSection` - 流媒体快速设置面板（关联 AC-068）
- `VolumeOSD` - 音量调节浮层提示（关联 AC-066）

**修改模块**:
- `HostListView` / `TVHostCardView` - 集成快速操作栏（关联 AC-065）
- `ControllerShortcutDetector` - 扩展音量快捷键检测（关联 AC-066）
- `StreamingViewModel` - 添加音量快捷调节逻辑（关联 AC-066）
- `ConsolePinView` - 集成数字键盘组件（关联 AC-067）
- `StreamingControlsView` - 添加快速设置 Section（关联 AC-068）

**破坏性变更**: 无

**迁移说明**: 无需迁移，纯增量功能

---

## 14. F-023 iPad 触摸操作友好化

> **变更来源**: F-023 iPad 触摸操作友好化 (INS-032 ~ INS-039)
> **变更日期**: 2026-02-02
> **关联需求**: US-017, AC-069 ~ AC-075

### 14.1 变更概述

本次变更针对 iPad 触摸操作体验进行全面优化，确保所有可交互控件符合 Apple Human Interface Guidelines (HIG) 的触摸目标标准，并增强无障碍支持。

**核心目标**：
1. 所有触摸目标 ≥ 44×44pt（Apple HIG 最小标准）
2. 相邻控件间距 ≥ 16pt（防止误触）
3. 统一触觉反馈体验
4. 完善 VoiceOver 支持
5. 扩展手势交互能力

### 14.2 影响分析

#### 14.2.1 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `VirtualButtonView` | 修改 | 尺寸标准化、无障碍标签、长按手势 |
| `VirtualControllerView` | 修改 | 控件间距优化、布局调整 |
| `VirtualStickView` | 修改 | 触摸区域优化、无障碍标签 |
| `StreamingControlsView` | 修改 | Slider 交互区域、控件间距 |
| `StreamingView` | 修改 | 边缘滑动手势 |
| `ChiakiTheme` | 修改 | 新增触摸尺寸常量 |
| `Localization` | 修改 | 新增虚拟控制器无障碍文案 |

#### 14.2.2 兼容性评估

| 变更类型 | 向后兼容 | 处理方式 |
|----------|----------|----------|
| 尺寸常量新增 | ✅ | 现有代码逐步迁移 |
| 接口参数新增（可选） | ✅ | 提供默认值 |
| 手势回调新增 | ✅ | 可选回调，默认 nil |
| 本地化字符串新增 | ✅ | 直接添加 |

**破坏性变更**：无

### 14.3 触摸目标尺寸标准化

#### 14.3.1 新增主题常量

```swift
// ChiakiTheme.swift
enum ChiakiTheme {
    enum Touch {
        /// Apple HIG 最小触摸目标尺寸
        static let minTargetSize: CGFloat = 44

        /// 相邻控件最小间距（防止误触）
        static let minSpacing: CGFloat = 16

        /// Slider 触摸区域高度
        static let sliderHeight: CGFloat = 44

        /// 推荐触摸目标尺寸（舒适操作）
        static let recommendedTargetSize: CGFloat = 48
    }
}
```

#### 14.3.2 VirtualButtonView 尺寸调整

**当前尺寸** → **优化后尺寸**

| 按钮类型 | 当前 | 优化后 | 说明 |
|----------|------|--------|------|
| 肩键 L1/R1/L2/R2 | 50pt | 50pt | ✅ 已符合 |
| 方向键 | 50pt | 50pt | ✅ 已符合 |
| 面板按钮 | 55pt | 55pt | ✅ 已符合 |
| 菜单按钮 (Share/PS/Options) | 40pt | **44pt** | ⚠️ 需调整 |

```swift
// VirtualButtonView.swift - 修改
struct VirtualButtonView: View {
    // 菜单按钮尺寸调整
    var size: CGFloat = ChiakiTheme.Touch.minTargetSize  // 40 → 44

    // ...
}
```

### 14.4 控件间距优化

#### 14.4.1 VirtualControllerView 间距调整

**当前间距** → **优化后间距**

| 区域 | 当前 | 优化后 | 说明 |
|------|------|--------|------|
| D-Pad 网格 | 10pt | **16pt** | ⚠️ 需调整 |
| 面板按钮网格 | 15pt | 16pt | 微调 |
| 中心菜单按钮 | 30pt | 30pt | ✅ 已符合 |
| 肩键间距 | 20pt | 20pt | ✅ 已符合 |

```swift
// VirtualControllerView.swift - 修改
private var dpadView: some View {
    Grid(horizontalSpacing: ChiakiTheme.Touch.minSpacing,  // 10 → 16
         verticalSpacing: ChiakiTheme.Touch.minSpacing) {  // 10 → 16
        // ...
    }
}

private var faceButtonsView: some View {
    Grid(horizontalSpacing: ChiakiTheme.Touch.minSpacing,  // 15 → 16
         verticalSpacing: ChiakiTheme.Touch.minSpacing) {  // 15 → 16
        // ...
    }
}
```

### 14.5 Slider 交互区域优化

#### 14.5.1 TouchableSlider 组件

创建自定义 Slider 包装器，扩大可触摸区域：

```swift
// TouchableSlider.swift - 新增
/// 触摸友好的 Slider 组件，扩大交互区域到 44pt
/// @requirement F-023 - iPad 触摸操作友好化
/// @satisfies AC-071 - Slider 交互区域
struct TouchableSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var tint: Color = .accentColor
    var onEditingChanged: ((Bool) -> Void)?

    var body: some View {
        Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            .tint(tint)
            .frame(height: ChiakiTheme.Touch.sliderHeight)
            .contentShape(Rectangle())  // 扩大触摸区域
    }
}
```

#### 14.5.2 StreamingControlsView 集成

```swift
// StreamingControlsView.swift - 修改
HStack(spacing: 12) {
    Image(systemName: "speaker.fill")

    // 替换为 TouchableSlider
    TouchableSlider(value: $volume, range: 0...1, tint: .chiakiPurple)
        .focused(focusedControl, equals: .volumeSlider)

    Image(systemName: "speaker.wave.3.fill")
    // ...
}
```

### 14.6 触觉反馈统一

#### 14.6.1 设计原则

所有可交互控件应通过 `HapticsManager` 提供统一的触觉反馈：

| 交互类型 | 反馈方法 | 说明 |
|----------|----------|------|
| 按钮点击 | `playSelection()` | 轻量选择反馈 |
| 按钮长按 | `playImpact(.medium)` | 中等冲击反馈 |
| Slider 调节 | `playSelection()` | 值变化反馈 |
| 手势完成 | `playSuccess()` | 成功反馈 |
| 操作失败 | `playError()` | 错误反馈 |

#### 14.6.2 VirtualButtonView 触觉集成

```swift
// VirtualButtonView.swift - 修改
struct VirtualButtonView: View {
    // 使用 HapticsManager 替代 UIImpactFeedbackGenerator
    private func triggerHaptic() {
        HapticsManager.shared.playSelection()
    }

    private func triggerLongPressHaptic() {
        HapticsManager.shared.playImpact(.medium)
    }
}
```

### 14.7 虚拟控制器无障碍支持

#### 14.7.1 无障碍标签定义

```swift
// Localization.swift - 新增
enum L10n {
    enum Accessibility {
        // 虚拟控制器按钮
        static let buttonCross = String(localized: "accessibility.button.cross")
        static let buttonCircle = String(localized: "accessibility.button.circle")
        static let buttonTriangle = String(localized: "accessibility.button.triangle")
        static let buttonSquare = String(localized: "accessibility.button.square")
        static let buttonL1 = String(localized: "accessibility.button.l1")
        static let buttonL2 = String(localized: "accessibility.button.l2")
        static let buttonR1 = String(localized: "accessibility.button.r1")
        static let buttonR2 = String(localized: "accessibility.button.r2")
        static let buttonDpadUp = String(localized: "accessibility.button.dpad.up")
        static let buttonDpadDown = String(localized: "accessibility.button.dpad.down")
        static let buttonDpadLeft = String(localized: "accessibility.button.dpad.left")
        static let buttonDpadRight = String(localized: "accessibility.button.dpad.right")
        static let buttonShare = String(localized: "accessibility.button.share")
        static let buttonOptions = String(localized: "accessibility.button.options")
        static let buttonPS = String(localized: "accessibility.button.ps")
        static let stickLeft = String(localized: "accessibility.stick.left")
        static let stickRight = String(localized: "accessibility.stick.right")

        // 状态
        static func buttonPressed(_ name: String) -> String {
            String(localized: "accessibility.button.pressed \(name)")
        }
        static func buttonReleased(_ name: String) -> String {
            String(localized: "accessibility.button.released \(name)")
        }
    }
}
```

#### 14.7.2 本地化字符串

```json
// Localizable.xcstrings - 新增
{
  "accessibility.button.cross": {
    "en": "Cross button",
    "zh-Hans": "叉号按钮"
  },
  "accessibility.button.circle": {
    "en": "Circle button",
    "zh-Hans": "圆圈按钮"
  },
  "accessibility.button.triangle": {
    "en": "Triangle button",
    "zh-Hans": "三角按钮"
  },
  "accessibility.button.square": {
    "en": "Square button",
    "zh-Hans": "方块按钮"
  },
  "accessibility.button.l1": {
    "en": "L1 button",
    "zh-Hans": "L1 按钮"
  },
  "accessibility.button.l2": {
    "en": "L2 trigger",
    "zh-Hans": "L2 扳机"
  },
  "accessibility.button.r1": {
    "en": "R1 button",
    "zh-Hans": "R1 按钮"
  },
  "accessibility.button.r2": {
    "en": "R2 trigger",
    "zh-Hans": "R2 扳机"
  },
  "accessibility.button.dpad.up": {
    "en": "D-pad up",
    "zh-Hans": "方向键上"
  },
  "accessibility.button.dpad.down": {
    "en": "D-pad down",
    "zh-Hans": "方向键下"
  },
  "accessibility.button.dpad.left": {
    "en": "D-pad left",
    "zh-Hans": "方向键左"
  },
  "accessibility.button.dpad.right": {
    "en": "D-pad right",
    "zh-Hans": "方向键右"
  },
  "accessibility.button.share": {
    "en": "Share button",
    "zh-Hans": "分享按钮"
  },
  "accessibility.button.options": {
    "en": "Options button",
    "zh-Hans": "选项按钮"
  },
  "accessibility.button.ps": {
    "en": "PlayStation button",
    "zh-Hans": "PlayStation 按钮"
  },
  "accessibility.stick.left": {
    "en": "Left analog stick",
    "zh-Hans": "左摇杆"
  },
  "accessibility.stick.right": {
    "en": "Right analog stick",
    "zh-Hans": "右摇杆"
  },
  "accessibility.button.pressed": {
    "en": "%@ pressed",
    "zh-Hans": "%@ 已按下"
  },
  "accessibility.button.released": {
    "en": "%@ released",
    "zh-Hans": "%@ 已松开"
  }
}
```

#### 14.7.3 VirtualButtonView 无障碍集成

```swift
// VirtualButtonView.swift - 修改
struct VirtualButtonView: View {
    let button: VirtualControllerButton
    var accessibilityLabel: String?

    var body: some View {
        // ...existing view code...
            .accessibilityLabel(accessibilityLabel ?? defaultAccessibilityLabel)
            .accessibilityValue(isPressed ? L10n.Accessibility.buttonPressed(buttonName) : "")
            .accessibilityAddTraits(.isButton)
    }

    private var defaultAccessibilityLabel: String {
        switch button {
        case .cross: return L10n.Accessibility.buttonCross
        case .circle: return L10n.Accessibility.buttonCircle
        case .triangle: return L10n.Accessibility.buttonTriangle
        case .square: return L10n.Accessibility.buttonSquare
        case .l1: return L10n.Accessibility.buttonL1
        case .l2: return L10n.Accessibility.buttonL2
        case .r1: return L10n.Accessibility.buttonR1
        case .r2: return L10n.Accessibility.buttonR2
        case .up: return L10n.Accessibility.buttonDpadUp
        case .down: return L10n.Accessibility.buttonDpadDown
        case .left: return L10n.Accessibility.buttonDpadLeft
        case .right: return L10n.Accessibility.buttonDpadRight
        case .share: return L10n.Accessibility.buttonShare
        case .options: return L10n.Accessibility.buttonOptions
        case .ps: return L10n.Accessibility.buttonPS
        }
    }
}
```

### 14.8 长按手势支持

#### 14.8.1 VirtualButtonView 长按扩展

```swift
// VirtualButtonView.swift - 修改
struct VirtualButtonView: View {
    var onStateChanged: (Bool) -> Void
    var onLongPress: (() -> Void)?  // 新增：长按回调

    @State private var isLongPressing = false

    var body: some View {
        Circle()
            // ...existing styling...
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        guard let handler = onLongPress else { return }
                        isLongPressing = true
                        HapticsManager.shared.playImpact(.medium)
                        handler()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed && !isLongPressing {
                            isPressed = true
                            onStateChanged(true)
                            HapticsManager.shared.playSelection()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        isLongPressing = false
                        onStateChanged(false)
                    }
            )
    }
}
```

#### 14.8.2 长按功能映射

| 按钮 | 长按功能 | 说明 |
|------|----------|------|
| PS 按钮 | 打开控制菜单 | 替代双击 |
| Options | 截图/录屏 | 快捷操作 |
| Share | 广播模式切换 | 快捷操作 |

### 14.9 滑动快捷调节

#### 14.9.1 EdgeSwipeGesture 组件

```swift
// EdgeSwipeGesture.swift - 新增
/// 边缘滑动手势识别器
/// @requirement F-023 - iPad 触摸操作友好化
/// @satisfies AC-075 - 滑动快捷调节
struct EdgeSwipeGesture: ViewModifier {
    enum Edge { case left, right }

    let edge: Edge
    let threshold: CGFloat = 20  // 边缘触发区域宽度
    var onSwipe: (CGFloat) -> Void  // 滑动增量回调

    @State private var isDragging = false
    @State private var startY: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // 检测是否从边缘开始
                        let screenWidth = UIScreen.main.bounds.width
                        let isInEdgeZone = edge == .left
                            ? value.startLocation.x < threshold
                            : value.startLocation.x > screenWidth - threshold

                        guard isInEdgeZone else { return }

                        if !isDragging {
                            isDragging = true
                            startY = value.startLocation.y
                            HapticsManager.shared.playSelection()
                        }

                        let delta = (startY - value.location.y) / 200  // 归一化
                        onSwipe(delta)
                    }
                    .onEnded { _ in
                        isDragging = false
                        HapticsManager.shared.playImpact(.light)
                    }
            )
    }
}

extension View {
    func edgeSwipe(edge: EdgeSwipeGesture.Edge, onSwipe: @escaping (CGFloat) -> Void) -> some View {
        modifier(EdgeSwipeGesture(edge: edge, onSwipe: onSwipe))
    }
}
```

#### 14.9.2 StreamingView 集成

```swift
// StreamingView.swift - 修改
var body: some View {
    ZStack {
        // ...existing content...
    }
    #if os(iOS)
    .edgeSwipe(edge: .right) { delta in
        // 右边缘滑动调节音量
        let newVolume = viewModel.volume + Double(delta)
        viewModel.setVolume(max(0, min(1, newVolume)))
    }
    .edgeSwipe(edge: .left) { delta in
        // 左边缘滑动调节亮度（可选）
        let newBrightness = UIScreen.main.brightness + CGFloat(delta)
        UIScreen.main.brightness = max(0, min(1, newBrightness))
    }
    #endif
}
```

### 14.10 核心接口设计

#### 14.10.1 VirtualButtonView（修改）

| 属性/方法 | 类型 | 关联 | 说明 |
|-----------|------|------|------|
| `size` | `CGFloat` | AC-069 | 默认值调整为 44pt |
| `accessibilityLabel` | `String?` | AC-073 | 可选无障碍标签 |
| `onLongPress` | `(() -> Void)?` | AC-074 | 可选长按回调 |

#### 14.10.2 TouchableSlider（新增）

| 属性/方法 | 类型 | 关联 | 说明 |
|-----------|------|------|------|
| `value` | `Binding<Double>` | AC-071 | 绑定值 |
| `range` | `ClosedRange<Double>` | AC-071 | 值范围 |
| `tint` | `Color` | - | 滑块颜色 |
| `onEditingChanged` | `((Bool) -> Void)?` | AC-072 | 编辑状态变化回调 |

#### 14.10.3 EdgeSwipeGesture（新增）

| 属性/方法 | 类型 | 关联 | 说明 |
|-----------|------|------|------|
| `edge` | `Edge` | AC-075 | 触发边缘（左/右） |
| `threshold` | `CGFloat` | AC-075 | 边缘区域宽度 |
| `onSwipe` | `(CGFloat) -> Void` | AC-075 | 滑动增量回调 |

### 14.11 目录结构更新

```
Chiaki/Features/Streaming/
├── VirtualController/
│   ├── VirtualButtonView.swift      # [修改] AC-069, AC-073, AC-074
│   ├── VirtualControllerView.swift  # [修改] AC-070
│   └── VirtualStickView.swift       # [修改] AC-073
├── StreamingView.swift              # [修改] AC-075
├── StreamingControlsView.swift      # [修改] AC-070, AC-071
└── ...

Chiaki/Shared/
├── Components/
│   └── TouchableSlider.swift        # [新增] AC-071
├── Gestures/
│   └── EdgeSwipeGesture.swift       # [新增] AC-075
└── ...

Chiaki/Utilities/
├── ChiakiTheme.swift                # [修改] AC-069, AC-070
└── Localization.swift               # [修改] AC-073
```

### 14.12 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-069: 触摸目标尺寸 | `ChiakiTheme.Touch` + `VirtualButtonView` | 标准化 ≥44pt |
| AC-070: 控件间距 | `VirtualControllerView` + `StreamingControlsView` | 标准化 ≥16pt |
| AC-071: Slider 区域 | `TouchableSlider` | 可触摸高度 44pt |
| AC-072: 触觉反馈 | `HapticsManager` 集成 | 统一反馈调用 |
| AC-073: 虚拟控制器无障碍 | `VirtualButtonView` + `Localization` | VoiceOver 支持 |
| AC-074: 长按手势 | `VirtualButtonView.onLongPress` | LongPressGesture |
| AC-075: 滑动调节 | `EdgeSwipeGesture` + `StreamingView` | 边缘滑动音量 |

---

### v1.6.0 (2026-02-02)

**变更来源**: F-023 iPad 触摸操作友好化 (INS-032 ~ INS-039)

**新增模块**:
- `TouchableSlider` - 触摸友好滑块组件（关联 AC-071）
- `EdgeSwipeGesture` - 边缘滑动手势修饰器（关联 AC-075）
- `ChiakiTheme.Touch` - 触摸目标尺寸常量（关联 AC-069, AC-070）

**修改模块**:
- `VirtualButtonView` - 尺寸标准化、无障碍标签、长按手势（关联 AC-069, AC-073, AC-074）
- `VirtualControllerView` - 控件间距优化（关联 AC-070）
- `VirtualStickView` - 无障碍标签（关联 AC-073）
- `StreamingControlsView` - Slider 替换、间距优化（关联 AC-070, AC-071）
- `StreamingView` - 边缘滑动手势集成（关联 AC-075）
- `Localization` - 虚拟控制器无障碍文案（关联 AC-073）

**破坏性变更**: 无

**迁移说明**: 无需迁移，纯增量功能。所有变更向后兼容，现有代码可逐步迁移至新的尺寸常量。

---

## 15. HDR 渲染管线优化 (F-025)

> **变更来源**: F-025 HDR 渲染管线优化
> **关联洞察**: INS-034 ~ INS-038 (GPT/Gemini 方案对比分析)

### 15.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `MetalVideoRenderer` | 修改 | 新增色域映射、EDR Headroom 支持 |
| `VideoShaders.metal` | 修改 | 新增 Rec.2020→P3 矩阵、Tone Mapping |
| `VideoStreamView` | 修改 | EDR Headroom 监听与传递 |
| `StreamStatsManager` | 修改 | 新增渲染性能指标 |
| `HDRConfiguration` | 新增 | 统一 HDR 配置结构 |

#### 受影响的接口

| 接口 | 变更类型 | 向后兼容 | 说明 |
|------|----------|----------|------|
| `MetalVideoRenderer.edrHeadroom` | 新增 | ✅ | 动态 EDR 缩放因子 |
| `MetalVideoRenderer.tonemapMode` | 新增 | ✅ | Tone Mapping 模式 |
| `VideoUniforms` (Shader) | 修改 | ✅ | 新增 edrHeadroom、tonemapMode 字段 |

### 15.2 色域映射设计 (AC-080)

#### 15.2.1 Rec.2020 → Display P3 转换矩阵

```metal
// VideoShaders.metal - 新增色域映射常量

// Rec.2020 → Display P3 色域映射矩阵
// 用于将 HDR 内容从 Rec.2020 色彩空间转换到 Apple Display P3
constant float3x3 kRec2020_to_P3_Matrix = float3x3(
    float3( 1.2249,  -0.2247,  -0.0002),
    float3(-0.0420,   1.0419,   0.0001),
    float3(-0.0197,  -0.0786,   1.0983)
);

// 应用色域映射（在 PQ EOTF 后、EDR 缩放前调用）
float3 applyGamutMapping(float3 linearRGB) {
    // 软裁剪：超出色域的颜色平滑压缩而非硬裁剪
    float3 mapped = kRec2020_to_P3_Matrix * linearRGB;
    // 负值软裁剪（保留色调）
    return max(mapped, 0.0);
}
```

#### 15.2.2 Shader 集成位置

```metal
// videoBiplanarFragmentShader 修改

// 在 pqEOTF 后添加色域映射
if (uniforms.colorSpace == 2u) {  // BT.2020 HDR
    rgb = clamp(rgb, 0.0, 1.0);
    rgb = pqEOTF(rgb);

    // [新增] Rec.2020 → P3 色域映射
    rgb = applyGamutMapping(rgb);

    // EDR 缩放（使用动态 Headroom）
    rgb = rgb * uniforms.edrHeadroom;
    // ...
}
```

### 15.3 动态 EDR Headroom 设计 (AC-081, AC-082)

#### 15.3.1 EDR Headroom 监听

```swift
// EDRHeadroomMonitor.swift (新增)
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// EDR Headroom 监听器
/// 关联: AC-081
@Observable
final class EDRHeadroomMonitor {
    /// 当前 EDR Headroom 值 (1.0 = SDR, >1.0 = HDR capable)
    private(set) var currentHeadroom: Float = 1.0

    /// 最大可用 Headroom
    private(set) var maxHeadroom: Float = 1.0

    private var displayLink: CADisplayLink?
    private var observation: NSKeyValueObservation?

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        #if os(macOS)
        // macOS: 监听 NSScreen.maximumExtendedDynamicRangeColorComponentValue
        observation = NSScreen.main?.observe(\.maximumExtendedDynamicRangeColorComponentValue) { [weak self] screen, _ in
            self?.updateHeadroom(Float(screen.maximumExtendedDynamicRangeColorComponentValue))
        }
        if let screen = NSScreen.main {
            updateHeadroom(Float(screen.maximumExtendedDynamicRangeColorComponentValue))
        }
        #else
        // iOS 16+: 使用 UIScreen.currentEDRHeadroom
        if #available(iOS 16.0, tvOS 16.0, *) {
            // 使用 DisplayLink 定期更新（Headroom 会随亮度变化）
            displayLink = CADisplayLink(target: self, selector: #selector(updateFromDisplayLink))
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 10, preferred: 5)
            displayLink?.add(to: .main, forMode: .common)
        }
        #endif
    }

    @objc private func updateFromDisplayLink() {
        #if os(iOS) || os(tvOS)
        if #available(iOS 16.0, tvOS 16.0, *) {
            updateHeadroom(Float(UIScreen.main.currentEDRHeadroom))
        }
        #endif
    }

    private func updateHeadroom(_ value: Float) {
        // 平滑过渡，避免突变
        let smoothed = currentHeadroom * 0.9 + value * 0.1
        currentHeadroom = smoothed
        maxHeadroom = max(maxHeadroom, value)
    }

    deinit {
        displayLink?.invalidate()
        observation?.invalidate()
    }
}
```

#### 15.3.2 Headroom 传递到 Shader

```swift
// MetalVideoRenderer.swift - 修改

/// 更新 Shader Uniforms
private func updateUniforms(edrHeadroom: Float) {
    var uniforms = VideoUniforms()
    uniforms.transform = transformMatrix
    uniforms.brightness = brightness
    uniforms.contrast = contrast
    uniforms.saturation = saturation
    uniforms.colorSpace = colorSpace.rawValue
    uniforms.colorRange = colorRange.rawValue

    // [新增] 动态 EDR Headroom
    // 关联: AC-082
    uniforms.edrHeadroom = edrHeadroom * edrIntensity  // edrIntensity 来自用户设置
    uniforms.tonemapMode = tonemapMode.rawValue

    uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<VideoUniforms>.size)
}
```

#### 15.3.3 Shader Uniform 扩展

```metal
// VideoShaders.metal - VideoUniforms 修改

struct VideoUniforms {
    float4x4 transform;
    float2 textureSizeY;
    float2 textureSizeUV;
    float brightness;
    float contrast;
    float saturation;
    uint colorSpace;
    uint colorRange;

    // [新增] HDR 相关
    float edrHeadroom;   // AC-081: 动态 EDR Headroom (含用户调整因子)
    uint tonemapMode;    // AC-084: 0 = passthrough, 1 = ACES
};
```

### 15.4 HDR 元数据抖动抑制 (AC-083)

```swift
// HDRMetadataCache.swift (新增)

/// HDR 元数据缓存，抑制频繁切换
/// 关联: AC-083
final class HDRMetadataCache {
    /// 当前确认的 HDR 状态
    private(set) var confirmedHDR: Bool = false

    /// HDR 检测计数器（需要连续 N 帧确认）
    private var hdrDetectionCount: Int = 0
    private var sdrDetectionCount: Int = 0

    /// 确认阈值（连续帧数）
    private let confirmationThreshold = 5

    /// 更新检测状态
    func update(isHDRFrame: Bool) -> Bool {
        if isHDRFrame {
            hdrDetectionCount += 1
            sdrDetectionCount = 0
            if hdrDetectionCount >= confirmationThreshold {
                confirmedHDR = true
            }
        } else {
            sdrDetectionCount += 1
            hdrDetectionCount = 0
            if sdrDetectionCount >= confirmationThreshold {
                confirmedHDR = false
            }
        }
        return confirmedHDR
    }

    /// 重置缓存
    func reset() {
        confirmedHDR = false
        hdrDetectionCount = 0
        sdrDetectionCount = 0
    }
}
```

### 15.5 Tone Mapping 降级路径 (AC-084)

```metal
// VideoShaders.metal - ACES Tone Mapping 实现

// ACES Filmic Tone Mapping
// 用于 HDR→SDR 降级（不支持 EDR 的设备）
float3 acesTonemap(float3 x) {
    // ACES 拟合参数
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// 在 Fragment Shader 中使用
if (uniforms.colorSpace == 2u) {  // BT.2020 HDR
    rgb = pqEOTF(rgb);
    rgb = applyGamutMapping(rgb);

    if (uniforms.tonemapMode == 1u) {
        // ACES Tone Mapping（SDR 输出）
        rgb = acesTonemap(rgb);
    } else {
        // EDR Passthrough
        rgb = rgb * uniforms.edrHeadroom;
    }
}
```

### 15.6 渲染性能指标扩展 (AC-085)

```swift
// StreamStatsManager.swift - 扩展

extension StreamStatsManager {
    // [新增] 渲染性能指标
    // 关联: AC-085

    /// 解码耗时 (ms)
    @Published private(set) var decodeTimeMs: Double = 0

    /// 渲染耗时 (ms)
    @Published private(set) var renderTimeMs: Double = 0

    /// P95 帧延迟 (ms)
    @Published private(set) var p95LatencyMs: Double = 0

    /// P99 帧延迟 (ms)
    @Published private(set) var p99LatencyMs: Double = 0

    // 延迟采样窗口
    private var latencySamples: [Double] = []
    private let sampleWindowSize = 100

    /// 记录解码耗时
    func recordDecodeTime(_ timeMs: Double) {
        decodeTimeMs = timeMs
    }

    /// 记录渲染耗时
    func recordRenderTime(_ timeMs: Double) {
        renderTimeMs = timeMs

        // 计算总帧延迟
        let totalLatency = decodeTimeMs + renderTimeMs
        latencySamples.append(totalLatency)

        // 保持窗口大小
        if latencySamples.count > sampleWindowSize {
            latencySamples.removeFirst()
        }

        // 计算百分位
        updatePercentiles()
    }

    private func updatePercentiles() {
        guard latencySamples.count >= 10 else { return }

        let sorted = latencySamples.sorted()
        let p95Index = Int(Double(sorted.count) * 0.95)
        let p99Index = Int(Double(sorted.count) * 0.99)

        p95LatencyMs = sorted[min(p95Index, sorted.count - 1)]
        p99LatencyMs = sorted[min(p99Index, sorted.count - 1)]
    }
}
```

### 15.7 核心接口汇总

| 接口/类 | 方法/属性 | 关联 | 说明 |
|---------|-----------|------|------|
| `EDRHeadroomMonitor` | `currentHeadroom: Float` | AC-081 | 当前 EDR Headroom |
| `EDRHeadroomMonitor` | `maxHeadroom: Float` | AC-081 | 最大可用 Headroom |
| `MetalVideoRenderer` | `edrHeadroom: Float` | AC-082 | 设置 EDR 缩放因子 |
| `MetalVideoRenderer` | `tonemapMode: TonemapMode` | AC-084 | Tone Mapping 模式 |
| `HDRMetadataCache` | `update(isHDRFrame:) -> Bool` | AC-083 | 抖动抑制 |
| `StreamStatsManager` | `decodeTimeMs`, `renderTimeMs` | AC-085 | 性能指标 |
| `StreamStatsManager` | `p95LatencyMs`, `p99LatencyMs` | AC-085 | 延迟百分位 |

### 15.8 目录结构更新

```
Chiaki/Core/Video/
├── MetalVideoRenderer.swift   # [修改] AC-080, AC-082, AC-084
├── VideoShaders.metal         # [修改] AC-080, AC-084 (已重命名为 .txt 仅文档用)
├── VideoStreamView.swift      # [修改] AC-081 - EDR 监听集成
├── EDRHeadroomMonitor.swift   # [新增] AC-081
├── HDRMetadataCache.swift     # [新增] AC-083
└── HDRConfiguration.swift     # [新增] 统一配置结构

Chiaki/Features/Streaming/
├── StreamStatsManager.swift   # [修改] AC-085
└── StreamingOverlay.swift     # [修改] 显示新增指标
```

---

## 16. 渲染模块解耦重构 (F-026)

> **变更来源**: F-026 渲染模块解耦重构
> **关联洞察**: INS-039 ~ INS-041 (架构审查)

### 16.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `MetalVideoRenderer` | 重构 | 移除 MTKViewDelegate，实现 VideoRenderer 协议 |
| `VideoStreamView` | 重构 | Coordinator 实现 MTKViewDelegate |
| `VideoRenderer` 协议 | 新增 | 渲染器抽象接口 |
| `HDRConfiguration` | 新增 | 统一 HDR 配置结构 |

#### 受影响的接口

| 接口 | 变更类型 | 向后兼容 | 说明 |
|------|----------|----------|------|
| `MetalVideoRenderer: MTKViewDelegate` | 移除 | ⚠️ 内部重构 | Delegate 移至 Coordinator |
| `VideoRenderer` 协议 | 新增 | ✅ | 新抽象层 |
| `HDRConfiguration` | 新增 | ✅ | 配置结构 |

### 16.2 VideoRenderer 协议设计 (AC-086)

```swift
// VideoRenderer.swift (新增)

import CoreVideo
import Metal

/// 视频显示模式
enum VideoDisplayMode: Int, Sendable {
    case fit = 0        // 适应窗口，保持比例
    case fill = 1       // 填充窗口，可能裁剪
    case stretch = 2    // 拉伸填充
}

/// Tone Mapping 模式
enum TonemapMode: UInt32, Sendable {
    case passthrough = 0   // EDR 直通
    case aces = 1          // ACES Filmic
}

/// 视频渲染器协议
/// 定义纯渲染接口，与 UI 框架解耦
/// 关联: AC-086
protocol VideoRenderer: AnyObject, Sendable {
    // MARK: - 帧提交

    /// 提交视频帧用于渲染
    func submitFrame(_ pixelBuffer: CVPixelBuffer)

    /// 渲染到指定 drawable
    func render(to drawable: CAMetalDrawable, descriptor: MTLRenderPassDescriptor)

    // MARK: - 显示控制

    /// 显示模式
    var displayMode: VideoDisplayMode { get set }

    /// 缩放因子 (1.0 = 无缩放)
    var zoomFactor: Float { get set }

    // MARK: - HDR 配置

    /// HDR 配置
    var hdrConfiguration: HDRConfiguration { get set }

    /// 动态 EDR Headroom (来自系统)
    var edrHeadroom: Float { get set }

    // MARK: - 色彩调整

    /// 亮度 (0.0 - 2.0, 默认 1.0)
    func setBrightness(_ value: Float)

    /// 对比度 (0.0 - 2.0, 默认 1.0)
    func setContrast(_ value: Float)

    /// 饱和度 (0.0 - 2.0, 默认 1.0)
    func setSaturation(_ value: Float)

    // MARK: - 状态查询

    /// 当前帧尺寸
    var frameSize: CGSize { get }

    /// 是否有待渲染帧
    var hasFrame: Bool { get }
}
```

### 16.3 HDRConfiguration 统一结构 (AC-088)

```swift
// HDRConfiguration.swift (新增)

/// 色彩空间
enum VideoColorSpace: UInt32, Sendable, Codable {
    case bt709 = 0     // HD (SDR 默认)
    case bt601 = 1     // SD
    case bt2020 = 2    // HDR / Wide Color Gamut
}

/// 色彩范围
enum VideoColorRange: UInt32, Sendable, Codable {
    case limited = 0   // 16-235 (Video Range)
    case full = 1      // 0-255 (Full Range)
}

/// HDR 配置结构
/// 统一管理 HDR 相关设置
/// 关联: AC-088
struct HDRConfiguration: Sendable, Codable, Equatable {
    /// HDR 是否启用
    var enabled: Bool = false

    /// 用户 EDR 强度调整 (0.5 - 2.0, 默认 1.0)
    var edrIntensity: Float = 1.0

    /// 色彩空间
    var colorSpace: VideoColorSpace = .bt709

    /// 色彩范围
    var colorRange: VideoColorRange = .limited

    /// Tone Mapping 模式
    var tonemapMode: TonemapMode = .passthrough

    /// 是否启用色域映射 (Rec.2020 → P3)
    var gamutMappingEnabled: Bool = true

    // MARK: - 便捷属性

    /// 是否为 HDR 模式 (BT.2020)
    var isHDR: Bool {
        enabled && colorSpace == .bt2020
    }

    /// 创建 SDR 默认配置
    static var sdr: HDRConfiguration {
        HDRConfiguration(enabled: false, colorSpace: .bt709)
    }

    /// 创建 HDR 默认配置
    static var hdr: HDRConfiguration {
        HDRConfiguration(enabled: true, colorSpace: .bt2020, tonemapMode: .passthrough)
    }
}
```

### 16.4 MTKViewDelegate 分离到 Coordinator (AC-087)

```swift
// VideoStreamView.swift - 重构

import SwiftUI
import MetalKit

/// 视频流 SwiftUI 视图
/// 关联: AC-087 - MTKViewDelegate 分离到 Coordinator
struct VideoStreamView: NSViewRepresentable {  // macOS
    let renderer: VideoRenderer
    let edrMonitor: EDRHeadroomMonitor

    @Binding var hdrConfiguration: HDRConfiguration

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60

        // HDR 配置
        if hdrConfiguration.isHDR {
            mtkView.colorPixelFormat = .rgba16Float
            mtkView.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        } else {
            mtkView.colorPixelFormat = .bgra8Unorm
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // 更新 HDR 配置
        renderer.hdrConfiguration = hdrConfiguration
        renderer.edrHeadroom = edrMonitor.currentHeadroom * hdrConfiguration.edrIntensity

        // 动态切换像素格式
        if hdrConfiguration.isHDR && nsView.colorPixelFormat != .rgba16Float {
            nsView.colorPixelFormat = .rgba16Float
            nsView.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        } else if !hdrConfiguration.isHDR && nsView.colorPixelFormat != .bgra8Unorm {
            nsView.colorPixelFormat = .bgra8Unorm
            nsView.colorspace = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }

    // MARK: - Coordinator

    /// MTKViewDelegate 实现
    /// 关联: AC-087
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: VideoRenderer

        init(renderer: VideoRenderer) {
            self.renderer = renderer
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // 尺寸变化处理（如需要）
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else {
                return
            }

            renderer.render(to: drawable, descriptor: descriptor)
        }
    }
}
```

### 16.5 MetalVideoRenderer 重构 (AC-089)

```swift
// MetalVideoRenderer.swift - 重构为实现 VideoRenderer 协议

/// Metal 视频渲染器实现
/// 关联: AC-086 (协议实现), AC-089 (依赖注入)
final class MetalVideoRenderer: VideoRenderer {
    // MARK: - VideoRenderer Protocol

    var displayMode: VideoDisplayMode = .fit
    var zoomFactor: Float = 1.0
    var hdrConfiguration: HDRConfiguration = .sdr
    var edrHeadroom: Float = 1.0

    var frameSize: CGSize {
        guard let buffer = currentPixelBuffer else { return .zero }
        return CGSize(
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer)
        )
    }

    var hasFrame: Bool {
        currentPixelBuffer != nil
    }

    // MARK: - Private Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    private var uniformBuffer: MTLBuffer

    private var currentPixelBuffer: CVPixelBuffer?
    private let lock = NSLock()

    // HDR 元数据缓存
    private let hdrMetadataCache = HDRMetadataCache()

    // MARK: - Initialization

    init(device: MTLDevice? = nil) throws {
        guard let device = device ?? MTLCreateSystemDefaultDevice() else {
            throw VideoRendererError.noMetalDevice
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw VideoRendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        // 创建纹理缓存
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        guard let textureCache = cache else {
            throw VideoRendererError.textureCacheCreationFailed
        }
        self.textureCache = textureCache

        // 创建 Uniform Buffer
        guard let uniformBuffer = device.makeBuffer(
            length: MemoryLayout<VideoUniforms>.size,
            options: .storageModeShared
        ) else {
            throw VideoRendererError.bufferCreationFailed
        }
        self.uniformBuffer = uniformBuffer

        // 创建渲染管线
        self.pipelineState = try Self.createPipelineState(device: device, hdr: false)
    }

    // MARK: - VideoRenderer Implementation

    func submitFrame(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        defer { lock.unlock() }

        currentPixelBuffer = pixelBuffer

        // HDR 元数据抖动抑制 (AC-083)
        let isHDRFrame = detectHDRFrame(pixelBuffer)
        _ = hdrMetadataCache.update(isHDRFrame: isHDRFrame)
    }

    func render(to drawable: CAMetalDrawable, descriptor: MTLRenderPassDescriptor) {
        lock.lock()
        guard let pixelBuffer = currentPixelBuffer else {
            lock.unlock()
            return
        }
        lock.unlock()

        // 更新 Uniforms
        updateUniforms()

        // 创建纹理
        guard let textures = createTextures(from: pixelBuffer) else { return }

        // 渲染
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(textures.y, index: 0)
        encoder.setFragmentTexture(textures.uv, index: 1)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func setBrightness(_ value: Float) {
        // 存储并在 updateUniforms 中应用
    }

    func setContrast(_ value: Float) {
        // 存储并在 updateUniforms 中应用
    }

    func setSaturation(_ value: Float) {
        // 存储并在 updateUniforms 中应用
    }

    // MARK: - Private Methods

    private func updateUniforms() {
        var uniforms = VideoUniforms()
        uniforms.colorSpace = hdrConfiguration.colorSpace.rawValue
        uniforms.colorRange = hdrConfiguration.colorRange.rawValue
        uniforms.edrHeadroom = edrHeadroom
        uniforms.tonemapMode = hdrConfiguration.tonemapMode.rawValue
        // ... 其他 uniforms

        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<VideoUniforms>.size)
    }

    private func detectHDRFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        // 检测 10-bit 或 HDR 格式
        return pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
               pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
    }
}
```

### 16.6 核心接口汇总

| 接口/类 | 方法/属性 | 关联 | 说明 |
|---------|-----------|------|------|
| `VideoRenderer` | `submitFrame(_:)` | AC-086 | 提交视频帧 |
| `VideoRenderer` | `render(to:descriptor:)` | AC-086 | 渲染到 drawable |
| `VideoRenderer` | `hdrConfiguration` | AC-088 | HDR 配置 |
| `VideoRenderer` | `edrHeadroom` | AC-089 | 外部注入 Headroom |
| `VideoStreamView.Coordinator` | `MTKViewDelegate` | AC-087 | Delegate 分离 |
| `HDRConfiguration` | 全部属性 | AC-088 | 统一 HDR 配置 |

### 16.7 目录结构更新

```
Chiaki/Core/Video/
├── VideoRenderer.swift        # [新增] AC-086 - 协议定义
├── MetalVideoRenderer.swift   # [重构] AC-086, AC-089 - 实现协议
├── VideoStreamView.swift      # [重构] AC-087 - Coordinator 模式
├── HDRConfiguration.swift     # [新增] AC-088 - 配置结构
├── EDRHeadroomMonitor.swift   # [新增] AC-081
├── HDRMetadataCache.swift     # [新增] AC-083
└── VideoShaders.metal         # [修改] AC-080, AC-084
```

---

## 17. UI 层 MVVM 合规重构 (F-027)

> **变更来源**: F-027 UI 层 MVVM 合规重构
> **关联洞察**: INS-042 ~ INS-046 (架构审查)

### 17.1 影响分析

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `AccountSettingsView` | 重构 | 移除直接 PSNService 访问 |
| `AccountSettingsViewModel` | 新增 | 封装 PSN 操作 |
| `VideoSettingsViewModel` | 新增 | 封装 HDR Binding 逻辑 |
| `ConsolesSettingsViewModel` | 新增 | 封装主机管理操作 |
| `HostListView` | 重构 | 移除直接 Manager 访问 |
| `StreamingView` | 重构 | 移除直接 ConsolePinManager 访问 |
| `ControllerSettingsView` | 重构 | 移除直接 ControllerManager 访问 |
| `PinManaging` 协议 | 新增 | ConsolePinManager 抽象 |
| `PSNServicing` 协议 | 新增 | PSNService 抽象 |

#### 受影响的接口

| 接口 | 变更类型 | 向后兼容 | 说明 |
|------|----------|----------|------|
| `ConsolePinManager` | 修改 | ✅ | 实现 PinManaging 协议 |
| `PSNService` | 修改 | ✅ | 实现 PSNServicing 协议 |
| `AccountSettingsViewModel` | 新增 | ✅ | 新 ViewModel |
| `VideoSettingsViewModel` | 新增 | ✅ | 新 ViewModel |

### 17.2 协议抽象设计 (AC-095)

#### 17.2.1 PinManaging 协议

```swift
// PinManaging.swift (新增)

/// PIN 管理协议
/// 关联: AC-095
protocol PinManaging: AnyObject, Sendable {
    /// 设置 PIN
    func setPin(_ pin: String, for host: ConsoleHost)

    /// 清除 PIN
    func clearPin(for host: ConsoleHost)

    /// 检查是否有 PIN
    func hasPin(for host: ConsoleHost) -> Bool

    /// 检查是否需要 PIN 输入
    func requiresPinEntry(for host: ConsoleHost) -> Bool

    /// 获取 PIN (如果存在)
    func getPin(for host: ConsoleHost) -> String?
}

// ConsolePinManager 扩展实现协议
extension ConsolePinManager: PinManaging {}
```

#### 17.2.2 PSNServicing 协议

```swift
// PSNServicing.swift (新增)

/// PSN 服务协议
/// 关联: AC-095
protocol PSNServicing: AnyObject {
    /// 当前账户
    var account: PSNAccount? { get }

    /// 是否已登录
    var isSignedIn: Bool { get }

    /// 登录状态
    var authState: PSNAuthState { get }

    /// 登出
    func signOut()

    /// 手动刷新 Token
    func manualRefresh() async throws

    /// 开始 OAuth 登录
    func startOAuthLogin() -> URL
}

// PSNService 扩展实现协议
extension PSNService: PSNServicing {}
```

### 17.3 AccountSettingsViewModel (AC-091)

```swift
// AccountSettingsViewModel.swift (新增)

import Foundation

/// 账户设置 ViewModel
/// 关联: AC-091 - 移除 AccountSettingsView 中的直接 PSNService 访问
@Observable
final class AccountSettingsViewModel {
    // MARK: - Published State

    private(set) var account: PSNAccount?
    private(set) var isSignedIn: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let psnService: PSNServicing

    // MARK: - Initialization

    init(psnService: PSNServicing = PSNService.shared) {
        self.psnService = psnService
        updateState()
    }

    // MARK: - Public Methods

    /// 登出
    func signOut() {
        psnService.signOut()
        updateState()
    }

    /// 刷新 Token
    func refreshToken() async {
        isRefreshing = true
        errorMessage = nil

        do {
            try await psnService.manualRefresh()
            updateState()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    /// 获取登录 URL
    func getLoginURL() -> URL {
        psnService.startOAuthLogin()
    }

    // MARK: - Private Methods

    private func updateState() {
        account = psnService.account
        isSignedIn = psnService.isSignedIn
    }
}
```

### 17.4 VideoSettingsViewModel (AC-093)

```swift
// VideoSettingsViewModel.swift (新增)

import SwiftUI

/// 视频设置 ViewModel
/// 关联: AC-093 - 封装 HDR Binding 转换逻辑
@Observable
final class VideoSettingsViewModel {
    // MARK: - Dependencies

    private let store: SettingsStore

    // MARK: - Initialization

    init(store: SettingsStore) {
        self.store = store
    }

    // MARK: - Stream Settings Proxy

    var streamSettings: StreamSettings {
        get { store.streamSettings }
        set { store.streamSettings = newValue }
    }

    // MARK: - HDR Bindings (简化 View 层逻辑)

    var hdrEnabled: Bool {
        get { streamSettings.hdrEnabled }
        set { streamSettings.hdrEnabled = newValue }
    }

    var hdrPeakNits: Double {
        get { Double(streamSettings.hdrTargetPeakNits) }
        set { streamSettings.hdrTargetPeakNits = Int(newValue) }
    }

    var hdrPeakMode: StreamSettings.HDRPeakMode {
        get { streamSettings.hdrPeakMode }
        set { streamSettings.hdrPeakMode = newValue }
    }

    var edrIntensity: Float {
        get { streamSettings.edrIntensity }
        set { streamSettings.edrIntensity = newValue }
    }

    // MARK: - Computed Properties

    /// HDR 是否可用（设备支持）
    var isHDRAvailable: Bool {
        // 检测设备是否支持 HDR
        #if os(macOS)
        return NSScreen.main?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0 > 1.0
        #else
        if #available(iOS 16.0, tvOS 16.0, *) {
            return UIScreen.main.potentialEDRHeadroom > 1.0
        }
        return false
        #endif
    }

    /// 是否显示 EDR 强度滑块
    var shouldShowEDRIntensity: Bool {
        hdrEnabled && isHDRAvailable
    }

    /// 是否显示色彩空间选项
    var shouldShowColorSpace: Bool {
        !hdrEnabled  // HDR 启用时隐藏（自动使用 BT.2020）
    }

    // MARK: - Validation

    /// 验证并修正设置
    func validateSettings() {
        // 确保 EDR 强度在有效范围内
        if edrIntensity < 0.5 { edrIntensity = 0.5 }
        if edrIntensity > 2.0 { edrIntensity = 2.0 }

        // HDR 启用时强制使用 BT.2020
        if hdrEnabled && streamSettings.colorSpace != .bt2020 {
            streamSettings.colorSpace = .bt2020
        }
    }
}
```

### 17.5 ConsolesSettingsViewModel (AC-094)

```swift
// ConsolesSettingsViewModel.swift (新增)

import Foundation

/// 主机设置 ViewModel
/// 关联: AC-094 - 将 ConsolesSettingsView 中的业务逻辑移至 ViewModel
@Observable
final class ConsolesSettingsViewModel {
    // MARK: - Dependencies

    private let hostStore: HostStore
    private let pinManager: PinManaging

    // MARK: - Initialization

    init(hostStore: HostStore, pinManager: PinManaging = ConsolePinManager.shared) {
        self.hostStore = hostStore
        self.pinManager = pinManager
    }

    // MARK: - Host Management

    var hosts: [ConsoleHost] {
        hostStore.hosts
    }

    /// 删除主机
    func removeHost(_ host: ConsoleHost) {
        hostStore.removeHost(host)
        pinManager.clearPin(for: host)
    }

    /// 更新主机
    func updateHost(_ host: ConsoleHost) {
        hostStore.updateHost(host)
    }

    /// 重命名主机
    func renameHost(_ host: ConsoleHost, to newName: String) {
        var updated = host
        updated.nickname = newName
        hostStore.updateHost(updated)
    }

    // MARK: - PIN Management

    func hasPin(for host: ConsoleHost) -> Bool {
        pinManager.hasPin(for: host)
    }

    func setPin(_ pin: String, for host: ConsoleHost) {
        pinManager.setPin(pin, for: host)
    }

    func clearPin(for host: ConsoleHost) {
        pinManager.clearPin(for: host)
    }
}
```

### 17.6 View 重构示例

#### 17.6.1 AccountSettingsView 重构 (AC-091)

```swift
// AccountSettingsView.swift - 重构后

struct AccountSettingsView: View {
    // ❌ 移除: @State private var psnService = PSNService.shared

    // ✅ 使用 ViewModel
    @State private var viewModel = AccountSettingsViewModel()

    var body: some View {
        Form {
            if viewModel.isSignedIn {
                Section("已登录账户") {
                    if let account = viewModel.account {
                        Text(account.onlineId)
                        Text(account.accountId)
                    }

                    Button("刷新 Token") {
                        Task { await viewModel.refreshToken() }
                    }
                    .disabled(viewModel.isRefreshing)

                    Button("登出", role: .destructive) {
                        viewModel.signOut()
                    }
                }
            } else {
                Section {
                    Link("登录 PSN", destination: viewModel.getLoginURL())
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
```

#### 17.6.2 HostListView 重构 (AC-090)

```swift
// HostListView.swift - 重构关键部分

struct HostListView: View {
    @Environment(HostListViewModel.self) var viewModel

    // ❌ 移除直接 Manager 访问:
    // ConsolePinManager.shared.setPin(pin, for: host)
    // HostManager.shared.wakeUp(host)

    var body: some View {
        // ...
        .sheet(item: $settingPinHost) { host in
            ConsolePinView(host: host) { pin in
                // ✅ 通过 ViewModel
                viewModel.setPin(pin, for: host)
            } onClear: {
                viewModel.clearPin(for: host)
            }
        }
    }
}

// HostListViewModel 扩展
extension HostListViewModel {
    // 关联: AC-090
    private let pinManager: PinManaging = ConsolePinManager.shared

    func setPin(_ pin: String, for host: ConsoleHost) {
        pinManager.setPin(pin, for: host)
    }

    func clearPin(for host: ConsoleHost) {
        pinManager.clearPin(for: host)
    }
}
```

### 17.7 目录结构优化建议 (AC-096)

```
Chiaki/Features/
├── HostList/
│   ├── Views/
│   │   ├── HostListView.swift         # [修改] AC-090
│   │   ├── HostCardView.swift
│   │   └── AddHostView.swift
│   └── ViewModels/
│       ├── HostListViewModel.swift    # [修改] AC-090
│       └── RegistrationViewModel.swift
│
├── Settings/
│   ├── Views/
│   │   ├── SettingsView.swift
│   │   ├── VideoSettingsView.swift    # [修改] AC-093
│   │   ├── AccountSettingsView.swift  # [修改] AC-091
│   │   ├── ConsolesSettingsView.swift # [修改] AC-094
│   │   └── ControllerSettingsView.swift # [修改] AC-092
│   └── ViewModels/
│       ├── VideoSettingsViewModel.swift   # [新增] AC-093
│       ├── AccountSettingsViewModel.swift # [新增] AC-091
│       └── ConsolesSettingsViewModel.swift # [新增] AC-094
│
├── Streaming/
│   ├── Views/
│   │   ├── StreamingView.swift        # [修改] AC-092
│   │   └── StreamingControlsView.swift
│   └── ViewModels/
│       └── StreamingViewModel.swift

Chiaki/Shared/
├── Components/
│   ├── LoadingIndicator.swift
│   └── ErrorView.swift
├── Styles/
│   ├── PrimaryButtonStyle.swift
│   └── FocusableButtonStyle.swift
└── Protocols/
    ├── PinManaging.swift              # [新增] AC-095
    └── PSNServicing.swift             # [新增] AC-095
```

### 17.8 核心接口汇总

| 接口/类 | 方法/属性 | 关联 | 说明 |
|---------|-----------|------|------|
| `PinManaging` | `setPin`, `clearPin`, `hasPin` | AC-095 | PIN 管理抽象 |
| `PSNServicing` | `signOut`, `manualRefresh` | AC-095 | PSN 服务抽象 |
| `AccountSettingsViewModel` | `signOut`, `refreshToken` | AC-091 | 账户操作封装 |
| `VideoSettingsViewModel` | HDR Bindings | AC-093 | HDR 设置封装 |
| `ConsolesSettingsViewModel` | `removeHost`, PIN 操作 | AC-094 | 主机管理封装 |

### 17.9 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-090 | `HostListView` + `HostListViewModel` | Singleton 解耦 |
| AC-091 | `AccountSettingsViewModel` | PSNService 封装 |
| AC-092 | `StreamingView` + `ControllerSettingsView` | Manager 访问移至 ViewModel |
| AC-093 | `VideoSettingsViewModel` | HDR Binding 封装 |
| AC-094 | `ConsolesSettingsViewModel` | 业务逻辑分离 |
| AC-095 | `PinManaging` + `PSNServicing` | 协议抽象 |
| AC-096 | 目录结构 | 可选优化 |

---

### v1.7.0 (2026-02-04)

**变更来源**: F-025 HDR 渲染管线优化 (INS-034 ~ INS-038), F-026 渲染模块解耦重构 (INS-039 ~ INS-041), F-027 UI 层 MVVM 合规重构 (INS-042 ~ INS-046)

**新增模块**:
- `EDRHeadroomMonitor` - 动态 EDR Headroom 监听（关联 AC-081）
- `HDRMetadataCache` - HDR 元数据抖动抑制（关联 AC-083）
- `HDRConfiguration` - 统一 HDR 配置结构（关联 AC-088）
- `VideoRenderer` 协议 - 渲染器抽象接口（关联 AC-086）
- `PinManaging` 协议 - PIN 管理抽象（关联 AC-095）
- `PSNServicing` 协议 - PSN 服务抽象（关联 AC-095）
- `AccountSettingsViewModel` - 账户设置 ViewModel（关联 AC-091）
- `VideoSettingsViewModel` - 视频设置 ViewModel（关联 AC-093）
- `ConsolesSettingsViewModel` - 主机设置 ViewModel（关联 AC-094）

**修改模块**:
- `MetalVideoRenderer` - 实现 VideoRenderer 协议，移除 MTKViewDelegate，新增色域映射、动态 Headroom（关联 AC-080, AC-082, AC-086, AC-089）
- `VideoShaders.metal` - 新增 Rec.2020→P3 矩阵、ACES Tone Mapping（关联 AC-080, AC-084）
- `VideoStreamView` - Coordinator 实现 MTKViewDelegate，集成 EDR 监听（关联 AC-081, AC-087）
- `StreamStatsManager` - 新增渲染性能指标（关联 AC-085）
- `HostListView` - 移除直接 Manager 访问（关联 AC-090）
- `AccountSettingsView` - 使用 ViewModel 替代直接 PSNService 访问（关联 AC-091）
- `StreamingView` - 移除直接 ConsolePinManager 访问（关联 AC-092）
- `ControllerSettingsView` - 移除直接 ControllerManager 访问（关联 AC-092）
- `ConsolesSettingsView` - 使用 ViewModel 封装业务逻辑（关联 AC-094）
- `ConsolePinManager` - 实现 PinManaging 协议（关联 AC-095）
- `PSNService` - 实现 PSNServicing 协议（关联 AC-095）

**破坏性变更**: 无（内部重构，API 兼容）

**迁移说明**:
1. `MetalVideoRenderer` 不再直接实现 `MTKViewDelegate`，使用 `VideoStreamView.Coordinator` 代替
2. 新 ViewModel 采用依赖注入，支持 Mock 测试
3. 协议抽象允许替换具体实现，便于单元测试

---

## 18. HDR 配置完全落地设计 [增量]

> **变更来源**: F-028 HDR 配置完全落地 (INS-048)
> **关联需求**: AC-097 ~ AC-100
> **设计版本**: v1.8.0

### 18.1 影响分析

#### 背景

当前 `HDRConfiguration` 已包含 `edrIntensity`、`gamutMappingEnabled` 等字段，但 Metal Shader 中 HDR 路径基本固定执行，这些配置字段未能真正影响渲染行为。本设计将这些配置字段接入 `VideoUniforms`，并在 Shader 中实现动态分支。

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `VideoUniforms` | 修改 | 新增 `edrIntensity`、`gamutMappingEnabled` 字段 |
| `MetalVideoRenderer` | 修改 | 同步 HDRConfiguration 到 Uniforms |
| `VideoShaders.metal` (运行时源) | 修改 | 根据配置动态执行色域映射和 EDR 强度 |
| `VideoShaderConstants.swift` | 新增 | CPU 端色彩常量验证 |
| `VideoShaderConstantsTests.swift` | 新增 | Shader 常量单元测试 |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| VideoUniforms 扩展 | ✅ 兼容 | 新增字段，现有字段不变 |
| Shader 动态分支 | ✅ 兼容 | 默认行为与当前一致 |
| 新增测试 | ✅ 兼容 | 纯增量 |

### 18.2 VideoUniforms 扩展 (AC-097)

```swift
/// 扩展后的 VideoUniforms
/// @requirement F-028
/// @satisfies AC-097
struct VideoUniforms {
    var transform: simd_float4x4
    var textureSizeY: simd_float2
    var textureSizeUV: simd_float2
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var colorSpace: UInt32   // 0 = BT.709 (HD), 1 = BT.601 (SD), 2 = BT.2020 (HDR)
    var colorRange: UInt32   // 0 = VideoRange(Limited), 1 = FullRange
    var edrHeadroom: Float   // AC-081: EDR Headroom (1.0+)
    var tonemapMode: UInt32  // AC-084: 0 = None (EDR), 1 = ACES Filmic (SDR)

    // 新增字段 (AC-097)
    var edrIntensity: Float      // AC-098: EDR 强度乘数 (0.5 ~ 2.0, 默认 1.0)
    var gamutMappingEnabled: UInt32  // AC-099: 0 = 禁用, 1 = 启用
    var _padding: Float = 0.0    // 保持 16 字节对齐

    static var `default`: VideoUniforms {
        VideoUniforms(
            transform: matrix_identity_float4x4,
            textureSizeY: simd_float2(1920, 1080),
            textureSizeUV: simd_float2(960, 540),
            brightness: 1.0,
            contrast: 1.0,
            saturation: 1.0,
            colorSpace: 0,
            colorRange: 0,
            edrHeadroom: 1.0,
            tonemapMode: 0,
            edrIntensity: 1.0,        // 新增
            gamutMappingEnabled: 1,   // 新增（默认启用）
            _padding: 0.0
        )
    }
}
```

### 18.3 MetalVideoRenderer 配置同步

```swift
/// HDRConfiguration 设置器修改
/// @requirement F-028
/// @satisfies AC-097, AC-098, AC-099
var hdrConfiguration: HDRConfiguration = .sdr {
    didSet {
        uniforms.colorSpace = hdrConfiguration.colorSpace.rawValue
        uniforms.colorRange = hdrConfiguration.colorRange.rawValue
        uniforms.tonemapMode = hdrConfiguration.tonemapMode.rawValue

        // 新增: 同步 edrIntensity 和 gamutMappingEnabled (AC-097)
        uniforms.edrIntensity = hdrConfiguration.edrIntensity
        uniforms.gamutMappingEnabled = hdrConfiguration.gamutMappingEnabled ? 1 : 0

        triggerRedraw()
    }
}

/// 单独设置 EDR 强度（用于实时预览）
/// @satisfies AC-098
func setEDRIntensity(_ intensity: Float) {
    uniforms.edrIntensity = max(0.5, min(2.0, intensity))
    triggerRedraw()
}

/// 单独设置色域映射开关
/// @satisfies AC-099
func setGamutMappingEnabled(_ enabled: Bool) {
    uniforms.gamutMappingEnabled = enabled ? 1 : 0
    triggerRedraw()
}
```

### 18.4 Metal Shader 动态分支

```metal
// VideoShaders.metal (运行时源) - 修改后的 HDR 处理
// @requirement F-028
// @satisfies AC-098, AC-099

fragment float4 videoBiplanarFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> textureY [[texture(0)]],
    texture2d<float> textureUV [[texture(1)]],
    constant VideoUniforms &uniforms [[buffer(1)]]
) {
    // ... YUV 解码部分不变 ...

    // For HDR (BT.2020), apply PQ EOTF to convert to linear light
    if (uniforms.colorSpace == 2u) {
        rgb = clamp(rgb, 0.0, 1.0);
        rgb = pqEOTF(rgb);

        // AC-099: 条件色域映射（根据配置）
        if (uniforms.gamutMappingEnabled == 1u) {
            rgb = applyGamutMapping(rgb);
        }

        if (uniforms.tonemapMode == 1u) {
            // ACES Tone Mapping (SDR Output)
            rgb = acesTonemap(rgb);
        } else {
            // HDR Output (EDR Scaling)
            rgb = linearToEDR(rgb);
            rgb = rgb * uniforms.edrHeadroom;

            // AC-098: 应用用户 EDR 强度设置
            rgb = rgb * uniforms.edrIntensity;
        }

        // ... 颜色调整部分不变 ...
    }
    // ... SDR 处理不变 ...
}
```

### 18.5 VideoShaderConstants (AC-100)

CPU 端常量定义，用于验证 Shader 行为一致性。

```swift
/// CPU 端 Shader 常量定义
/// @requirement F-028
/// @satisfies AC-100
enum VideoShaderConstants {

    // MARK: - PQ EOTF 常量
    static let pq_m1: Float = 0.1593017578125    // 2610/16384
    static let pq_m2: Float = 78.84375           // 2523/32 * 128
    static let pq_c1: Float = 0.8359375          // 3424/4096
    static let pq_c2: Float = 18.8515625         // 2413/128
    static let pq_c3: Float = 18.6875            // 2392/128

    // MARK: - 色域映射矩阵 (Rec.2020 → P3)
    /// Rec.2020 到 Display P3 转换矩阵 (D65 白点，线性空间)
    /// 列主序，与 Metal shader 一致
    static let rec2020ToP3Matrix: simd_float3x3 = simd_float3x3(
        simd_float3( 1.2249, -0.0420, -0.0197),  // Column 0
        simd_float3(-0.2247,  1.0419, -0.0786),  // Column 1
        simd_float3( 0.0000,  0.0000,  1.0979)   // Column 2
    )

    // MARK: - YUV 转 RGB 矩阵

    /// BT.709 Limited Range
    static let bt709Limited: simd_float3x3 = simd_float3x3(
        simd_float3(1.0,         1.0,         1.0),
        simd_float3(0.0,        -0.21325,     2.11240),
        simd_float3(1.79274,    -0.53291,     0.0)
    )

    /// BT.2020 Limited Range
    static let bt2020Limited: simd_float3x3 = simd_float3x3(
        simd_float3(1.0,         1.0,         1.0),
        simd_float3(0.0,        -0.18740,     2.14290),
        simd_float3(1.67958,    -0.65046,     0.0)
    )

    // MARK: - PQ EOTF (CPU 端验证)

    /// 应用 PQ EOTF 解码
    /// - Parameter pq: PQ 编码值 (0~1)
    /// - Returns: 线性光值 (0~1, 代表 0~10000 nits)
    static func pqEOTF(_ pq: Float) -> Float {
        let p = pow(max(pq, 0), 1.0 / pq_m2)
        let num = max(p - pq_c1, 0)
        let den = pq_c2 - pq_c3 * p
        return pow(num / den, 1.0 / pq_m1)
    }

    /// 应用 PQ EOTF 到 RGB 向量
    static func pqEOTF(_ rgb: simd_float3) -> simd_float3 {
        simd_float3(pqEOTF(rgb.x), pqEOTF(rgb.y), pqEOTF(rgb.z))
    }

    // MARK: - ACES Tone Mapping (CPU 端验证)

    /// ACES Filmic Tone Mapping
    /// 基于 Narkowicz 2015
    static func acesTonemap(_ x: simd_float3) -> simd_float3 {
        let a: Float = 2.51
        let b: Float = 0.03
        let c: Float = 2.43
        let d: Float = 0.59
        let e: Float = 0.14

        let result = (x * (a * x + b)) / (x * (c * x + d) + e)
        return simd_clamp(result, simd_float3(0, 0, 0), simd_float3(1, 1, 1))
    }

    // MARK: - Gamut Mapping

    /// 应用 Rec.2020 → P3 色域映射
    static func applyGamutMapping(_ color: simd_float3) -> simd_float3 {
        let p3 = rec2020ToP3Matrix * color
        return simd_max(p3, simd_float3(0, 0, 0))
    }
}
```

### 18.6 单元测试 (AC-100)

```swift
/// VideoShaderConstants 单元测试
/// @requirement F-028
/// @satisfies AC-100
final class VideoShaderConstantsTests: XCTestCase {

    // MARK: - PQ EOTF Tests

    func testPQEOTF_Black() {
        // PQ 0.0 应解码为线性 0.0
        let result = VideoShaderConstants.pqEOTF(0.0)
        XCTAssertEqual(result, 0.0, accuracy: 0.0001)
    }

    func testPQEOTF_SDRWhite() {
        // PQ 0.508 ≈ 203 nits (SDR 参考白)
        // 203/10000 = 0.0203 线性
        let result = VideoShaderConstants.pqEOTF(0.508)
        XCTAssertEqual(result, 0.0203, accuracy: 0.002)
    }

    func testPQEOTF_Peak() {
        // PQ 1.0 应解码为线性 1.0 (10000 nits)
        let result = VideoShaderConstants.pqEOTF(1.0)
        XCTAssertEqual(result, 1.0, accuracy: 0.01)
    }

    // MARK: - Gamut Mapping Tests

    func testGamutMapping_White() {
        // D65 白点在两个色域中应一致
        let white = simd_float3(1.0, 1.0, 1.0)
        let mapped = VideoShaderConstants.applyGamutMapping(white)
        XCTAssertEqual(mapped.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(mapped.y, 1.0, accuracy: 0.01)
        XCTAssertEqual(mapped.z, 1.0, accuracy: 0.01)
    }

    func testGamutMapping_Red() {
        // Rec.2020 红原色映射到 P3
        let rec2020Red = simd_float3(1.0, 0.0, 0.0)
        let p3Red = VideoShaderConstants.applyGamutMapping(rec2020Red)
        // P3 红比 2020 红更窄，所以 x 会略大于 1.0，需要 clamp
        XCTAssertGreaterThan(p3Red.x, 0.9)
    }

    func testGamutMapping_NoNegatives() {
        // 任意输入都不应产生负值
        let testColors: [simd_float3] = [
            simd_float3(0.5, 0.0, 0.0),
            simd_float3(0.0, 0.5, 0.0),
            simd_float3(0.0, 0.0, 0.5),
            simd_float3(0.3, 0.6, 0.9)
        ]

        for color in testColors {
            let mapped = VideoShaderConstants.applyGamutMapping(color)
            XCTAssertGreaterThanOrEqual(mapped.x, 0.0)
            XCTAssertGreaterThanOrEqual(mapped.y, 0.0)
            XCTAssertGreaterThanOrEqual(mapped.z, 0.0)
        }
    }

    // MARK: - ACES Tone Mapping Tests

    func testACES_Black() {
        let result = VideoShaderConstants.acesTonemap(simd_float3(0, 0, 0))
        XCTAssertEqual(result.x, 0.0, accuracy: 0.0001)
    }

    func testACES_Clamp() {
        // 高输入应被 clamp 到 1.0
        let result = VideoShaderConstants.acesTonemap(simd_float3(10, 10, 10))
        XCTAssertLessThanOrEqual(result.x, 1.0)
        XCTAssertLessThanOrEqual(result.y, 1.0)
        XCTAssertLessThanOrEqual(result.z, 1.0)
    }

    func testACES_SDRRange() {
        // SDR 范围 (0~1) 应有合理的 S 曲线响应
        let midGray = VideoShaderConstants.acesTonemap(simd_float3(0.18, 0.18, 0.18))
        XCTAssertGreaterThan(midGray.x, 0.1)
        XCTAssertLessThan(midGray.x, 0.3)
    }

    // MARK: - YUV Matrix Tests

    func testBT709_WhitePoint() {
        // Y=1, U=0, V=0 应转换为白色
        let yuv = simd_float3(1.0, 0.0, 0.0)
        let rgb = VideoShaderConstants.bt709Limited * yuv
        XCTAssertEqual(rgb.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.y, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.z, 1.0, accuracy: 0.01)
    }
}
```

### 18.7 代码结构变更

```
Chiaki/
├── Core/
│   └── Video/
│       ├── MetalVideoRenderer.swift      # [修改] AC-097, AC-098, AC-099
│       ├── HDRConfiguration.swift        # [无变更] 字段已存在
│       └── VideoShaderConstants.swift    # [新增] AC-100

Tests/
└── ChiakiTests/
    └── Video/
        └── VideoShaderConstantsTests.swift  # [新增] AC-100
```

### 18.8 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-097 | `VideoUniforms` + `MetalVideoRenderer` | 配置字段接入 Shader Uniforms |
| AC-098 | Metal Shader | `edrIntensity` 作为乘数应用 |
| AC-099 | Metal Shader | `gamutMappingEnabled` 控制色域映射 |
| AC-100 | `VideoShaderConstants` + Tests | CPU 端常量与测试 |

---

## 19. MainActor 边界规范化设计 [增量]

> **变更来源**: F-029 MainActor 边界规范化 (INS-050)
> **关联需求**: AC-101 ~ AC-103
> **设计版本**: v1.8.0

### 19.1 影响分析

#### 背景

项目中作为 UI 环境对象的 `@Observable` Store 类（如 `SettingsStore`、`HostStore`）目前没有整体标注 `@MainActor`。虽然单例 `shared` 属性已标注，但类本身的方法和属性可能被后台线程访问，导致 Observation 框架或 UI 的未定义行为。

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `SettingsStore` | 修改 | 整体标注 `@MainActor` |
| `HostStore` | 修改 | 整体标注 `@MainActor` |
| 其他 Observable Store | 审查 | 评估是否需要 `@MainActor` |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| 添加 `@MainActor` | ⚠️ 源码兼容 | 现有调用方可能需要 `await` 或 `MainActor.run` |
| 运行时行为 | ✅ 兼容 | 确保线程安全，不影响功能 |

### 19.2 SettingsStore 标注 (AC-101)

```swift
/// 设置存储，管理 UserDefaults 持久化
/// @requirement F-029
/// @satisfies AC-101
@MainActor
@Observable
class SettingsStore {
    static let shared = SettingsStore()

    var streamSettings: StreamSettings {
        didSet { saveSettings() }
    }

    var useRemoteProfile: Bool {
        didSet { userDefaults.set(useRemoteProfile, forKey: "use_remote_profile") }
    }

    // ... 其他属性 ...

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // 初始化逻辑 ...
    }

    // 所有方法自动在 MainActor 上执行
    func updateResolution(_ resolution: StreamSettings.Resolution) { ... }
    func updateFrameRate(_ frameRate: StreamSettings.FrameRate) { ... }
    // ...
}
```

### 19.3 HostStore 标注 (AC-102)

```swift
/// 主机存储，管理 PlayStation 主机持久化
/// @requirement F-029
/// @satisfies AC-102
@MainActor
@Observable
final class HostStore {
    static let shared = HostStore()

    private(set) var hosts: [ConsoleHost] = []

    var visibleRegisteredHosts: [ConsoleHost] { ... }
    var registeredHosts: [ConsoleHost] { ... }
    var hiddenHosts: [ConsoleHost] { ... }

    private let userDefaults: UserDefaults
    private let hostsKey = "chiaki.savedHosts"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadHosts()
    }

    // CRUD 操作自动在 MainActor 上执行
    func addHost(_ host: ConsoleHost) { ... }
    func updateHost(_ host: ConsoleHost) { ... }
    func removeHost(_ host: ConsoleHost) { ... }
    // ...
}
```

### 19.4 其他 Observable Store 审查 (AC-103)

需要审查的 Store 类：

| 类名 | 当前状态 | 建议操作 | 理由 |
|------|----------|----------|------|
| `SettingsStore` | 无 `@MainActor` | ✅ 标注 | Environment 对象，UI 直接绑定 |
| `HostStore` | 无 `@MainActor` | ✅ 标注 | Environment 对象，UI 直接绑定 |
| `ControllerManager` | 已有 `@MainActor` | ✅ 保持 | - |
| `NetworkMonitor` | 使用 `nonisolated` | ⚠️ 审查 | 回调可能在后台，需确保状态更新在 MainActor |
| `DiscoveryService` | 无 `@MainActor` | ⚠️ 审查 | 回调来自 libchiaki，需要 dispatch |

#### NetworkMonitor 修正模式

```swift
/// 网络监控器
/// @satisfies AC-103
@Observable
final class NetworkMonitor {
    @MainActor static let shared = NetworkMonitor()

    @MainActor private(set) var isConnected: Bool = true
    @MainActor private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")

    nonisolated init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // 确保状态更新在 MainActor
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.mapConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    @MainActor
    private func mapConnectionType(_ path: NWPath) -> ConnectionType {
        // ...
    }
}
```

### 19.5 迁移指南

对于现有调用方，可能需要以下调整：

```swift
// 场景 1: 从非 MainActor 上下文访问 Store
// 修改前（可能警告或运行时问题）
func fetchAndUpdateSettings() {
    let settings = SettingsStore.shared.streamSettings  // ⚠️
}

// 修改后
func fetchAndUpdateSettings() async {
    let settings = await MainActor.run {
        SettingsStore.shared.streamSettings
    }
}

// 或使用 Task
func fetchAndUpdateSettings() {
    Task { @MainActor in
        let settings = SettingsStore.shared.streamSettings
        // ...
    }
}

// 场景 2: 在 async 函数中
@MainActor
func updateUI() async {
    // 已在 MainActor 上，无需修改
    let settings = SettingsStore.shared.streamSettings
}
```

### 19.6 代码结构变更

```
Chiaki/
├── Core/
│   └── Storage/
│       ├── SettingsStore.swift    # [修改] AC-101 - 添加 @MainActor
│       └── HostStore.swift        # [修改] AC-102 - 添加 @MainActor
│
│   └── Network/
│       └── NetworkMonitor.swift   # [修改] AC-103 - MainActor 状态更新
```

### 19.7 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-101 | `SettingsStore` | 整体标注 `@MainActor` |
| AC-102 | `HostStore` | 整体标注 `@MainActor` |
| AC-103 | 其他 Store 审查 | `NetworkMonitor` 等确保 MainActor 状态更新 |

---

## 20. 日志输出规范化设计 [增量]

> **变更来源**: F-030 日志输出规范化 (INS-051)
> **关联需求**: AC-104 ~ AC-106
> **设计版本**: v1.8.0

### 20.1 影响分析

#### 背景

`ChiakiSessionWrapper` 及其他 Bridge 层文件中存在大量 debug `print` 语句，这些在 release 版本中会产生噪声和性能损耗。需要统一走 Logger 系统，并用 `#if DEBUG` 保护 verbose 日志。

#### 受影响的模块

| 模块 | 影响类型 | 说明 |
|------|----------|------|
| `ChiakiSessionWrapper` | 修改 | `print` → `Logger` |
| `ChiakiDiscovery` | 审查 | 检查 debug 输出 |
| `ChiakiRegist` | 审查 | 检查 debug 输出 |
| `VideoDecoderBridge` | 审查 | 检查 debug 输出 |
| `AudioPlayerBridge` | 审查 | 检查 debug 输出 |

#### 兼容性评估

| 变更 | 向后兼容 | 说明 |
|------|----------|------|
| `print` → `Logger` | ✅ 兼容 | 纯重构，不影响功能 |
| `#if DEBUG` 保护 | ✅ 兼容 | Release 版本行为更优 |

### 20.2 日志规范

#### 日志级别使用规范

| 级别 | 用途 | DEBUG 保护 |
|------|------|-----------|
| `logError` | 错误，影响功能 | ❌ 不需要 |
| `logWarning` | 警告，可能影响体验 | ❌ 不需要 |
| `logInfo` | 关键状态变化 | ❌ 不需要 |
| `logDebug` | 调试信息，频繁调用 | ✅ 建议 |
| `logVerbose` | 详细追踪，高频 | ✅ 必须 |

#### DEBUG 保护模式

```swift
// 模式 1: 使用 logDebug/logVerbose（内部已有条件检查）
// 这是推荐的方式，Logger 内部会根据 levelMask 过滤
logDebug("Session callback received: \(eventType)")

// 模式 2: 显式 #if DEBUG（用于避免参数计算开销）
#if DEBUG
logVerbose("Frame details: size=\(frame.size), pts=\(frame.pts), data=\(frame.data.hexDump)")
#endif

// 模式 3: 避免在 Release 中计算昂贵参数
#if DEBUG
let debugInfo = expensiveDebugComputation()
logDebug("Debug info: \(debugInfo)")
#endif
```

### 20.3 ChiakiSessionWrapper 日志替换 (AC-104)

```swift
// 修改前
print("🎮 Session callback setup complete")
print("📺 Video callback: \(width)x\(height), format=\(format)")
print("🔊 Audio callback: \(channels)ch, \(sampleRate)Hz")

// 修改后
/// @requirement F-030
/// @satisfies AC-104
extension ChiakiSessionWrapper {
    private func setupCallbacks() {
        // 使用 Logger.session
        Logger.session.info("Session callback setup complete")

        // 详细日志使用 DEBUG 保护
        #if DEBUG
        Logger.session.debug("Video callback configured: \(width)x\(height), format=\(format)")
        Logger.session.debug("Audio callback configured: \(channels)ch, \(sampleRate)Hz")
        #endif
    }

    private func handleVideoData(_ data: UnsafePointer<UInt8>, length: Int) {
        // 高频回调使用 verbose
        #if DEBUG
        logVerbose("Video data received: \(length) bytes")
        #endif

        // 错误情况总是记录
        guard length > 0 else {
            Logger.video.warning("Empty video data received")
            return
        }

        // 处理逻辑...
    }
}
```

### 20.4 DEBUG 保护审查 (AC-105)

需要添加 `#if DEBUG` 保护的位置：

```swift
// ChiakiSessionWrapper.swift
#if DEBUG
Logger.session.debug("Event: \(eventType), data: \(eventData)")
#endif

// VideoDecoderBridge.swift
#if DEBUG
Logger.video.debug("NAL unit: type=\(nalType), size=\(nalSize)")
Logger.video.debug("Decode latency: \(latencyMs)ms")
#endif

// AudioPlayerBridge.swift
#if DEBUG
Logger.audio.debug("Audio buffer: \(bufferSize) samples, latency=\(latency)ms")
#endif
```

### 20.5 Bridge 层日志审查清单 (AC-106)

| 文件 | 审查项 | 状态 |
|------|--------|------|
| `ChiakiSession.swift` | 替换 `print`，添加 DEBUG 保护 | 待完成 |
| `ChiakiDiscovery.swift` | 检查发现回调日志 | 待完成 |
| `ChiakiRegist.swift` | 检查注册流程日志 | 待完成 |
| `ChiakiLogBridge.swift` | 确保 libchiaki 日志正确转发 | 已完成 |
| `VideoDecoderBridge.swift` | 高频解码日志 DEBUG 保护 | 待完成 |
| `VideoToolboxDecoder.swift` | 解码错误日志保留 | 待完成 |
| `AudioPlayerBridge.swift` | 高频音频日志 DEBUG 保护 | 待完成 |

### 20.6 日志输出对比

```
=== Release 版本（优化后）===
[INFO] [Session] Connected to PlayStation 5
[INFO] [Session] Streaming started
[WARNING] [Video] Frame decode delayed: 45ms
[ERROR] [Network] Connection lost

=== Debug 版本 ===
[INFO] [Session] Connected to PlayStation 5
[DEBUG] [Session] Event: CHIAKI_EVENT_CONNECTED, data: 0x...
[DEBUG] [Session] Video callback configured: 1920x1080, format=P010
[DEBUG] [Session] Audio callback configured: 2ch, 48000Hz
[INFO] [Session] Streaming started
[VERBOSE] [Video] NAL unit: type=5, size=12345
[VERBOSE] [Video] Decode latency: 8.5ms
[DEBUG] [Audio] Buffer: 1024 samples, latency=21ms
[WARNING] [Video] Frame decode delayed: 45ms
[ERROR] [Network] Connection lost
```

### 20.7 代码结构变更

```
Chiaki/
├── Core/
│   └── Bridge/
│       ├── ChiakiSession.swift        # [修改] AC-104 - print → Logger
│       ├── ChiakiDiscovery.swift      # [审查] AC-106
│       ├── ChiakiRegist.swift         # [审查] AC-106
│       └── ChiakiLogBridge.swift      # [无变更] 已正确实现
│
│   └── Video/
│       ├── VideoDecoderBridge.swift   # [审查] AC-105, AC-106
│       └── VideoToolboxDecoder.swift  # [审查] AC-106
│
│   └── Audio/
│       └── AudioPlayerBridge.swift    # [审查] AC-105, AC-106
```

### 20.8 需求追溯

| 验收标准 | 实现模块 | 说明 |
|----------|----------|------|
| AC-104 | `ChiakiSessionWrapper` | `print` → `Logger` |
| AC-105 | Bridge 层 | verbose 日志 `#if DEBUG` 保护 |
| AC-106 | 所有 Bridge 文件 | 统一日志输出方式审查 |

---

## 设计变更记录

### v1.8.0 (2026-02-04)

**变更来源**: F-028 HDR 配置完全落地 (INS-048), F-029 MainActor 边界规范化 (INS-050), F-030 日志输出规范化 (INS-051)

**新增模块**:
- `VideoShaderConstants` - CPU 端 Shader 常量定义（关联 AC-100）
- `VideoShaderConstantsTests` - Shader 常量单元测试（关联 AC-100）

**修改模块**:
- `VideoUniforms` - 新增 `edrIntensity`、`gamutMappingEnabled` 字段（关联 AC-097）
- `MetalVideoRenderer` - 同步 HDRConfiguration 新字段到 Uniforms（关联 AC-097, AC-098, AC-099）
- `VideoShaders.metal` (运行时源) - 动态色域映射和 EDR 强度（关联 AC-098, AC-099）
- `SettingsStore` - 添加 `@MainActor` 标注（关联 AC-101）
- `HostStore` - 添加 `@MainActor` 标注（关联 AC-102）
- `NetworkMonitor` - 确保状态更新在 MainActor（关联 AC-103）
- `ChiakiSessionWrapper` - `print` → `Logger`，DEBUG 保护（关联 AC-104, AC-105）
- Bridge 层文件 - 统一日志输出方式（关联 AC-106）

**破坏性变更**:
- `SettingsStore` 和 `HostStore` 添加 `@MainActor` 后，从非 MainActor 上下文访问需要 `await`

**迁移说明**:
1. 现有直接访问 Store 属性的代码，如在后台线程中，需改用 `await MainActor.run { ... }`
2. 视图层代码无需修改，SwiftUI 自动在 MainActor 上执行
3. `VideoUniforms` 结构大小增加 8 字节，但对齐未变
