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

## 已归档增量设计

> §8~§20 增量设计已归档，详见 [归档文件](archive/02-system-design-archive.md)

| 章节 | 关联功能 | 主题 |
|------|----------|------|
| §8 | F-010~F-014 | 架构优化设计（StreamingViewModel 拆分、现代化 UI 规范） |
| §9 | F-015~F-018 | 生产就绪设计（网络弹性、本地化、性能管理） |
| §10 | F-019 | 完善日志系统（FileLogHandler、DiagnosticsExporter、CrashReporter） |
| §11 | F-020 | 手柄操作友好化（焦点管理、tvOS 导航、组合键检测） |
| §12 | F-021 | GameController 深度集成（自适应扳机、触控板、电池显示） |
| §13 | F-022 | 手柄操控 UI/UX 优化（快速操作栏、音量快捷键、数字键盘） |
| §14 | F-023 | iPad 触摸操作友好化（触摸目标、间距、手势、无障碍） |
| §15 | F-025 | HDR 渲染管线优化（色域映射、EDR Headroom、Tone Mapping） |
| §16 | F-026 | 渲染模块解耦重构（VideoRenderer 协议、Coordinator 分离） |
| §17 | F-027 | UI 层 MVVM 合规重构（Singleton 解耦、ViewModel 补全） |
| §18 | F-028 | HDR 配置完全落地（Shader 动态分支、单元测试） |
| §19 | F-029 | MainActor 边界规范化（Store 标注、迁移指南） |
| §20 | F-030 | 日志输出规范化（print→Logger、DEBUG 保护） |
| §19(v2) | F-038 | Swift/C Bridge 安全加固（生命周期、内存、线程、指针安全） |

### 设计变更记录摘要

| 版本 | 日期 | 变更来源 |
|------|------|----------|
| v1.3.0 | 2026-01-28 | F-019 日志系统 |
| v1.4.0 | 2026-01-30 | F-020 手柄友好化, F-021 GC 集成 |
| v1.5.0 | 2026-01-30 | F-022 手柄 UI/UX |
| v1.6.0 | 2026-02-02 | F-023 iPad 触摸 |
| v1.7.0 | 2026-02-04 | F-025 HDR 渲染, F-026 渲染解耦, F-027 MVVM |
| v1.8.0 | 2026-02-04 | F-028 HDR 落地, F-029 MainActor, F-030 日志规范 |
| v1.9.0 | 2026-02-08 | F-038 Bridge 安全加固 |
| v2.0.0 | 2026-02-10 | F-040 控制器架构分层重构 |

---

## §21. 控制器架构分层重构 (F-040)

> **关联需求**: F-040 (AC-151 ~ AC-157)
> **来源洞察**: INS-078 ~ INS-081
> **影响模块**: Core/Controllers, Features/Streaming

### 21.1 架构概述

将当前单体 `ControllerManager`（800+ 行）拆分为 Provider 分层架构：

```
┌──────────────────────────────────────────────────────────────────────┐
│                    StreamingViewModel                                  │
│                  (仅依赖 ControllerOrchestrator)                       │
└────────────────────────┬─────────────────────────────────────────────┘
                         │ onInputChanged / applyRumble
                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    ControllerOrchestrator                              │
│  @MainActor @Observable                                               │
│                                                                       │
│  职责:                                                                │
│  - 设备发现 (GCController notifications)                              │
│  - Provider 选择与生命周期管理                                         │
│  - 输入合并 (多 Provider → 统一 ChiakiControllerInput)                │
│  - 反馈路由 (rumble/adaptive triggers → 活跃 Provider)                │
│  - 连接状态跟踪 (connectedControllers, activeController)              │
│                                                                       │
│  属性:                                                                │
│  - providers: [any ControllerInputProvider]                           │
│  - activeProvider: (any ControllerInputProvider)?                     │
│  - fallbackProvider: GameControllerProvider?                          │
│  - currentInput: ChiakiControllerInput                               │
│  - onInputChanged: ((ChiakiControllerInput?) -> Void)?               │
└──────┬──────────────────────┬──────────────────────┬─────────────────┘
       │                      │                      │
  ┌────▼──────────┐   ┌──────▼────────────┐  ┌─────▼────────────┐
  │ DualSense     │   │ GameController    │  │ DualShock4       │
  │ HIDProvider   │   │ Provider          │  │ HIDProvider      │
  │ (macOS only)  │   │ (all platforms)   │  │ (macOS only)     │
  │               │   │                   │  │                  │
  │ IOKit HID     │   │ GCController      │  │ IOKit HID        │
  │ PS button ✓   │   │ All buttons       │  │ PS button ✓      │
  │ Rumble ✓      │   │ Sticks/Triggers   │  │ Rumble ✓         │
  │ Adaptive ✓    │   │ GCDeviceHaptics   │  │                  │
  └───────────────┘   └───────────────────┘  └──────────────────┘
```

### 21.2 核心协议

#### 21.2.1 ControllerInputProvider

```swift
/// 控制器输入提供者协议
/// [satisfies] AC-151
protocol ControllerInputProvider: AnyObject {
    /// 唯一标识符
    var providerId: String { get }

    /// Provider 显示名称
    var displayName: String { get }

    /// 是否已连接设备
    var isConnected: Bool { get }

    /// 支持的能力集
    var capabilities: ControllerCapabilities { get }

    /// 当前输入状态（由 Provider 自行维护，Orchestrator 按需读取）
    var currentInput: ChiakiControllerInput { get }

    /// 输入变化回调（Provider 有新输入时调用）
    var onInputChanged: ((ChiakiControllerInput) -> Void)? { get set }

    /// 连接状态变化回调
    var onConnectionChanged: ((Bool) -> Void)? { get set }

    /// 启动 Provider（开始监听设备）
    func start()

    /// 停止 Provider（释放资源）
    func stop()
}
```

#### 21.2.2 ControllerFeedbackOutput

```swift
/// 控制器反馈输出协议
/// [satisfies] AC-154
protocol ControllerFeedbackOutput: AnyObject {
    /// 发送 rumble（左右马达独立控制）
    func sendRumble(left: UInt8, right: UInt8)

    /// 应用自适应扳机效果（DualSense 专属）
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide)

    /// 设置 LED 颜色（如 DualSense 灯条）
    func setLEDColor(red: UInt8, green: UInt8, blue: UInt8)

    /// 是否支持该反馈类型
    func supportsFeedback(_ type: FeedbackType) -> Bool
}

/// 反馈类型枚举
enum FeedbackType {
    case rumble
    case adaptiveTriggers
    case ledColor
}
```

#### 21.2.3 ControllerCapabilities

```swift
/// Provider 能力集
/// [satisfies] AC-151
struct ControllerCapabilities: OptionSet {
    let rawValue: UInt32

    static let standardButtons  = ControllerCapabilities(rawValue: 1 << 0)
    static let analogSticks     = ControllerCapabilities(rawValue: 1 << 1)
    static let analogTriggers   = ControllerCapabilities(rawValue: 1 << 2)
    static let psButton         = ControllerCapabilities(rawValue: 1 << 3)
    static let touchpad         = ControllerCapabilities(rawValue: 1 << 4)
    static let motion           = ControllerCapabilities(rawValue: 1 << 5)
    static let rumble           = ControllerCapabilities(rawValue: 1 << 6)
    static let adaptiveTriggers = ControllerCapabilities(rawValue: 1 << 7)
    static let ledColor         = ControllerCapabilities(rawValue: 1 << 8)

    /// DualSense HID 完整能力集
    static let dualSenseHID: ControllerCapabilities = [
        .psButton, .rumble, .adaptiveTriggers, .ledColor
    ]

    /// GameController 框架标准能力集
    static let gameController: ControllerCapabilities = [
        .standardButtons, .analogSticks, .analogTriggers,
        .touchpad, .motion
    ]
}
```

### 21.3 Provider 实现

#### 21.3.1 DualSenseHIDProvider (macOS only)

基于现有 `DualSenseHIDManager` 重构，同时实现 `ControllerInputProvider` + `ControllerFeedbackOutput`。

```swift
/// DualSense IOKit HID Provider
/// [satisfies] AC-152, AC-153
/// macOS only - 优先于 GameController 处理 PS button 和 rumble
#if os(macOS)
final class DualSenseHIDProvider: ControllerInputProvider, ControllerFeedbackOutput {
    let providerId = "dualsense-hid"
    let displayName = "DualSense (HID)"

    let capabilities: ControllerCapabilities = .dualSenseHID

    // 支持的设备 VID/PID
    static let supportedDevices: [(vid: Int, pid: Int, name: String)] = [
        (0x054C, 0x0CE6, "DualSense"),
        (0x054C, 0x0DF2, "DualSense Edge"),
    ]

    // 内部实现复用现有 DualSenseHIDManager 的 IOKit 逻辑
    // - HID Manager 生命周期
    // - Enhanced BT mode 激活
    // - 输入报文解析 (PS button from buttons[2] bit 0)
    // - 输出报文构造 (rumble, adaptive triggers)
    // - CRC32 计算 (BT)
    // - 序列号管理 (BT)
}
#endif
```

**关键设计决策**：
- HID Provider 仅提供 GameController 不可靠的能力（PS button、rumble、adaptive triggers）
- 标准按键/摇杆/扳机由 GameControllerProvider 提供，避免重复解析
- 非排他 HID 打开（`kIOHIDOptionsTypeNone`），与 GameController 安全共存

#### 21.3.2 GameControllerProvider (all platforms)

```swift
/// GameController 框架 Provider
/// [satisfies] AC-152, AC-157
final class GameControllerProvider: ControllerInputProvider, ControllerFeedbackOutput {
    let providerId = "gamecontroller"
    let displayName = "GameController Framework"

    let capabilities: ControllerCapabilities = .gameController

    /// 绑定的 GCController 实例
    private(set) var controller: GCController?

    // 内部实现:
    // - GCExtendedGamepad.valueChangedHandler
    // - 触控板解析 (GCDualSenseGamepad/GCDualShockGamepad)
    // - 运动传感器 (GCMotion)
    // - GCDeviceHaptics rumble (非 macOS DualSense 场景)

    /// 绑定到特定 GCController
    func bind(to controller: GCController) { ... }

    /// 解绑
    func unbind() { ... }
}
```

#### 21.3.3 DualShock4HIDProvider (macOS only, P2)

```swift
/// DualShock 4 IOKit HID Provider
/// [satisfies] AC-156
#if os(macOS)
final class DualShock4HIDProvider: ControllerInputProvider, ControllerFeedbackOutput {
    let providerId = "dualshock4-hid"
    let displayName = "DualShock 4 (HID)"

    let capabilities: ControllerCapabilities = [.psButton, .rumble, .ledColor]

    static let supportedDevices: [(vid: Int, pid: Int, name: String)] = [
        (0x054C, 0x05C4, "DualShock 4 v1"),
        (0x054C, 0x09CC, "DualShock 4 v2"),
    ]

    // DS4 HID 报文格式:
    // - USB: Report ID 0x05, 32 bytes output
    // - BT: Report ID 0x11, 78 bytes output (CRC32)
    // - PS button: buttons[2] bit 0
    // - Rumble: motor_right (byte 4), motor_left (byte 5) in USB report
}
#endif
```

### 21.4 Orchestrator 设计

```swift
/// 控制器编排器
/// [satisfies] AC-155
/// 取代现有 ControllerManager 的核心职责
@MainActor @Observable
final class ControllerOrchestrator {
    // MARK: - 公开状态

    private(set) var connectedControllers: [ControllerInfo] = []
    private(set) var activeController: ControllerInfo?
    private(set) var currentInput = ChiakiControllerInput()

    var onInputChanged: ((ChiakiControllerInput?) -> Void)?

    var hapticsEnabled: Bool = true
    var adaptiveTriggersEnabled: Bool = true

    // MARK: - Provider 管理

    /// 当前活跃的 Provider 列表（可能同时有 HID + GC）
    private var activeProviders: [any ControllerInputProvider] = []

    /// 反馈输出路由（HID 优先）
    private var feedbackProvider: (any ControllerFeedbackOutput)?

    /// GameController Provider（始终存在作为 fallback）
    private var gcProvider: GameControllerProvider?

    #if os(macOS)
    /// HID Provider 注册表
    private var hidProviders: [any ControllerInputProvider & ControllerFeedbackOutput] = []
    #endif

    // MARK: - 设备发现

    /// 处理 GCController 连接
    private func handleControllerConnected(_ controller: GCController) {
        // 1. 创建 GameControllerProvider 并绑定
        let gcProvider = GameControllerProvider()
        gcProvider.bind(to: controller)

        #if os(macOS)
        // 2. 检查 VID/PID，尝试匹配 HID Provider
        if let hidProvider = matchHIDProvider(for: controller) {
            // HID Provider 作为主要反馈输出
            hidProvider.start()
            activeProviders.append(hidProvider)
            feedbackProvider = hidProvider
        }
        #endif

        // 3. GC Provider 始终作为标准输入源
        gcProvider.start()
        activeProviders.append(gcProvider)

        // 4. 如果没有 HID feedback，用 GC 作为 fallback
        if feedbackProvider == nil {
            feedbackProvider = gcProvider
        }
    }

    // MARK: - 输入合并

    /// 合并多个 Provider 的输入
    /// HID Provider: PS button
    /// GC Provider: 其他所有按键、摇杆、扳机、触控板、运动
    private func mergeInput() {
        var merged = ChiakiControllerInput()

        for provider in activeProviders {
            let input = provider.currentInput
            let caps = provider.capabilities

            if caps.contains(.psButton) {
                // HID Provider 提供 PS button
                if input.buttons.contains(.ps) {
                    merged.buttons.insert(.ps)
                }
            }
            if caps.contains(.standardButtons) {
                // GC Provider 提供标准按键
                merged.buttons.formUnion(input.buttons.subtracting(.ps))
            }
            if caps.contains(.analogSticks) {
                merged.leftStickX = input.leftStickX
                merged.leftStickY = input.leftStickY
                merged.rightStickX = input.rightStickX
                merged.rightStickY = input.rightStickY
            }
            if caps.contains(.analogTriggers) {
                merged.l2State = input.l2State
                merged.r2State = input.r2State
            }
            if caps.contains(.touchpad) {
                merged.touchpad0 = input.touchpad0
                merged.touchpad1 = input.touchpad1
            }
            if caps.contains(.motion) {
                merged.gyroX = input.gyroX
                merged.gyroY = input.gyroY
                merged.gyroZ = input.gyroZ
                merged.accelX = input.accelX
                merged.accelY = input.accelY
                merged.accelZ = input.accelZ
            }
        }

        currentInput = merged
        onInputChanged?(merged)
    }

    // MARK: - 反馈路由

    /// 应用 rumble — 通过活跃的 feedbackProvider 路由
    /// [satisfies] AC-154
    func applyRumble(left: UInt8, right: UInt8) {
        guard hapticsEnabled else { return }
        guard left > 0 || right > 0 else { return }
        feedbackProvider?.sendRumble(left: left, right: right)
    }

    /// 应用自适应扳机
    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        guard adaptiveTriggersEnabled else { return }
        feedbackProvider?.applyAdaptiveTrigger(effect: effect, side: side)
    }
}
```

### 21.5 Provider 选择策略

```
[satisfies] AC-152, AC-153

GCController 连接事件
        │
        ▼
  识别 VID/PID
        │
        ├── 匹配 DualSense (0x054C:0x0CE6/0x0DF2) + macOS
        │   │
        │   ├── 启动 DualSenseHIDProvider (主: PS button + rumble + adaptive)
        │   └── 启动 GameControllerProvider (辅: buttons + sticks + triggers + touchpad)
        │       feedbackProvider = DualSenseHIDProvider
        │
        ├── 匹配 DualShock 4 (0x054C:0x05C4/0x09CC) + macOS
        │   │
        │   ├── 启动 DualShock4HIDProvider (主: PS button + rumble)
        │   └── 启动 GameControllerProvider (辅: buttons + sticks + triggers)
        │       feedbackProvider = DualShock4HIDProvider
        │
        └── 其他手柄 / iOS / tvOS
            │
            └── 仅启动 GameControllerProvider (全能力)
                feedbackProvider = GameControllerProvider
```

### 21.6 VID/PID 匹配机制

```swift
#if os(macOS)
/// 从 GCController 提取 VID/PID 并匹配 HID Provider
private func matchHIDProvider(for controller: GCController) -> (any ControllerInputProvider & ControllerFeedbackOutput)? {
    // 使用 IOKit HID 注册表查询 VID/PID
    // GCController 不直接暴露 VID/PID，需要通过 IOServiceMatching 关联

    // DualSense 匹配
    for device in DualSenseHIDProvider.supportedDevices {
        if isControllerMatching(controller, vid: device.vid, pid: device.pid) {
            return DualSenseHIDProvider()
        }
    }

    // DualShock 4 匹配
    for device in DualShock4HIDProvider.supportedDevices {
        if isControllerMatching(controller, vid: device.vid, pid: device.pid) {
            return DualShock4HIDProvider()
        }
    }

    return nil
}
#endif
```

### 21.7 文件结构变更

```
Chiaki/Core/Controllers/
├── ControllerOrchestrator.swift      # 新增: 设备编排器 (原 ControllerManager 核心逻辑)
├── ControllerInputProvider.swift     # 新增: Provider 协议 + Capabilities + FeedbackOutput
├── GameControllerProvider.swift      # 新增: GCController 封装 Provider
├── DualSenseHIDProvider.swift        # 重构: 从 DualSenseHIDManager 重构
├── DualShock4HIDProvider.swift       # 新增: DS4 HID Provider (P2)
├── ControllerInputMapper.swift       # 保留: 按键映射（可能移入 GameControllerProvider）
├── ControllerShortcutDetector.swift  # 保留: 快捷键检测
├── AdaptiveTriggerEffect.swift       # 保留: 扳机效果定义
├── HapticsManager.swift              # 保留: 设备振动 fallback（非手柄振动）
└── ControllerManager.swift           # 删除: 由 ControllerOrchestrator 替代
```

### 21.8 迁移策略

分步执行，每步可独立编译和验证：

| 步骤 | 内容 | 风险 |
|------|------|------|
| 1 | 定义 `ControllerInputProvider` + `ControllerFeedbackOutput` 协议 | 低: 仅新增文件 |
| 2 | 实现 `GameControllerProvider`，从 ControllerManager 提取 GC 逻辑 | 中: 核心逻辑迁移 |
| 3 | 重构 `DualSenseHIDManager` → `DualSenseHIDProvider` | 中: 接口适配 |
| 4 | 实现 `ControllerOrchestrator`，替代 ControllerManager | 高: 替换入口 |
| 5 | 更新 StreamingViewModel 接入 Orchestrator | 中: 集成点变更 |
| 6 | 新增 `DualShock4HIDProvider` | 低: 纯新增 |
| 7 | 删除 ControllerManager.swift，全面切换 | 中: 清理 |

### 21.9 线程安全模型

```
┌─────────────────────┐
│  Main Thread         │ ← @MainActor (Orchestrator, Provider 状态)
│  - UI 更新            │
│  - 输入合并            │
│  - Provider 生命周期   │
└─────────┬───────────┘
          │ 回调
┌─────────▼───────────┐
│  IOKit HID RunLoop   │ ← HID Provider 的输入报文回调
│  - 原始报文解析       │
│  - DispatchQueue.main │  → 转发到主线程
│    .async 投递        │
└─────────────────────┘

┌─────────────────────┐
│  GCController        │ ← valueChangedHandler 在主线程调用
│  RunLoop Thread      │    (Apple 保证)
└─────────────────────┘
```

### 21.10 回归保护

- [satisfies] AC-157
- 所有平台标准输入（摇杆、面按键、扳机）不受 Provider 拆分影响
- iOS/tvOS 路径无变化（无 HID Provider，仅 GameControllerProvider）
- macOS DualSense 路径：HID → PS button + rumble，GC → 其他输入（与当前行为一致）
- 新增 DualShock 4 HID 不影响现有 DualSense 逻辑

---

*§21 新增 (2026-02-10): F-040 控制器架构分层重构*

## §22. Metal 原生高质量视频滤波管线 (F-041)

> **来源**: INS-082~INS-084 深度技术调研
> **关联 Bug**: BUG-016（运动模糊残留）, BUG-017（窗口最大化模糊残留）
> **方案决策**: Metal 原生 shader 实现（排除 libplacebo+MoltenVK 方案，详见 INS-085 评估）

### 22.1 问题根因与方案选择

**当前渲染管线瓶颈**：

```
CVPixelBuffer (NV12/P010)
    │
    ▼
[bilinear 采样] ← 仅 mag_filter::linear, min_filter::linear
    │                4 texel 线性插值，720p→4K 放大时细节严重丢失
    ▼
[YUV→RGB + HDR]
    │
    ▼
输出 drawable    ← 无锐化、无去色带、无抖动
```

**chiaki-ng（libplacebo）对照**：

| 能力 | chiaki-ng | 当前 Chiaki Apple | F-041 目标 |
|------|-----------|-------------------|------------|
| 上采样 | EWA Lanczos Sharp | bilinear | Bicubic Catmull-Rom 9-tap |
| 下采样 | Hermite | bilinear | bilinear（下采样场景少） |
| 锐化 | 隐式（EWA Sharp 变体） | 无 | CAS 自适应锐化 |
| 去色带 | 4-tap + grain | 无 | 4-tap + Bayer 抖动 |
| Sigmoid | 有 | 无 | 暂不实现（收益有限） |
| 帧混合 | oversample/linear | 无 | 暂不实现（增加延迟） |
| 预设 | fast/default/hq | 未接入渲染 | Performance/Default/HQ |

**方案排除记录**：

| 方案 | 排除原因 |
|------|----------|
| libplacebo + MoltenVK | 翻译层 5-15% 开销、LGPL 许可证风险、iOS/tvOS 不原生支持、+15-25MB 包体积 |
| MetalFX Spatial Scaler | 需额外 render pass（YUV→RGB→scale→输出）、操作 RGB 不能直接处理 YUV |
| MPSImageLanczosScale | 需中间纹理分配，打破零拷贝架构 |

### 22.2 目标渲染管线

```
CVPixelBuffer (NV12/P010)
    │
    ├─ Y plane ──► [Bicubic Catmull-Rom 9-tap]  ← 利用硬件 bilinear 合并相邻 tap
    │                                                16 taps → 9 taps 优化
    ├─ UV plane ─► [bilinear 硬件采样]           ← 色度半分辨率，人眼不敏感
    │
    ▼
[YUV→RGB 转换 + HDR 处理]                        ← 现有逻辑不变
    │
    ▼
[CAS 自适应锐化]                                  ← 3x3 邻域 9 taps
    │                                                高对比度区域自动降低锐化
    ▼
[去色带 + Bayer 抖动]                              ← 4 taps 随机邻域 + 4x4 抖动矩阵
    │
    ▼
输出 drawable
```

**关键设计约束**：
- [satisfies] AC-168: 全部在单次 fragment shader 内完成，无额外 render pass
- [satisfies] AC-168: 保持 CVMetalTextureCache 零拷贝，不引入中间纹理
- [satisfies] AC-167: 全管线 ≤ 2ms（1080p→4K, 60fps, Apple Silicon）

### 22.3 VideoUniforms 扩展

```metal
struct VideoUniforms {
    // === 现有字段（不变） ===
    float4x4 transform;
    float2 textureSizeY;
    float2 textureSizeUV;
    float brightness;
    float contrast;
    float saturation;
    uint colorSpace;
    uint colorRange;
    float edrHeadroom;
    uint tonemapMode;
    float edrIntensity;
    uint gamutMappingEnabled;

    // === F-041 新增字段 ===
    uint upscaleFilter;       // [satisfies] AC-159: 0=bilinear, 1=bicubic, 2=lanczos2
    float casStrength;        // [satisfies] AC-161: 0.0=off, 0.0-1.0
    uint debandEnabled;       // [satisfies] AC-163: 0=off, 1=on
    float debandThreshold;    // [satisfies] AC-163: 默认 0.004
    float debandGrain;        // [satisfies] AC-163: 默认 0.003
    float _pad4;              // 对齐到 16 字节边界
};
```

**struct 大小**：从 128 字节扩展到 160 字节（+32 字节，含对齐填充）。

### 22.4 Bicubic Catmull-Rom 上采样算法

**原理**：Catmull-Rom 是一种 C1 连续的插值样条，使用 4x4 邻域（16 taps）。通过利用 Metal 硬件 bilinear 采样，将相邻权重为正的两个 tap 合并为一次 bilinear `sample()` 调用，优化为 3x3 = 9 taps。

```metal
// [satisfies] AC-158
float4 sampleBicubicCatmullRom(texture2d<float> tex, sampler s,
                                float2 uv, float2 texSize) {
    float2 samplePos = uv * texSize;
    float2 texPos1 = floor(samplePos - 0.5) + 0.5;
    float2 f = samplePos - texPos1;

    // Catmull-Rom 权重（Horner 形式，减少乘法）
    float2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    float2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    float2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    float2 w3 = f * f * (-0.5 + 0.5 * f);

    // 合并中间两个权重用于 bilinear 优化
    float2 w12 = w1 + w2;
    float2 offset12 = w2 / w12;

    float2 texPos0  = (texPos1 - 1.0) / texSize;
    float2 texPos3  = (texPos1 + 2.0) / texSize;
    float2 texPos12 = (texPos1 + offset12) / texSize;

    // 3x3 = 9 次 bilinear 采样
    float4 result = float4(0.0);
    result += tex.sample(s, float2(texPos0.x,  texPos0.y))  * w0.x  * w0.y;
    result += tex.sample(s, float2(texPos12.x, texPos0.y))  * w12.x * w0.y;
    result += tex.sample(s, float2(texPos3.x,  texPos0.y))  * w3.x  * w0.y;
    result += tex.sample(s, float2(texPos0.x,  texPos12.y)) * w0.x  * w12.y;
    result += tex.sample(s, float2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += tex.sample(s, float2(texPos3.x,  texPos12.y)) * w3.x  * w12.y;
    result += tex.sample(s, float2(texPos0.x,  texPos3.y))  * w0.x  * w3.y;
    result += tex.sample(s, float2(texPos12.x, texPos3.y))  * w12.x * w3.y;
    result += tex.sample(s, float2(texPos3.x,  texPos3.y))  * w3.x  * w3.y;
    return result;
}
```

**应用策略**：
- Y 通道：`sampleBicubicCatmullRom(textureY, s, uv, uniforms.textureSizeY).r`
- UV 通道：保持 `textureUV.sample(s, uv).rg`（半分辨率色度，bilinear 足够）

### 22.5 CAS 自适应锐化算法

**原理**：AMD FidelityFX CAS 通过分析 3x3 邻域的亮度对比度，自适应调节锐化强度 — 平坦区域锐化增强细节，边缘区域降低锐化避免光晕/振铃。

```metal
// [satisfies] AC-160, AC-161
float3 contrastAdaptiveSharpening(float3 center, texture2d<float> tex, sampler s,
                                   float2 uv, float2 texSize, float strength) {
    if (strength <= 0.0) return center;

    float2 px = 1.0 / texSize;

    // 采样十字邻域（4 taps，对角由 center 替代）
    float3 b = tex.sample(s, uv + float2( 0, -1) * px).rgb;
    float3 d = tex.sample(s, uv + float2(-1,  0) * px).rgb;
    float3 f = tex.sample(s, uv + float2( 1,  0) * px).rgb;
    float3 h = tex.sample(s, uv + float2( 0,  1) * px).rgb;

    // 采样对角邻域（4 taps）
    float3 a = tex.sample(s, uv + float2(-1, -1) * px).rgb;
    float3 c = tex.sample(s, uv + float2( 1, -1) * px).rgb;
    float3 g = tex.sample(s, uv + float2(-1,  1) * px).rgb;
    float3 i = tex.sample(s, uv + float2( 1,  1) * px).rgb;

    // BT.709 亮度
    float3 lw = float3(0.2126, 0.7152, 0.0722);
    float lb = dot(b, lw), ld = dot(d, lw), le = dot(center, lw);
    float lf = dot(f, lw), lh = dot(h, lw);
    float la = dot(a, lw), lc = dot(c, lw), lg = dot(g, lw), li = dot(i, lw);

    // 软 min/max
    float mnC = min(min(lb, min(ld, lf)), min(lh, le));
    float mxC = max(max(lb, max(ld, lf)), max(lh, le));
    float mn = 0.5 * (mnC + min(mnC, min(min(la, lc), min(lg, li))));
    float mx = 0.5 * (mxC + max(mxC, max(max(la, lc), max(lg, li))));

    float amp = saturate(min(mn, 1.0 - mx) / max(mx, 1e-5));
    amp = sqrt(amp);

    float peak = -1.0 / mix(8.0, 5.0, saturate(strength));
    float w = amp * peak;

    return saturate((b * w + d * w + f * w + h * w + center) / (1.0 + 4.0 * w));
}
```

**注意**：CAS 在 YUV→RGB 转换**之后**应用（操作 RGB 域），因此需要在已转换的 RGB 值上执行。对 HDR 路径，CAS 应在 tone mapping 之后、最终输出之前执行。

### 22.6 去色带 + 有序抖动

**去色带原理**：检测低频区域（相邻像素差值低于阈值），用随机邻域平均值平滑，消除压缩色带。

**有序抖动原理**：使用 Bayer 4x4 矩阵在量化级别之间添加结构化噪声，在 8-bit 输出时掩盖残余色带。

```metal
// [satisfies] AC-162, AC-163
// Bayer 4x4 有序抖动矩阵
constant float bayer4x4[16] = {
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
};

float3 deband(float3 color, texture2d<float> tex, sampler s,
              float2 uv, float2 texSize, float2 screenPos,
              float threshold, float grain) {
    float2 px = 1.0 / texSize;
    float seed = fract(uv.x * 1337.0 + uv.y * 7.13);

    // 随机方向 4-tap 采样
    float angle = fract(sin(dot(uv * texSize + seed, float2(12.9898, 78.233))) * 43758.5453)
                  * 2.0 * M_PI_F;
    float dist = fract(sin(dot(uv * texSize + seed, float2(39.346, 11.135))) * 43758.5453)
                 * 16.0;  // 16 pixel 采样半径
    float2 offset = float2(cos(angle), sin(angle)) * dist * px;

    float3 s0 = tex.sample(s, uv + offset).rgb;
    float3 s1 = tex.sample(s, uv - offset).rgb;
    float3 s2 = tex.sample(s, uv + float2(offset.y, -offset.x)).rgb;
    float3 s3 = tex.sample(s, uv + float2(-offset.y, offset.x)).rgb;
    float3 avg = (s0 + s1 + s2 + s3) * 0.25;

    float diff = max(abs(color.r - avg.r), max(abs(color.g - avg.g), abs(color.b - avg.b)));
    if (diff < threshold) {
        color = mix(color, avg, 0.5);
    }

    // Bayer 抖动
    int2 pos = int2(screenPos) % 4;
    float dither = bayer4x4[pos.y * 4 + pos.x] - 0.5;
    color += dither * grain;

    return color;
}
```

**注意**：去色带需要访问 RGB 纹理（转换后值），因此**不能**直接在 YUV 采样阶段使用。在 CAS 之后、`return` 之前执行。对 HDR（EDR > 1.0）路径，抖动幅度需缩放以匹配更大的值域。

### 22.7 预设→渲染参数映射

```
[satisfies] AC-164, AC-165

┌─────────────────────────────────────────────────────────────┐
│                    VideoPreset 枚举                          │
├─────────────┬──────────────┬──────────────┬─────────────────┤
│ 参数         │ Performance  │ Default      │ High Quality    │
├─────────────┼──────────────┼──────────────┼─────────────────┤
│ upscaleFilter│ 0 (bilinear) │ 1 (bicubic)  │ 1 (bicubic)     │
│ casStrength  │ 0.0 (off)    │ 0.5          │ 0.7             │
│ debandEnabled│ 0 (off)      │ 1 (on)       │ 1 (on)          │
│ debandThresh │ —            │ 0.004        │ 0.004           │
│ debandGrain  │ —            │ 0.002        │ 0.004           │
└─────────────┴──────────────┴──────────────┴─────────────────┘
```

**集成点**：`StreamingViewModel.setVideoPreset()` 现有 TODO 标记处，调用 `MetalVideoRenderer` 新增的配置方法：

```swift
// MetalVideoRenderer 新增方法
func setFilterConfig(_ config: VideoFilterConfig)

struct VideoFilterConfig {
    var upscaleFilter: UInt32 = 1      // bicubic
    var casStrength: Float = 0.5
    var debandEnabled: Bool = true
    var debandThreshold: Float = 0.004
    var debandGrain: Float = 0.003
}
```

### 22.8 渲染诊断指标

```
[satisfies] AC-166

新增到 StreamStatistics:
├── renderDeltaMs: Double        // GPU command buffer 完成耗时
├── frameDropCount: UInt64       // 丢帧计数（frame 到达时上一帧未渲染完）
├── frameRepeatCount: UInt64     // 重复帧计数（draw 时无新帧）
├── presentInterval: Double      // 相邻 present 间隔 (ms)
└── currentFilter: String        // 当前上采样滤波器标识
```

**展示位置**：StreamingOverlay 统计面板现有指标行下方新增一行：
`Filter: bicubic | Render: 0.8ms | Drop: 0 | Repeat: 2 | PresentΔ: 16.7ms`

### 22.9 Shader 集成策略

**核心原则**：所有新增滤波逻辑内联到现有 `videoBiplanarFragmentShader`，通过 uniform 条件分支控制。不新增 render pass 或 pipeline state。

```metal
fragment float4 videoBiplanarFragmentShader(...) {
    // Step 1: 上采样（替换原有 bilinear 采样）
    float y, float2 uv;
    if (uniforms.upscaleFilter == 1u) {
        y = sampleBicubicCatmullRom(textureY, s, in.texCoord, uniforms.textureSizeY).r;
    } else if (uniforms.upscaleFilter == 2u) {
        y = sampleLanczos2(textureY, s, in.texCoord, uniforms.textureSizeY).r;
    } else {
        y = textureY.sample(s, in.texCoord).r;
    }
    uv = textureUV.sample(s, in.texCoord).rg;  // UV 始终 bilinear

    // Step 2: YUV→RGB + HDR（现有逻辑不变）
    ...

    // Step 3: CAS 锐化（RGB 域，tone mapping 之后）
    if (uniforms.casStrength > 0.0) {
        rgb = contrastAdaptiveSharpening(rgb, ...);
    }

    // Step 4: 去色带 + 抖动（最后一步）
    if (uniforms.debandEnabled != 0u) {
        rgb = deband(rgb, ...);
    }

    return float4(rgb, 1.0);
}
```

**GPU 分支开销**：Metal 在 fragment shader 中的 uniform 条件分支成本极低（全 wavefront 走同一分支），不会造成 divergence。

### 22.10 HDR 路径兼容性

[satisfies] AC-169

| 阶段 | SDR (BT.709) | HDR (BT.2020 PQ) |
|------|-------------|-------------------|
| Bicubic 上采样 | Y 通道 9-tap | Y 通道 9-tap（10-bit r16Unorm） |
| CAS 锐化 | RGB gamma 域 | RGB 线性域（EDR/ACES 之后） |
| 去色带阈值 | 0.004 | 需缩放（EDR 值域更大） |
| Bayer 抖动 | grain / 255 | grain * edrHeadroom（匹配 EDR 值域） |

**HDR 特殊处理**：去色带的 `threshold` 和 `grain` 在 HDR 路径需乘以 `edrHeadroom` 因子，以匹配 EDR 扩展值域（SDR 1.0 → EDR 可达 ~8.0）。

### 22.11 性能预算

| 阶段 | 采样数 | M1 预估 | A14 预估 |
|------|--------|---------|----------|
| Bicubic Y | 9 taps | 0.3ms | 0.5ms |
| Bilinear UV | 1 tap | 0.05ms | 0.08ms |
| YUV→RGB + HDR | ALU | 0.1ms | 0.15ms |
| CAS | 9 taps | 0.3ms | 0.5ms |
| 去色带+抖动 | 4 taps + ALU | 0.2ms | 0.3ms |
| **总计** | | **~1.0ms** | **~1.5ms** |

帧预算 16.6ms（60fps），余量充足。Performance 预设（纯 bilinear）退回到现有开销水平。

### 22.12 回归风险

| 风险 | 影响范围 | 缓解措施 |
|------|---------|---------|
| Uniform struct 大小变更 | 所有 pipeline state | 确保 16 字节对齐，验证 CPU/GPU struct 一致性 |
| Bicubic 在纹理边缘采样越界 | 画面边缘伪影 | Catmull-Rom 权重自然衰减 + clamp_to_edge |
| CAS 在 HDR 值域误锐化 | HDR 画面过锐 | CAS 在 tone mapping 之后执行（值域已归一化） |
| 去色带误平滑细节 | 画面丢失纹理 | 阈值默认保守（0.004），可关闭 |
| Performance 预设退化 | 用户期望不匹配 | Performance = 纯 bilinear，等同当前行为 |

---

*§22 新增 (2026-02-10): F-041 Metal 原生高质量视频滤波管线*

## §23. libplacebo 渲染后端集成 (F-042)

> **关联需求**: F-042 (AC-170 ~ AC-191)
> **来源洞察**: INS-088~INS-091
> **影响模块**: VideoRenderer, PlaceboVideoRenderer(新), StreamingViewModel, StreamSettings, 构建系统
> **关联功能**: F-026（VideoRenderer 协议）, F-041（降级为兼容模式）

### 23.1 动机与方案选择

**问题**: F-041 Metal 原生 shader 管线（Bicubic + CAS + Deband）已实现基础画质增强，但存在以下不足：
- 自维护 Metal shader 代码脆弱（BUG-020: `constant` vs `const` 导致黑屏）
- 缺少 libplacebo 的高级功能：EWA Lanczos 上采样、帧混合、HDR 动态色调映射、自定义 mpv .hook 着色器
- 画质仍不及 chiaki-ng 的 libplacebo 管线

**方案选择**:

| 方案 | 优势 | 劣势 | 决策 |
|------|------|------|------|
| 继续扩展 Metal 原生 shader | 零依赖、最小包体积 | 功能追赶 libplacebo 不现实，维护成本高 | ❌ 作为兼容模式保留 |
| libplacebo + MoltenVK (Phase 1) | 可立即开始、验证集成架构 | MoltenVK 翻译层 5-15% 开销、+10-15MB 包体积 | ✅ 初始路径 |
| libplacebo Metal 原生后端 (Phase 2) | 无翻译层、最优性能、直接 Metal API | 需要自行实现 ~3,170 行后端代码 | ✅ 迁移目标 |

**分阶段策略**:
- **Phase 1**: MoltenVK (Vulkan) 路径集成 libplacebo，验证完整渲染管线和集成架构
- **Phase 2**: 自研 libplacebo Metal 后端就绪后，替换 MoltenVK 层，对上层 API 透明

### 23.2 架构概述

```
┌─────────────────────────────────────────────────────────────────┐
│                    StreamingViewModel                            │
│  renderBackend: .metalNative / .libplacebo                      │
│  videoRenderer: any VideoRenderer                               │
└──────────┬──────────────────────────────┬───────────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────┐    ┌──────────────────────────────────────┐
│ MetalVideoRenderer  │    │      PlaceboVideoRenderer            │
│ (F-041 兼容模式)     │    │                                      │
│                     │    │  ┌─────────────────────────────────┐  │
│ • Bicubic + CAS     │    │  │     libplacebo (pl_renderer)    │  │
│ • Deband            │    │  │  • EWA Lanczos / Polar filters  │  │
│ • VideoFilterConfig │    │  │  • HDR tone mapping             │  │
│ • 零外部依赖        │    │  │  • Deband + dithering           │  │
└─────────────────────┘    │  │  • Custom mpv shaders           │  │
                           │  └───────────┬─────────────────────┘  │
                           │              │                        │
                           │  ┌───────────▼─────────────────────┐  │
                           │  │  Phase 1: MoltenVK (Vulkan)     │  │
                           │  │  Phase 2: Metal 原生后端         │  │
                           │  └─────────────────────────────────┘  │
                           └──────────────────────────────────────┘
```

**VideoRenderer 协议兼容性**: `PlaceboVideoRenderer` 实现现有 `VideoRenderer` 协议（F-026 定义），与 `MetalVideoRenderer` 完全并存。上层代码（StreamingViewModel、StreamStatsManager）通过协议接口操作，无需感知具体后端。

### 23.3 PlaceboVideoRenderer 设计

```swift
// PlaceboVideoRenderer.swift
import Foundation
import CoreVideo
import MetalKit

/// libplacebo 渲染后端实现
/// @requirement F-042
/// @satisfies AC-173, AC-174, AC-175, AC-176, AC-177
final class PlaceboVideoRenderer: NSObject, VideoRenderer, @unchecked Sendable {

    // MARK: - libplacebo 核心对象 (C interop)
    private var plLog: OpaquePointer?           // pl_log
    private var plVulkan: OpaquePointer?        // pl_vulkan (Phase 1) / pl_metal (Phase 2)
    private var plGpu: OpaquePointer?           // pl_gpu
    private var plRenderer: OpaquePointer?      // pl_renderer
    private var plSwapchain: OpaquePointer?     // pl_swapchain
    private var plCache: OpaquePointer?         // pl_cache (shader 缓存)

    // MARK: - VideoRenderer 协议属性
    weak var mtkView: MTKView?
    var displayMode: VideoDisplayMode = .normal
    var zoomFactor: Float = 1.0
    var vrrEnabled: Bool = false
    var hdrConfiguration: HDRConfiguration = .sdr
    var edrHeadroom: Float = 1.0
    var filterConfig: VideoFilterConfig { ... }
    // ... 完整协议实现

    // MARK: - libplacebo 渲染参数
    private var renderParams: PlaceboRenderParams = .default
    private var debandParams: PlaceboDebandParams = .default

    // MARK: - 初始化
    init?() {
        // 1. 创建 pl_log
        // 2. Phase 1: pl_vulkan_create() (MoltenVK)
        //    Phase 2: pl_metal_create() (原生后端)
        // 3. pl_renderer_create(plLog, plGpu)
        // 4. 加载 shader 缓存
    }

    // MARK: - 帧提交与渲染
    func submitFrame(_ pixelBuffer: CVPixelBuffer) {
        // CVPixelBuffer → IOSurface → pl_tex (零拷贝)
    }

    func render(to view: MTKView, descriptor: MTLRenderPassDescriptor?) {
        // 1. pl_swapchain_start_frame()
        // 2. 构建 pl_frame (source + target)
        // 3. pl_render_image(plRenderer, &sourceFrame, &targetFrame, &renderParams)
        // 4. pl_swapchain_swap_buffers()
    }
}
```

### 23.4 零拷贝纹理导入

**Phase 1 (MoltenVK) 路径**:

```
CVPixelBuffer
    │
    ▼
IOSurfaceRef (CVPixelBufferGetIOSurface)
    │
    ▼
VkImage (VK_EXT_metal_objects: vkUseIOSurfaceMVK 或 VkImportMetalIOSurfaceInfoEXT)
    │
    ▼
pl_tex (pl_vulkan_wrap)
    │
    ▼
pl_frame { .planes[0] = Y plane, .planes[1] = UV plane }
    │
    ▼
pl_render_image() → 完整渲染管线
    │
    ▼
pl_swapchain → CAMetalLayer drawable
```

**关键约束**:
- `VK_EXT_metal_objects` 扩展必须可用（MoltenVK 1.2+ 支持）
- NV12 (420YpCbCr8BiPlanarVideoRange) 和 P010 (420YpCbCr10BiPlanarVideoRange) 双格式支持
- IOSurface 引用计数管理：pl_tex 持有期间 IOSurface 不得释放

**Phase 2 (Metal 原生后端) 路径**:

```
CVPixelBuffer
    │
    ▼
IOSurfaceRef
    │
    ▼
MTLTexture (MTLDevice.makeTexture(descriptor:iosurface:plane:))
    │
    ▼
pl_tex (pl_metal_wrap: PL_HANDLE_MTL_TEX)
    │
    ▼
pl_render_image() → 完整渲染管线
```

Phase 2 消除 Vulkan 层，直接使用 Metal 纹理，减少一次格式转换。

### 23.5 渲染管线配置

libplacebo 渲染参数通过 `pl_render_params` 结构体配置：

```c
// 三级预设映射 (AC-181)
// Performance → pl_render_fast_params
struct pl_render_params fast = pl_render_fast_params;
// 禁用所有后处理，最低延迟

// Default → pl_render_default_params
struct pl_render_params default_p = pl_render_default_params;
default_p.deband_params = &pl_deband_default_params;  // AC-182

// High Quality → pl_render_high_quality_params
struct pl_render_params hq = pl_render_high_quality_params;
hq.deband_params = &pl_deband_default_params;          // AC-182
// ewa_lanczossharp 上采样由 hq_params 默认配置          // AC-183
```

**上采样算法对比**（libplacebo vs F-041 Metal 原生）:

| 特性 | F-041 Metal 原生 | libplacebo |
|------|-----------------|------------|
| 上采样 | Bicubic Catmull-Rom 9-tap | EWA Lanczos Sharp (极坐标滤波) |
| 下采样 | N/A | Hermite |
| 锐化 | CAS 9-tap | 内置于上采样滤波器 |
| 去色带 | 4-tap 随机邻域 + Bayer 4x4 | 梯度检测 + 自适应阈值 |
| HDR 色调映射 | 简单 Reinhard | 动态场景检测 + 峰值统计 |
| 帧混合 | 无 | Oversample / Mitchell-Clamp |
| 自定义着色器 | 无 | mpv .hook 格式 |
| 色域映射 | 无 | 感知色域拉伸 |

### 23.6 后端切换机制

```swift
// StreamSettings.swift (AC-178)
enum RenderBackend: String, Codable, CaseIterable {
    case metalNative    // F-041 Metal 原生 shader
    case libplacebo     // libplacebo 渲染管线

    var displayName: String {
        switch self {
        case .metalNative: return "Metal Native"
        case .libplacebo: return "libplacebo"
        }
    }
}

// StreamSettings 扩展
var renderBackend: RenderBackend = .libplacebo  // 默认 libplacebo
```

```swift
// StreamingViewModel.swift (AC-180)
private func createRenderer() -> (any VideoRenderer)? {
    switch settings.renderBackend {
    case .libplacebo:
        if let renderer = PlaceboVideoRenderer() {
            return renderer
        }
        // Graceful fallback (AC-185)
        Logger.video.warning("libplacebo init failed, falling back to Metal Native")
        return MetalVideoRenderer()
    case .metalNative:
        return MetalVideoRenderer()
    }
}
```

### 23.7 构建系统集成

**依赖链**:

```
libplacebo (LGPL 2.1, 动态 framework)
    ├── SPIRV-Cross (Apache 2.0, 静态链接到 libplacebo)
    ├── shaderc/glslang (BSD, GLSL→SPIR-V 编译)
    └── Phase 1: MoltenVK (Apache 2.0, 动态 framework)
        └── vulkan-headers (Apache 2.0)
```

**xcframework 结构** (AC-171):

```
Frameworks/
├── libplacebo.xcframework/
│   ├── macos-arm64_x86_64/libplacebo.framework/
│   └── ios-arm64/libplacebo.framework/
├── MoltenVK.xcframework/           (Phase 1 only)
│   ├── macos-arm64_x86_64/MoltenVK.framework/
│   └── ios-arm64/MoltenVK.framework/
└── (Phase 2: MoltenVK 移除)
```

**LGPL 合规** (AC-172):
- libplacebo 必须以动态 framework 链接（用户可替换）
- MoltenVK (Apache 2.0) 无限制
- 应用内提供 libplacebo 源码链接和许可证声明

**构建脚本**:
- 新增 `scripts/build-libplacebo.sh`：交叉编译 libplacebo + MoltenVK 为 xcframework
- Meson 交叉编译配置（macOS arm64/x86_64、iOS arm64）
- CI 集成：预编译 xcframework 缓存，避免每次构建

### 23.8 Swapchain 与 MTKView 集成

libplacebo 的 `pl_swapchain` 需要与现有 MTKView 渲染循环协作：

**Phase 1 (MoltenVK)**:
```
MTKView.delegate.draw(in:)
    │
    ▼
PlaceboVideoRenderer.render(to:descriptor:)
    │
    ├── pl_swapchain_start_frame() → 获取 target texture
    ├── 构建 pl_frame (source: Y+UV planes, target: swapchain frame)
    ├── pl_render_image(renderer, &source, &target, &params)
    └── pl_swapchain_swap_buffers()
```

**MoltenVK swapchain 与 CAMetalLayer**:
- `pl_vulkan_create_swapchain()` 接受 `VkSurfaceKHR`
- MoltenVK 通过 `VK_EXT_metal_surface` 从 CAMetalLayer 创建 VkSurfaceKHR
- MTKView 底层使用 CAMetalLayer，两者可共享

**替代方案**（若 swapchain 共享困难）:
- 使用 `pl_renderer` 离屏渲染到 `pl_tex`
- 将结果 `pl_tex` 对应的 MTLTexture 通过 `VK_EXT_metal_objects` 导出
- 用简单的 Metal blit pass 复制到 MTKView drawable
- 额外开销 ~0.1ms，但架构更简洁

### 23.9 HDR 支持

libplacebo 内置完整 HDR 管线 (AC-177):

```c
// 源帧色彩空间
struct pl_color_space src_csp = {
    .primaries = PL_COLOR_PRIM_BT_2020,
    .transfer = PL_COLOR_TRC_PQ,
    // HDR10 静态元数据
    .hdr = {
        .max_luma = 1000,  // 来自 PS5 流元数据
    },
};

// 目标色彩空间（自动检测显示器能力）
struct pl_color_space dst_csp = {
    .primaries = PL_COLOR_PRIM_BT_2020,  // EDR 扩展色域
    .transfer = PL_COLOR_TRC_LINEAR,      // EDR 线性光
};

// 渲染参数
render_params.color_map_params = &pl_color_map_default_params;
// 动态色调映射：自动场景检测 + 峰值统计
```

- EDR headroom 注入：`dst_csp.hdr.max_luma = edrHeadroom * 203.0`（203 nit = SDR 白点）
- SDR 路径：src/dst 均为 BT.709，libplacebo 自动跳过色调映射

### 23.10 Shader 缓存

libplacebo 首次使用某配置时需编译 shader（GLSL→SPIR-V→MSL），后续从缓存加载：

```swift
// 缓存路径: ~/Library/Caches/com.chiaki.app/placebo_cache.bin
private func setupShaderCache() {
    let cacheParams = pl_cache_params(
        log: plLog,
        max_total_size: 10 * 1024 * 1024  // 10 MB
    )
    plCache = pl_cache_create(&cacheParams)
    pl_gpu_set_cache(plGpu, plCache)

    // 加载已有缓存
    if let file = fopen(cacheFilePath, "rb") {
        pl_cache_load_file(plCache, file)
        fclose(file)
    }
}

// 应用退出时保存缓存
func saveCache() {
    if let file = fopen(cacheFilePath, "wb") {
        pl_cache_save_file(plCache, file)
        fclose(file)
    }
}
```

### 23.11 C/Swift 桥接

libplacebo 是纯 C 库，需要 Swift 桥接头：

```
Chiaki/
├── Core/
│   └── Video/
│       ├── VideoRenderer.swift          (协议，不变)
│       ├── MetalVideoRenderer.swift     (不变，兼容模式)
│       ├── PlaceboVideoRenderer.swift   (新增，Swift 主体)
│       └── Placebo/
│           ├── PlaceboBridge.h          (桥接头：#include <libplacebo/*.h>)
│           ├── PlaceboContext.m/.c       (C 层初始化/销毁封装)
│           └── PlaceboTypes.swift       (Swift 类型映射)
```

**桥接策略**:
- libplacebo C API 通过 Objective-C 桥接头暴露给 Swift
- 不透明指针（`OpaquePointer`）管理 libplacebo 对象生命周期
- 配置结构体通过 Swift wrapper 类型安全封装
- 渲染热路径（submitFrame/render）通过最小化桥接调用减少开销

### 23.12 诊断接口

PlaceboVideoRenderer 实现 StreamStatsManager 所需接口 (AC-186, AC-187):

```swift
// PlaceboVideoRenderer 统计属性
var frameCount: UInt64 { get }           // 渲染帧计数
var droppedFrameCount: UInt64 { get }    // 丢帧计数
var frameRepeatCount: UInt64 { get }     // 重复帧计数
var presentInterval: Double { get }      // 帧间间隔 (ms)
var filterName: String { "libplacebo" }  // 后端标识

// StreamingOverlay 显示当前后端名称
// 渲染诊断项增加 "Backend: libplacebo" 或 "Backend: Metal Native"
```

### 23.13 Phase 2: Metal 后端迁移路径

Metal 原生后端完成后，`PlaceboVideoRenderer` 内部切换 (AC-188, AC-189):

```swift
// Phase 1 → Phase 2 切换（对 VideoRenderer 协议透明）
private func initializeGpu() -> Bool {
    #if PLACEBO_METAL_BACKEND
    // Phase 2: 直接创建 Metal 上下文
    plMetal = pl_metal_create(plLog, &metalParams)
    plGpu = plMetal?.pointee.gpu
    #else
    // Phase 1: 通过 MoltenVK 创建 Vulkan 上下文
    plVulkan = pl_vulkan_create(plLog, &vulkanParams)
    plGpu = plVulkan?.pointee.gpu
    #endif
    return plGpu != nil
}
```

**迁移检查清单**:
- [ ] `pl_metal_create()` 替换 `pl_vulkan_create()`
- [ ] `pl_metal_wrap()` 替换 VK_EXT_metal_objects 纹理导入
- [ ] `CAMetalLayer` 直接创建 swapchain（无需 VkSurfaceKHR）
- [ ] 移除 MoltenVK.xcframework 依赖
- [ ] 编译标志 `PLACEBO_METAL_BACKEND` 控制切换

### 23.14 回归风险

| 风险 | 影响范围 | 缓解措施 |
|------|---------|---------|
| MoltenVK 在 iOS 上 Vulkan 能力不完整 | 部分 libplacebo shader 不可用 | 运行时检测 GPU 能力，降级配置 |
| libplacebo 动态 framework 签名 | App Store 提审 | 正确签名 + 嵌入 framework |
| Shader 首次编译延迟 | 首次串流启动慢 ~2-3s | Shader 缓存持久化 + 预热 |
| CVPixelBuffer → VkImage 零拷贝失败 | 帧延迟增加 | Fallback 到 CPU copy + 性能警告日志 |
| MetalVideoRenderer 回退路径未测试 | libplacebo 失败时黑屏 | 集成测试覆盖 fallback 路径 |
| 包体积增加 ~15-25MB (MoltenVK) | 用户下载体验 | Phase 2 消除 MoltenVK 后降至 ~5MB |
| libplacebo API 版本兼容性 | 升级 libplacebo 后编译失败 | 锁定 libplacebo 版本，CI 验证 |

---

*§23 新增 (2026-02-10): F-042 libplacebo 渲染后端集成*

