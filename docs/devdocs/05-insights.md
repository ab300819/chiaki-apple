# 洞察收集

> **状态更新**: 2026-02-10
> **已归档洞察**: [archive/05-insights-archive.md](archive/05-insights-archive.md) (INS-001 ~ INS-076, 共 76 条)

---

## 已归档洞察摘要

> 以下洞察已转化为需求并完成实现，详情见 [归档文件](archive/05-insights-archive.md)

| 范围 | 编号 | 转化目标 | 状态 |
|------|------|----------|------|
| SwiftUI 架构 | INS-001 ~ INS-005 | F-010 ~ F-014 | ✅ 已完成 |
| Phase 11 生产就绪 | INS-006 ~ INS-010 | F-015 ~ F-018 | ✅ 已完成 |
| 日志系统 | INS-011 ~ INS-016 | F-019 | ✅ 已完成 |
| 手柄操作 | INS-017 ~ INS-022 | F-020 | ✅ 已完成 |
| GC 框架评估 | INS-023 ~ INS-026 | F-021 | ✅ 已完成 |
| StreamingOverlay | INS-027 | T-135 | ✅ 已完成 |
| 手柄 UI/UX | INS-028 ~ INS-031 | F-022 | ✅ 已完成 |
| HDR 配置审查 | INS-032 ~ INS-033 | F-024 | ✅ 已完成 |
| HDR 渲染管线 | INS-034 ~ INS-038 | F-025 | ✅ 已完成 |
| 渲染模块封装 | INS-039 ~ INS-041 | F-026 | ✅ 已完成 |
| UI 层架构 | INS-042 ~ INS-046 | F-027 | ✅ 已完成 |
| REVIEW_SUMMARY | INS-048 ~ INS-051 | F-028 ~ F-030 | ✅ 已完成 |
| macOS 设置布局 | INS-052 | F-034 | ✅ 已完成 |
| Slider 布局审查 | INS-053 ~ INS-055 | F-035 | ✅ 已完成 |
| HostListView 审查 | INS-056 ~ INS-059 | F-036 | ✅ 已完成 |
| AddHostView 审查 | INS-062 ~ INS-067 | F-037 | ✅ 已完成 |
| ConsolePinView 审查 | INS-068 ~ INS-071 | F-037 | ✅ 已完成 |
| Bridge 安全审查 | INS-072 ~ INS-076 | F-038 | ✅ 已完成 |

---

## 暂缓洞察

### INS-047: 解码重排策略优化 ⏸️

- **收集时间**: 2026-02-04
- **来源**: 💡 REVIEW_SUMMARY 高优先级建议
- **现状**: `VideoToolboxDecoder` 使用固定 4 帧重排缓冲，永远等满再输出
- **建议**: 改为动态策略：仅在检测到乱序/B 帧时缓冲，或根据 codec/profile 动态设置
- **影响范围**: VideoToolboxDecoder、视频延迟体验
- **暂缓原因**: 修改重排策略风险较高，当前固定策略虽有延迟但稳定性好

---

## 活跃洞察

### INS-077: iPhone 串流横屏锁定 ✅ 已完成

- **收集时间**: 2026-02-09
- **来源**: 🔍 外部参考 (PS Remote Play / Steam Link / Moonlight 竞品分析) + 💡 内部反馈
- **优先级**: P1
- **现状**: StreamingView 无运行时方向锁定，iPhone 竖屏时体验差
- **建议**: 串流画面默认锁定横屏（Landscape Left/Right），退出恢复
- **参考**: Steam Link / Moonlight 均为纯横屏；PS Remote Play 支持竖屏但默认横屏
- **状态**: ✅ 已完成 → F-039 (US-039, AC-148~AC-150) — M16 T-221/T-222 已合入

### INS-078: 控制器输入层分离（Input Provider 协议） ✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈 (BUG-018/019 修复暴露架构问题)
- **参考**: chiaki-ng SDL controllermanager.cpp 分层设计
- **优先级**: P1
- **现状**: ControllerManager 800+ 行单体类，混合输入读取、设备管理、反馈输出
- **建议**: 定义 `ControllerInputProvider` 协议，每种输入源独立实现。ControllerManager 降级为设备编排器
- **影响范围**: ControllerManager、DualSenseHIDManager、VirtualControllerInput、StreamingViewModel
- **状态**: ✅ 已完成 → F-040 (M17 全部完成)

### INS-079: HID 优先、GameController Fallback 策略 ✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 💡 BUG-018/019 根因分析 + 🔍 chiaki-ng SDL/HIDAPI 参考
- **参考**: DualSense HID 协议; chiaki-ng SDL 优先策略
- **优先级**: P1
- **现状**: GameController 作为主通道，HID 仅 macOS 补丁。PS button/rumble 在 macOS BT 下 GameController 不工作
- **建议**: 对已知 VID/PID 手柄优先使用 IOKit HID Provider，GameController 作为通用 fallback，两者非排他共存
- **影响范围**: ControllerManager、DualSenseHIDManager、设备检测逻辑
- **状态**: ✅ 已完成 → F-040 (M17 全部完成)

### INS-080: Rumble/Feedback 输出统一封装 ✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈 (rumble 4 层 fallback 散布各处)
- **参考**: chiaki-ng `SDL_GameControllerRumble()` 统一入口
- **优先级**: P1
- **现状**: rumble 路径: macOS HID → GCDeviceHaptics → CoreHaptics → HapticsManager，4 种路径分布在多个文件
- **建议**: 定义 `ControllerFeedbackOutput` 协议，每个 Provider 实现自己的反馈输出，Orchestrator 路由
- **影响范围**: ControllerManager.applyRumble()、DualSenseHIDManager、HapticsManager
- **状态**: ✅ 已完成 → F-040 (M17 全部完成)

### INS-081: 扩展 HID 支持到 DualShock 4 ✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 🔍 chiaki-ng 支持 DS4 + DualSense HID 模式
- **参考**: DualShock 4 HID 协议, VID 0x054C / PID 0x05C4 (v1), 0x09CC (v2)
- **优先级**: P2
- **现状**: 仅支持 DualSense HID，DualShock 4 在 macOS 同样存在 GameController 限制
- **建议**: 在 Provider 架构基础上新增 DualShock4HIDProvider，只需实现不同的 HID 报文格式
- **影响范围**: 新文件 DualShock4HIDManager.swift
- **状态**: ✅ 已完成 → F-040 (M17 全部完成)

---

## 待定洞察

### INS-060: 空状态视图动画 ⏳

- **收集时间**: 2026-02-06
- **来源**: 🎨 UI/UX 审查
- **优先级**: P3
- **建议**: 为主机列表空状态添加引导动画

### INS-061: 批量删除确认信息 ⏳

- **收集时间**: 2026-02-06
- **来源**: 🎨 UI/UX 审查
- **优先级**: P3
- **建议**: 批量删除主机时显示确认对话框和删除数量

### INS-082: Metal 原生高质量滤波管线（上采样 + 锐化 + 去色带）✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 📄 文档调研 + 🔍 外部参考（chiaki-ng/libplacebo） + 🔬 深度技术调研
- **参考**:
  - `chiaki-ng/gui/src/qmlmainwindow.cpp`（libplacebo 渲染管线：EWA Lanczos Sharp 上采样）
  - `chiaki-ng/gui/src/qml/PlaceboSettingsDialog.qml`（滤波器/去色带/Sigmoid 配置）
  - MJP Catmull-Rom 9-tap 优化算法（利用硬件双线性合并相邻 tap）
  - AMD FidelityFX CAS（对比度自适应锐化，3x3 邻域 9 taps）
  - mpv deband shader（随机邻域采样 + 阈值平滑 + 有序抖动）
- **根因分析**:
  - BUG-016（运动模糊）残留根因：`VideoShaders.txt` 全部采样器仅 `mag_filter::linear, min_filter::linear`，720p/1080p 放大到 Retina 时双线性插值丢失细节
  - BUG-017（窗口最大化模糊）残留根因：双线性采样在高 DPI 放大场景下画质不足
  - chiaki-ng 使用 `ewa_lanczossharp` 上采样 + `hermite` 下采样 + 去色带 + Sigmoid，画质差距极大
- **方案评估**:
  - ⏸️ libplacebo + MoltenVK：技术可行（MoltenVK 支持 iOS/tvOS，VK_EXT_metal_objects 支持零拷贝），但 LGPL 2.1 许可证对 App Store 定价分发有合规风险，无 iOS 构建先例。详见 INS-085
  - ⏸️ libplacebo Metal 后端：正在适配中，若完成可消除 MoltenVK 依赖和许可证问题。详见 INS-085
  - ❌ MetalFX Spatial Scaler：需额外 render pass（YUV→RGB→scale→输出）、操作 RGB 不支持 YUV
  - ✅ **Metal 原生 shader 实现**（短期方案）：零外部依赖、全平台统一、单次 fragment shader 内完成、保持零拷贝
- **确认方案**: Metal 原生实现三级滤波管线：
  1. **Bicubic Catmull-Rom 上采样**（Y 通道 9-tap，利用硬件双线性优化；UV 保持 bilinear）
  2. **CAS 自适应锐化**（9 taps，自动降低高对比度区域锐化强度，避免光晕）
  3. **去色带 + 有序抖动**（4 taps 随机邻域 + Bayer 4x4 抖动矩阵）
- **性能预算** (1080p→4K, 60fps, M1): 全管线 ~1.0ms，帧预算 16.6ms 余量充足
- **长期演进**: F-041 Metal 原生 shader 为短期方案；libplacebo Metal 后端就绪后（见 INS-085），可获得 EWA Lanczos、帧混合、HDR 峰值检测等完整画质能力。届时 F-041 保留为轻量/兼容模式
- **影响范围**: `VideoShaders.txt`（新增滤波函数）, `MetalVideoRenderer.swift`（扩展 VideoUniforms）, `StreamSettings.swift`, `VideoSettingsView.swift`
- **优先级**: P0
- **关联 Bug**: BUG-016, BUG-017
- **状态**: ✅ 已完成 → F-041 (M18 全部完成)

### INS-083: 视频预设接入真实渲染参数（补齐预设能力）✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈（体验与设置不一致） + 📄 代码审查 + 🔬 深度技术调研
- **参考**:
  - `Chiaki/Features/Streaming/StreamingViewModel.swift`（`setVideoPreset` 存在 TODO）
  - `chiaki-ng/gui/src/qmlmainwindow.cpp`（`pl_render_fast_params` / `pl_render_default_params` / `pl_render_high_quality_params`）
  - `chiaki-ng/gui/src/qml/PlaceboSettingsDialog.qml`（自定义参数面板）
- **现状**: `VideoPreset` 仅更新状态和日志，未真正作用于渲染参数，用户无法通过预设改善画质
- **确认方案**: 建立三级预设→渲染参数映射：
  - **Performance**: bilinear 上采样，无锐化，无去色带（最低 GPU 开销）
  - **Default**: bicubic Catmull-Rom 上采样，CAS 锐化 0.5，去色带开启（平衡画质/性能）
  - **High Quality**: bicubic 上采样，CAS 锐化 0.7，去色带 + 抖动（最佳画质）
- **影响范围**: `StreamingViewModel.swift`, `MetalVideoRenderer.swift`, `SettingsStore.swift`
- **优先级**: P1
- **状态**: ✅ 已完成 → F-041 (M18 全部完成)

### INS-084: 渲染时序诊断指标（辅助画质调优）✅ 已完成

- **收集时间**: 2026-02-10
- **来源**: 📄 文档调研 + 🔍 外部参考（chiaki-ng frame mixing） + 🔬 深度技术调研
- **参考**:
  - `chiaki-ng/gui/src/qmlmainwindow.cpp`（`pl_render_image_mix`、timeline semaphore 同步）
  - MetalFX Frame Interpolation（WWDC25，需两帧输入，增加延迟，远期评估）
- **调研结论**:
  - 帧混合（frame mixing）在串流场景增加延迟（需缓存前帧），不适合低延迟优先的远程串流
  - chiaki-ng 帧混合默认 oversample，但其桌面场景延迟容忍度更高
  - **渲染时序诊断**对定位画质问题有直接价值，应优先实现
- **确认方案**: 在 StreamingOverlay 统计面板补充渲染管线诊断指标：
  - render delta（渲染命令耗时 ms）
  - frame drop/repeat 计数
  - present interval（帧间展示间隔）
  - upscale filter 类型标识
- **帧混合暂缓**: MetalFX Frame Interpolation 作为远期技术储备（P3），当前不实现
- **影响范围**: `StreamStatistics.swift`, `StreamingOverlay.swift`, `MetalVideoRenderer.swift`
- **优先级**: P1
- **状态**: ✅ 已完成 → F-041 (M18 全部完成)

### INS-085: libplacebo Metal 原生渲染后端集成 ✅ 已确认（路径 B 可行，分阶段推进）

- **收集时间**: 2026-02-10
- **来源**: 📄 技术可行性调研 + 🔬 深度技术调研 + 💡 项目规划反馈 + 📊 **三方独立技术评估**
- **参考**:
  - https://github.com/haasn/libplacebo
  - https://github.com/KhronosGroup/MoltenVK
  - chiaki-ng MoltenVK macOS 集成（`VK_EXT_METAL_SURFACE_EXTENSION_NAME`）
  - libplacebo GitLab Issue #124（LGPL → BSD/MIT 重新许可讨论）
  - MoltenVK `VK_EXT_metal_objects`（CVPixelBuffer → IOSurface → VkImage 零拷贝）
  - **`metal-backend-claude.md`** — 完整实现方案（metal-cpp、vtable 实现、编译管线、测试策略，最详尽）
  - **`metal-backend-gemini.md`** — 精简设计方案（核心策略、Argument Buffers、4 阶段路线）
  - **`metal-backend-gpt.md`** — 结构化评估（最小改动原则、分阶段计划、风险缓解、验收标准）
- **项目背景**:
  - 本项目计划上架 App Store 并定价，同时开源
  - App Store 定价分发 + LGPL 2.1 存在合规灰色地带
  - 项目维护者正在**适配 libplacebo Metal 原生渲染后端**
- **三方评估结论（路径 B 已确认可行）**:
  - ✅ **三份独立研报一致确认**：libplacebo Metal 原生后端技术可行
  - ✅ **着色器编译路径成熟**：GLSL → SPIR-V → MSL（SPIRV-Cross）→ MTLLibrary，D3D11 后端已验证同类路径
  - ✅ **改动范围极小**：仅需修改 2 个现有文件（`meson_options.txt` + `src/meson.build`），高层渲染链（renderer/dispatch/shaders）**零改动**
  - ✅ **代码量可控**：~3,170 行新代码，比 D3D11 后端（~5,000 行）少 37%
  - ✅ **测试几乎免费**：复用共享 GPU 测试 ~1,763 行，仅需新增 ~120 行 Metal 特定测试
  - ✅ **实现框架明确**：Apple 官方 `metal-cpp`（C++ header-only、零开销、跨平台统一）
  - ✅ **消除 MoltenVK**：直接调用 Metal API，无翻译层，无 ~10-15MB 包体积增加
  - ✅ **全平台统一**：iOS/macOS/tvOS 使用相同 metal-cpp 头文件
- **工期估算**（综合三份研报）:
  - **Phase A — 构建骨架**: ~1 周（meson 接入、API 头、stubs 编译通过）
  - **Phase B — 离屏 MVP**: 3-4 周（纹理/缓冲/pass 闭环，通过基础 GPU 测试）
  - **Phase C — 功能补齐**: 3-5 周（compute、swapchain、互操作、着色器缓存）
  - **Phase D — 稳定性优化**: 2-3 周（性能对比、输出一致性、CI 集成）
  - **总计**: 约 10-14 周 MVP 可用，16-20 周生产就绪
- **核心技术要点**:
  - `pl_gpu_fns` vtable 实现（~22 个函数：tex/buf/pass/timer/sync）
  - SPIRV-Cross `SPVC_BACKEND_MSL` 替代 D3D11 的 `SPVC_BACKEND_HLSL`（仅一行核心差异）
  - `MTL::Device` + `MTL::CommandQueue` → `pl_gpu` 映射
  - `CA::MetalLayer` → `pl_swapchain` 映射
  - IOSurface 互操作（`PL_HANDLE_MTL_TEX` / `PL_HANDLE_IOSURFACE` 公共 API 已预留）
  - `setBytes:length:atIndex:` 替代 push constants（≤4KB 限制）
  - Metal 2.0+（macOS 10.13+）基线，GPU Family 动态能力检测
- **许可证分析**（不变）:
  - libplacebo: LGPL 2.1（维护者有意重新许可为 BSD/MIT，但至今未完成）
  - Metal 后端消除 MoltenVK（Apache 2.0），许可证问题仅剩 libplacebo 自身 LGPL
  - 本项目开源：LGPL 代码可链接，但 App Store 定价分发需用户可替换 LGPL 组件
  - 动态 framework 分发是合规路径（VLC 已在 iOS App Store 采用此模式）
  - 若 libplacebo 完成重新许可 → 许可证阻塞完全消除
- **路径选择（更新）**:
  - ~~路径 A — libplacebo + MoltenVK~~：不再推荐，路径 B 全面优于路径 A
  - **路径 B — libplacebo Metal 后端**：✅ 三方确认可行，正在实现
- **阶段策略（更新 2026-02-10）**:
  - **Phase 1（当前）**: 先用 MoltenVK 路径集成 libplacebo，验证集成架构和画质效果（INS-088/089）
  - **Phase 2**: libplacebo Metal 原生后端完成后，替换 MoltenVK 层，消除翻译开销
  - **Phase 3**: libplacebo 后端作为默认高画质渲染路径，F-041 Metal 原生 shader 保留为轻量/兼容模式（INS-090）
  - **上游贡献**: Metal 后端完成后提交 upstream PR（INS-091）
- **集成到本项目的预期工作**:
  - 新增 `PlaceboVideoRenderer.swift` 实现 `VideoRenderer` 协议
  - 通过 `pl_metal_create()` 初始化 libplacebo Metal 上下文
  - CVPixelBuffer → IOSurface → `pl_metal_wrap()` 零拷贝纹理导入
  - `pl_render_image()` 全套渲染管线（上采样/去色带/色调映射/帧混合）
  - 设置页新增渲染后端切换（Metal Native / libplacebo）
- **影响范围**: `VideoRenderer.swift`（协议已预留后端扩展点）, 新增 `PlaceboVideoRenderer` 模块
- **优先级**: P2（路径 B 实现完成后升级为 P1）
- **状态**: ✅ 已确认（路径 B 技术可行性三方独立验证通过，待 Metal 后端实现就绪后集成）

### INS-086: App Store 付费分发许可证合规性分析 ⏸️ 暂缓

- **收集时间**: 2026-02-10
- **来源**: 📄 许可证调研 + 🔬 深度法律/技术分析
- **参考**:
  - chiaki-ng `COPYING`（AGPL-3.0 + OpenSSL 链接例外）
  - 原 chiaki 项目（thestr4ng3r, AGPL-3.0）
  - FSF App Store GPL 执法声明 (2010-2011)
  - VLC iOS 重新许可案例（GPL→LGPL, 2011-2013, 联系 230+ 贡献者）
  - GNU Go App Store 下架事件 (2010)
  - SFC v. Vizio (2021-至今，第三方受益人起诉 GPL 违规)
  - Steck v. AVM (2023-2024，个人开发者成功起诉 LGPL 违规)
  - GPL Cooperation Commitment（首次违规 30 天修正期）
  - libplacebo README（维护者公开邀请 BSD-2 重新许可）
- **项目背景**:
  - 本项目计划上架 App Store 并定价，同时保持开源
  - 当前使用 chiaki-ng 作为 git submodule，编译为 `libchiaki.xcframework`（静态链接）
  - 静态链接 AGPL 代码 = 整个 app 成为 AGPL 衍生作品
- **许可证全景**:
  - 🔴 **chiaki-ng (libchiaki)**: AGPL-3.0 — **致命阻塞**，与 App Store 不兼容
  - 🟡 **libplacebo** (待集成): LGPL-2.1+ — 灰色地带，有成熟先例（VLC 模式）
  - 🟢 opus/mbedtls/miniupnpc/json-c/curl/jerasure/nanopb: BSD/MIT/Apache/zlib — 无障碍
- **AGPL-3.0 与 App Store 的致命冲突**:
  - §6 反 Tivoization：必须提供「安装信息」让用户安装修改版 → iOS 代码签名使此不可能
  - §10 禁止额外限制：App Store ToS 施加 DRM/使用限制/禁止再分发 → 直接冲突
  - §12 不可同时满足：无法同时遵守 AGPL 和 App Store ToS → 禁止通过 App Store 分发
  - **结论：AGPL-3.0 软件无法合法通过 App Store 分发，这不是灰色地带**
- **libplacebo LGPL-2.1+ 的合规路径**（次要问题，有成熟方案）:
  - ✅ 动态 Framework 方案（VLC 模式）：Infuse、Plex、VLC 等付费/免费 app 已长期采用
  - ✅ 项目开源自动满足源码公开要求
  - ✅ 维护者公开邀请 BSD-2 重新许可（README 原文："if a use case emerges"）
  - ℹ️ LGPL 2.1（非 3.0）无反 Tivoization 条款，对 iOS 更友好
  - ℹ️ 零起诉先例：从未有人因 iOS App Store 上的 LGPL 使用发起诉讼
- **可行路径评估**:
  - **路径 1 — 获取 AGPL 例外**：联系 streetpea + thestr4ng3r 添加 App Store 分发例外（§7 附加许可）。最少工作量但成功率不确定
  - **路径 2 — Swift 重写 libchiaki**：消除 AGPL 依赖，获得完全版权自由。详见 INS-087
  - **路径 3 — 仅开源分发**：GitHub + TestFlight + AltStore，无 App Store 付费变现
  - **路径 4 — 双轨策略**：开源版 AGPL（GitHub），App Store 版使用自有 Swift 实现
- **推荐执行顺序**:
  1. **立即**：尝试路径 1 — 联系 chiaki-ng 版权持有人获取 App Store 例外
  2. **并行**：评估路径 2 — Swift 重写可行性（见 INS-087）
  3. **兜底**：路径 4 双轨策略
- **影响范围**: 项目整体分发策略、许可证选择、libchiaki 依赖方式
- **优先级**: P1（决定项目商业化可行性）
- **状态**: ⏸️ 暂缓（待联系 chiaki-ng 版权持有人确认路径 1 可行性）

### INS-087: libchiaki Swift 原生重写可行性评估 ⏸️ 暂缓

- **收集时间**: 2026-02-10
- **来源**: 🔬 深度技术调研 + 📄 源码分析 + 🔍 协议文档调研
- **参考**:
  - `chiaki-ng/lib/`（28,576 行 C，90 个文件，46 公开头文件）
  - `Chiaki/Core/Bridge/`（6 个桥接文件，~30 个 C 函数调用，7 条回调路径）
  - PS Remote Play 协议公开文档调研（IEEE 论文、psdevwiki、PSXHAX 论坛）
  - RemotePlayPrototype (grill2010, C#) — 唯一已知的非 chiaki 实现
  - Oracle v. Google (2021 最高法院) — API 重新实现与合理使用
  - IBM PC BIOS Clean-Room 先例 — Chinese Wall 方法
- **动机**: 消除 AGPL-3.0 许可证阻塞（INS-086），获得完全版权自由以支持 App Store 付费分发
- **libchiaki 模块分析（28,576 行）**:
  - Holepunch (PSN NAT 穿透): 5,599 行 — 最复杂模块
  - RPCrypt (加密): 2,428 行 — 含硬编码密钥推导常量表
  - Takion (UDP 传输): 1,717 行 — 核心数据面协议
  - Ctrl (TCP 控制通道): 1,425 行 — 会话管理/心跳
  - StreamConnection (流连接): 1,281 行 — ECDH + Protobuf 握手
  - Session (会话编排): 1,170 行 — 顶层生命周期管理
  - Senkusha (连接探测): 962 行 — MTU/RTT
  - 其他 (发现/注册/FEC/反馈/工具): ~14,000 行
- **Clean-Room 可行性结论**: ❌ **纯 Clean-Room 不可行**
  - 无独立协议规范（Sony 从未发布，无 RFC/白皮书）
  - 加密常量（RPCrypt 密钥表 3,584 字节）仅存在于源码中
  - Protobuf schema 从 Sony 二进制文件（libremote.so）提取，未独立发布
  - PS4 FW 8/9/10 + PS5 协议变体（Takion v7/v9/v12）仅在源码中区分
  - PSN Holepunch（OAuth2 scope/WebSocket 信令/RUDP）完全未文档化
  - 全球范围内所有已知实现均源自同一逆向工程知识树
- **Swift 重写技术评估**:
  - 预估代码量: ~20,000-25,000 行 Swift（C 代码行数的 70-85%）
  - 预估工期: 20-29 周（7 个阶段）
    - P1 基础层（发现+注册）: 2-3 周
    - P2 会话层（session+RPCrypt+Ctrl）: 3-4 周
    - P3 传输层（Takion+Senkusha+GKCrypt+ECDH）: 4-6 周
    - P4 流媒体（StreamConnection+帧处理+FEC）: 3-4 周
    - P5 输入/反馈: 1-2 周
    - P6 PSN 远程（Holepunch+STUN+RUDP）: 4-6 周
    - P7 集成测试: 3-4 周
  - 依赖替换: mbedtls→CryptoKit, nanopb→SwiftProtobuf, pthread→Swift Concurrency, BSD socket→Network.framework, libcurl→URLSession, json-c→Codable
  - 需保留 C 依赖: opus（无 Swift 替代）、miniupnpc（UPnP）、可能 jerasure（FEC）
- **Swift 重写价值**（即使获得 AGPL 例外仍有独立价值）:
  - 消除 7 个 `@convention(c)` 回调 + 13 处 `Unmanaged` 指针（零桥接开销）
  - Swift Concurrency 替代 pthread（async/await + Actor 模型）
  - Network.framework 替代 BSD socket（自动网络切换、更好的移动端表现）
  - CryptoKit 硬件加速 + 自动密钥管理
  - 消除 4 平台 xcframework 交叉编译构建复杂度
  - 完全自有版权，许可证自由选择
- **法律合规方案**:
  - **推荐: Chinese Wall 方案** — 阅读过源码的人撰写协议规范文档，由未阅读源码的独立开发者实现
  - **次选: 全新架构重写** — 采用全新架构（Swift Concurrency/Actor）、全新命名体系、仅提取协议常量（不受版权保护），法律灰色地带但实际执行风险低
  - **版权法原则**: 协议/算法/常量不受版权保护，仅代码表达受保护；关键在于避免「接触+实质相似」
- **影响范围**: 整个 `Chiaki/Core/Bridge/` 替换, `libchiaki.xcframework` 移除, 构建系统简化
- **优先级**: P2（取决于 INS-086 路径 1 结果）
- **状态**: ⏸️ 暂缓（待 INS-086 路径 1 — AGPL 例外谈判结果确定后决策）

### INS-088: libplacebo 替代自有渲染为默认串流后端 🔄 已转化

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈（自有 shader 画质不理想）+ 📄 技术调研
- **参考**:
  - F-041 Metal 原生 shader 管线实践经验（Bicubic + CAS + Deband）
  - BUG-020（Metal shader `constant` vs `const` 导致黑屏 — 自维护 shader 脆弱性）
  - chiaki-ng libplacebo 集成（EWA Lanczos + 帧混合 + HDR 峰值检测 + 色域映射）
- **优先级**: P0
- **现状**: F-041 Metal 原生 shader 已完成但画质仍不及 chiaki-ng 的 libplacebo 管线。自维护 shader 代码脆弱（BUG-020 暴露 Metal 语言陷阱），且缺少 libplacebo 的高级功能（EWA Lanczos 上采样、帧混合、HDR 动态色调映射、自定义 mpv .hook 着色器支持）
- **建议**: 使用 libplacebo 作为默认串流渲染后端。初始阶段通过 MoltenVK (Vulkan) 路径集成，Metal 原生后端完成后切换
- **影响范围**: 新增 PlaceboVideoRenderer、构建系统（libplacebo + MoltenVK + SPIRV-Cross）、设置页后端切换
- **状态**: 🔄 已转化 → F-042 (AC-170~191, T-243~T-250)

### INS-089: libplacebo 集成架构（PlaceboVideoRenderer + 后端切换）🔄 已转化

- **收集时间**: 2026-02-10
- **来源**: 📄 文档调研 + 🔍 chiaki-ng 参考
- **参考**:
  - `VideoRenderer` 协议（已预留后端扩展点，INS-085）
  - chiaki-ng `qmlmainwindow.cpp`（`pl_vulkan_create` → `pl_renderer` → `pl_render_image`）
  - MoltenVK `VK_EXT_metal_objects`（CVPixelBuffer → IOSurface → VkImage 零拷贝）
- **优先级**: P0
- **现状**: `VideoRenderer` 协议已定义，`MetalVideoRenderer` 为唯一实现
- **建议**: 新增 `PlaceboVideoRenderer` 实现 `VideoRenderer` 协议。Phase 1 渲染路径：CVPixelBuffer → IOSurface → VkImage（via `VK_EXT_metal_objects`）→ `pl_render_image()` 全套渲染 → VkImage → MetalLayer 输出。设置页新增渲染后端选择（Metal Native / libplacebo）
- **影响范围**: VideoRenderer 协议、新增 PlaceboVideoRenderer 模块、StreamingViewModel 后端切换逻辑、设置页
- **状态**: 🔄 已转化 → F-042 (AC-170~191, T-243~T-250)

### INS-090: F-041 Metal 原生 shader 降级为兼容/轻量模式 🔄 已转化

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈
- **优先级**: P1
- **现状**: F-041 Metal 原生 shader 管线已完成，提供基础画质增强（Bicubic + CAS + Deband）
- **建议**: libplacebo 集成后，F-041 Metal 原生 shader 保留为轻量/兼容模式：(1) 不支持 libplacebo 的设备回退路径 (2) 低功耗模式选项 (3) 最小依赖选项。不删除代码，默认改用 libplacebo
- **影响范围**: MetalVideoRenderer（保留不变）、设置页预设逻辑
- **状态**: 🔄 已转化 → F-042 (AC-170~191, T-243~T-250)

### INS-091: libplacebo Metal 后端上游贡献策略 🔄 已转化

- **收集时间**: 2026-02-10
- **来源**: 📄 技术调研 + 🔍 开源社区参考
- **参考**:
  - 三份独立 Metal 后端设计方案（`metal-backend-claude.md`、`metal-backend-gemini.md`、`metal-backend-gpt.md`）
  - libplacebo README（维护者公开邀请 BSD-2 重新许可："if a use case emerges"）
  - D3D11 后端 PR 作为参考（成功合入 upstream 的后端新增先例）
- **优先级**: P1
- **现状**: 正在独立实现 libplacebo Metal 后端，~3,170 行代码
- **建议**: (1) Phase 1 先用 MoltenVK 验证集成架构（可立即开始）(2) Metal 后端完成后提交 upstream PR (3) 同步推进许可证重新授权讨论 (4) 若 upstream 未合入，可 fork 使用
- **影响范围**: 构建系统、依赖管理、上游 PR 策略
- **状态**: 🔄 已转化 → F-042 (AC-170~191, T-243~T-250)

---

## 统计

| 指标 | 数量 |
|------|------|
| 总洞察 | 91 |
| ✅ 已转化完成 | 82 (INS-078~084 随 M17/M18 完成) |
| 🔄 已转化待实现 | 5 (INS-085, INS-088~091→F-042 M19) |
| ⏸️ 暂缓 | 3 (INS-047, INS-086, INS-087) |
| ⏳ 待定 | 2 (INS-060, INS-061) |

---

*文档更新 (2026-02-10): 新增 INS-088~091 并转化为 F-042。INS-078~084 随 M17/M18 完成标记为已完成。devdocs-sync 状态同步*
