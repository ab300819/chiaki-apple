# 洞察收集：SwiftUI 架构与 UI 优化

**收集时间**：2026-01-27
**来源类型**：🎨 UI/UX 审查 & 📄 技术审计

## 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-001 | API 现代化：全面迁移至 iOS 17+ 标准 | 🎨 | P0 | ✅ 已确认 |
| INS-002 | 状态 management 归一化：迁移剩余 `ObservableObject` | 📄 | P1 | ✅ 已确认 |
| INS-003 | 架构解耦：重构 `StreamingViewModel` | 📄 | P1 | ✅ 已确认 |
| INS-004 | 交互精致化：优化动画曲线与原生感 | 🎨 | P2 | ✅ 已确认 |
| INS-005 | 未来适配：引入 Liquid Glass (iOS 26+) | 🎨 | P2 | ✅ 已确认 |

## 详细建议

### INS-001: API 现代化：全面迁移至 iOS 17+ 标准
- **来源**: 🎨 UI/UX 审查
- **现状**: 代码中仍有 93 处使用弃用的 `.foregroundColor()`，以及多处 `.cornerRadius()`。
- **建议**: 全局迁移至 `.foregroundStyle()` 和 `.clipShape()`。
- **预期收益**: 提高渲染效率，支持分层颜色。

### INS-002: 状态管理归一化
- **来源**: 📄 技术审计
- **现状**: 部分服务类仍使用旧版 Combine `ObservableObject`。
- **建议**: 统一迁移至 `@Observable`。
- **预期收益**: 减少视图刷新粒度。

### INS-003: 架构解耦：重构 `StreamingViewModel`
- **来源**: 📄 技术审计
- **现状**: `StreamingViewModel` 职责过重（400+ 行）。
- **建议**: 拆分出统计管理和输入映射模块。
- **预期收益**: 提高可测试性，降低视图刷新频率。

---

## 确认结果

- [x] INS-004: 已确认 → F-013
- [x] INS-005: 已确认 → F-014

---

## 洞察收集：Phase 11 生产就绪与体验打磨

**收集时间**：2026-01-27
**来源类型**：📄 产品路线图 (Beta 1 冲刺)

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-006 | i18n 本地化深度补全 (xcstrings) | 🎨 | P0 | ✅ 已确认 |
| INS-007 | 异常恢复：增强网络波动下的重连机制 | 📄 | P0 | ✅ 已确认 |
| INS-008 | 能效优化：Metal 渲染器节能调优 | 📄 | P1 | ✅ 已确认 |
| INS-009 | 生产构建元数据完善 (Metadata) | 🎨 | P1 | ✅ 已确认 |
| INS-010 | 触觉反馈 2.0：语义化 haptics 精调 | 🎨 | P2 | ✅ 已确认 |

### 详细建议

#### INS-006: i18n 本地化深度补全
- **现状**: 部分错误提示和 Accessibility 标签仍为硬编码。
- **建议**: 全面迁移至 `Localizable.xcstrings`。

#### INS-007: 异常恢复：增强重连机制
- **现状**: 网络剧烈波动可能导致会话僵死。
- **建议**: 引入 `NWPathMonitor` 并结合 RUDP 保持逻辑。

---

## 确认结果

- [x] INS-006: 已确认 → F-015
- [x] INS-007: 已确认 → F-016
- [x] INS-008: 已确认 → F-017
- [x] INS-009: 已确认 → F-018
- [x] INS-010: 已确认 → [待分配]

---

## 洞察收集：完善日志系统

**收集时间**：2026-01-28
**来源类型**：💡 内部反馈（用户排查需求）

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-011 | 日志文件持久化 | 💡 | P0 | 🔄 已转化 |
| INS-012 | 日志文件轮换策略 | 💡 | P1 | 🔄 已转化 |
| INS-013 | 一键导出诊断包 | 💡 | P0 | 🔄 已转化 |
| INS-014 | 崩溃日志自动捕获 | 💡 | P1 | 🔄 已转化 |
| INS-015 | 敏感信息脱敏 | 💡 | P1 | 🔄 已转化 |

### 详细建议

#### INS-011: 日志文件持久化
- **现状**: 日志仅保存在内存中（最多 1000 条），应用重启后丢失
- **建议**: 将日志实时写入文件，存储在应用文档目录
- **影响范围**: `Logger.swift`，新增 `FileLogHandler`

#### INS-012: 日志文件轮换策略
- **现状**: 无文件管理机制，可能导致存储空间占用过大
- **建议**: 实现日志轮换：按大小（5MB/文件）+ 按数量（保留最近 7 个文件）
- **影响范围**: `FileLogHandler`（新增）

#### INS-013: 一键导出诊断包
- **现状**: 仅支持导出当前内存中的过滤日志
- **建议**: 提供"导出诊断包"功能，包含：所有日志文件 + 设备信息 + 网络状态 + 配置快照
- **影响范围**: `LogViewerView.swift`，新增 `DiagnosticsExporter`

#### INS-014: 崩溃日志自动捕获
- **现状**: 未捕获 Swift 异常和崩溃信号
- **建议**: 集成简单的崩溃捕获，记录最后的调用栈到日志文件
- **影响范围**: `ChiakiApp.swift`

#### INS-015: 敏感信息脱敏
- **现状**: 日志可能包含 IP、PSN ID、令牌等敏感信息
- **建议**: 导出时自动脱敏：IP 部分遮蔽、令牌截断、用户 ID 哈希化
- **影响范围**: `DiagnosticsExporter`（新增）

---

### 确认结果

- [x] INS-011: 已确认 → F-019 / AC-049
- [x] INS-012: 已确认 → F-019 / AC-050
- [x] INS-013: 已确认 → F-019 / AC-051
- [x] INS-014: 已确认 → F-019 / AC-052
- [x] INS-015: 已确认 → F-019 / AC-053

---

## 洞察收集：增强日志覆盖范围

**收集时间**：2026-01-28
**来源类型**：💡 内部反馈

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-016 | 增强核心流程日志覆盖 | 💡 | P1 | 🔄 已转化 |

### 详细建议

#### INS-016: 增强核心流程日志覆盖
- **现状**: 现有日志主要覆盖错误和状态变化，核心操作步骤记录不足
- **建议**: 在关键流程中增加详细日志，确保排查时有充足的上下文数据
- **影响范围**: Session、Video、Audio、Controller、Discovery、PSN、Network 等核心模块

**建议增加日志的关键位置**:
- Session 连接流程：连接参数、握手阶段、认证步骤、会话建立
- Video 解码：收到 SPS/PPS、解码器初始化、帧统计
- Audio 播放：音频格式、缓冲状态、欠载事件
- Controller 输入：控制器连接/断开、按键映射
- Discovery 发现：发送/接收的发现包、解析结果
- PSN 认证：OAuth 流程阶段、Token 刷新触发
- Network 状态：连接类型变化、RTT 测量

---

### 确认结果

- [x] INS-016: 已确认 → F-019 / AC-054

---

## 洞察收集：手柄操作 UI 支持度

**收集时间**：2026-01-30
**来源类型**：💡 内部反馈 + 🎨 UI/UX 审查
**参考文档**：`controller-insight.md` (GameController 框架调研)

### 背景

用户在使用 Chiaki 时主要通过手柄操作，很少切换到触控或键盘。当前 UI 设计主要面向触控交互，手柄操作存在以下痛点：

1. 流媒体控制菜单必须触摸屏幕才能操作
2. tvOS 上焦点反馈不明确
3. 缺少手柄快捷键支持

**技术背景**（来自 controller-insight.md）：
- GameController 框架支持 iOS / iPadOS / macOS / tvOS / visionOS
- 系统原生支持 DualSense、DualShock 4、Xbox、Switch Pro、MFi 控制器
- 开发层面无需区分厂商，使用 `physicalInputProfile` 检测能力而非型号

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-017 | 流媒体控制菜单无焦点管理 | 💡 | P0 | 🔄 已转化 |
| INS-018 | tvOS 菜单按钮无焦点反馈 | 💡 | P0 | 🔄 已转化 |
| INS-019 | 控制菜单无焦点陷阱 | 💡 | P1 | 🔄 已转化 |
| INS-020 | tvOS 方向键导航不完整 | 💡 | P1 | 🔄 已转化 |
| INS-021 | 手柄快捷操作缺失 | 💡 | P1 | 🔄 已转化 |
| INS-022 | 控制菜单关闭后焦点丢失 | 🎨 | P2 | 🔄 已转化 |

### 详细建议

#### INS-017: 流媒体控制菜单无焦点管理
- **现状**: `StreamingControlsView` 中的按钮、滑块均无 `@FocusState` 管理
- **建议**: 添加焦点枚举和 `.focused()` 修饰符
- **影响范围**: StreamingControlsView.swift
- **技术参考**: SwiftUI `@FocusState` + `FocusedValue` 实现焦点追踪
- **实现要点**:
  ```swift
  enum ControlFocus: Hashable {
      case disconnectButton, micToggle, volumeSlider, qualityPicker
  }
  @FocusState private var focusedControl: ControlFocus?
  ```

#### INS-018: tvOS 菜单按钮无焦点反馈
- **现状**: tvOS 控制菜单按钮使用 `.buttonStyle(.plain)`，无焦点视觉反馈
- **建议**: 创建 `FocusableButtonStyle`，焦点时添加边框/缩放效果
- **影响范围**: StreamingControlsView.swift
- **技术参考**: tvOS HIG 推荐焦点时 1.05x 缩放 + 阴影
- **实现要点**:
  ```swift
  struct FocusableButtonStyle: ButtonStyle {
      @Environment(\.isFocused) var isFocused
      func makeBody(configuration: Configuration) -> some View {
          configuration.label
              .scaleEffect(isFocused ? 1.05 : 1.0)
              .overlay(isFocused ? RoundedRectangle(...).stroke(...) : nil)
      }
  }
  ```

#### INS-019: 控制菜单无焦点陷阱
- **现状**: 菜单打开时手柄方向键可能操作背景视频层
- **建议**: 使用 `focusSection()` 或条件 disabled 实现焦点隔离
- **影响范围**: StreamingView.swift
- **技术参考**: tvOS `focusSection()` modifier 创建焦点边界
- **实现要点**: 菜单显示时禁用背景层的焦点响应

#### INS-020: tvOS 方向键导航不完整
- **现状**: 仅处理 `onExitCommand` 和 `onPlayPauseCommand`
- **建议**: 添加 `onMoveCommand` 处理完整方向键导航
- **影响范围**: StreamingView.swift
- **技术参考**: tvOS 支持 `.onMoveCommand { direction in ... }`
- **实现要点**:
  ```swift
  .onMoveCommand { direction in
      switch direction {
      case .up, .down, .left, .right: handleNavigation(direction)
      @unknown default: break
      }
  }
  ```

#### INS-021: 手柄快捷操作缺失
- **现状**: 必须通过触摸 UI 才能打开控制菜单
- **建议**: 添加组合键：PS+Options 打开菜单，L1+R1+PS 断开连接
- **影响范围**: ControllerManager.swift, StreamingViewModel.swift
- **技术参考**: GameController 通过 `valueChangedHandler` 检测按键组合
- **实现要点**:
  - 在输入映射层（推荐结构第 2 层）检测组合键
  - 组合键不应转发到 PlayStation（仅本地 UI 操作）
  - 需要防抖机制避免误触发（建议 200ms 延迟确认）

#### INS-022: 控制菜单关闭后焦点丢失
- **现状**: 关闭菜单后焦点可能跳转到意外位置
- **建议**: 实现焦点记忆和恢复逻辑
- **影响范围**: StreamingControlsView.swift
- **技术参考**: SwiftUI `@FocusState` 绑定可编程设置
- **实现要点**: 记录菜单打开前的焦点状态，关闭时恢复

---

### 确认结果

- [x] INS-017: 已确认 → F-020 / AC-055
- [x] INS-018: 已确认 → F-020 / AC-056
- [x] INS-019: 已确认 → F-020 / AC-057
- [x] INS-020: 已确认 → F-020 / AC-058
- [x] INS-021: 已确认 → F-020 / AC-059
- [x] INS-022: 已确认 → F-020 / AC-060

---

## 洞察收集：GameController 框架使用评估

**收集时间**：2026-01-30
**来源类型**：📄 技术审计
**参考文档**：`controller-insight.md` (GameController 框架调研)

### 背景

用户询问是否可以更多依赖 `GameController` 框架来简化手柄管理。经调研，当前实现已充分利用 GameController 框架：

- 控制器发现/连接：✅ 使用 `GCController.controllers()` 和通知系统
- 按钮/摇杆/扳机：✅ 使用 `GCExtendedGamepad` 属性
- Motion 传感器：✅ 使用 `GCMotion`
- LED 控制：✅ 使用 `GCLight`

**必须自定义的部分**（无法用 GameController 替代）：
- ChiakiControllerInput 序列化（libchiaki C 协议桥接）
- 虚拟触控手柄（非物理控制器）
- macOS 键盘映射（GameController 不支持键盘）

**调研结论**（来自 controller-insight.md）：
> **根据"能力是否存在"启用功能，而不是根据"型号字符串"判断**
> - 使用 `physicalInputProfile` 检测能力（推荐）
> - 避免依赖 `vendorName`（不稳定）

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-023 | 启用 DualSense 自适应扳机 | 📄 | P2 | 🔄 已转化 |
| INS-024 | 启用触控板位置追踪 | 📄 | P2 | 🔄 已转化 |
| INS-025 | 统一 Haptics 引擎实例 | 📄 | P1 | 🔄 已转化 |
| INS-026 | 添加控制器电池电量显示 | 📄 | P3 | 🔄 已转化 |

### 详细建议

#### INS-023: 启用 DualSense 自适应扳机

- **现状**: `adaptiveTriggersEnabled` 属性已声明但未使用（ControllerManager.swift Line 72）
- **建议**: 实现 `GCDualSenseAdaptiveTriggers` 支持，解码 PS5 扳机效果事件
- **影响范围**: ControllerManager.swift, ChiakiSessionWrapper.swift
- **预期收益**: 支持 PS5 游戏的自适应扳机反馈
- **技术参考** (controller-insight.md):
  - 自适应扳机：✅（iOS 16+）支持阻力/区间反馈
  - USB 连接能力通常比蓝牙完整
  - macOS 支持度通常高于 iOS
- **实现要点**:
  ```swift
  if let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad,
     let triggers = dualSense.leftTrigger.adaptiveTriggers {
      // 设置扳机效果
      triggers.setModeFeedbackWithStartPosition(0.3, resistiveStrength: 0.8)
  }
  ```
- **注意**: 需要解码 libchiaki 的 `ChiakiSessionEvent.triggerEffects` 并映射到 GameController 格式

#### INS-024: 启用触控板位置追踪

- **现状**: 仅检测触控板按钮状态，未使用 `GCDualSenseGamepadTouchpadInput` 位置数据
- **建议**: 映射触控板 X/Y 坐标到 `ChiakiControllerTouch` 结构
- **影响范围**: ControllerManager.swift
- **预期收益**: 支持需要触控板位置的 PS5 游戏
- **技术参考** (controller-insight.md):
  - 触摸板：✅ 支持坐标 + 按压
- **实现要点**:
  ```swift
  if let touchpad = dualSense.touchpadButton {
      // 触控板支持坐标追踪
      let x = touchpad.touchSurface?.x ?? 0
      let y = touchpad.touchSurface?.y ?? 0
      // 映射到 ChiakiControllerTouch
  }
  ```

#### INS-025: 统一 Haptics 引擎实例

- **现状**: ControllerManager 和 HapticsManager 各自创建 `CHHapticEngine` 实例
- **建议**: 统一由 HapticsManager 管理，ControllerManager 调用其接口
- **影响范围**: ControllerManager.swift, HapticsManager.swift
- **预期收益**: 减少资源占用，避免潜在冲突
- **技术参考** (controller-insight.md):
  - 高级震动：✅ 支持自动降级兼容
- **实现要点**:
  - HapticsManager 提供 `func applyRumble(left: Float, right: Float)` 接口
  - ControllerManager 移除本地 `CHHapticEngine` 初始化
  - 引擎生命周期由 HapticsManager 统一管理

#### INS-026: 添加控制器电池电量显示

- **现状**: `GCController.battery` 属性未使用
- **建议**: 在 UI 中显示连接手柄的电量
- **影响范围**: ControllerManager.swift, UI 层
- **预期收益**: 用户体验提升
- **实现要点**:
  ```swift
  if let battery = controller.battery {
      let level = battery.batteryLevel  // 0.0 ~ 1.0
      let state = battery.batteryState  // .charging, .discharging, .full
  }
  ```
- **UI 建议**: 在控制器信息区域显示电池图标，低于 20% 时显示警告色

---

### 确认结果

- [x] INS-023: 已确认 → F-021 / AC-061
- [x] INS-024: 已确认 → F-021 / AC-062
- [x] INS-025: 已确认 → F-021 / AC-063
- [x] INS-026: 已确认 → F-021 / AC-064

---

## 洞察收集：StreamingOverlay 信息完善

**收集时间**：2026-01-30
**来源类型**：💡 内部反馈

### 背景

用户建议在 StreamingOverlay 增加 HDR 标志，以便直观确认当前流的视频规格。

**现有代码支持情况**：
- `ChiakiVideoCodec.h265HDR` 已定义，提供 `isHDR` 属性
- `StreamSettings.hdrEnabled` 控制 HDR 请求
- `StreamingOverlay` 显示分辨率、帧率、延迟、码率、丢包
- **但未显示 HDR 状态**

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-027 | StreamingOverlay HDR 标志 | 💡 | P2 | 🔄 已转化 |

### 详细建议

#### INS-027: StreamingOverlay HDR 标志

- **现状**: StreamingOverlay 不显示当前流是否为 HDR
- **建议**: 在分辨率旁添加 "HDR" 徽章
- **影响范围**: StreamStatsManager.swift, StreamingOverlay.swift
- **预期收益**: 用户可直观确认 HDR 状态，完善视频规格信息展示
- **实现要点**:
  ```swift
  // StreamStatsManager
  var isHDR: Bool = false

  // StreamingOverlay - 分辨率旁显示 HDR 徽章
  HStack(spacing: 16) {
      StatItem(icon: "display", value: stats.currentResolution)
      if stats.isHDR {
          Text("HDR")
              .font(.system(size: 10, weight: .bold))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(LinearGradient(...))
              .clipShape(RoundedRectangle(cornerRadius: 4))
      }
  }
  ```

---

### 确认结果

- [x] INS-027: 已确认 → T-135

---

## 洞察收集：手柄全操控 UI/UX 深度优化

**收集时间**：2026-01-30
**来源类型**：🎨 UI/UX 审查
**分析范围**：导航结构、菜单层级、操作步骤、tvOS 适配

### 背景

用户使用 Chiaki 时主要依赖手柄操作，很少切换到触控或键盘。经过对应用导航结构的全面审查，发现以下特点：

**当前优势**：
- 顶层导航简洁（仅 2 个主标签：Hosts、Settings）
- 设置菜单层级浅（最多 3 层）
- tvOS 已有焦点管理 (`@FocusState`) 和命令处理
- F-020 已规划基础手柄支持（焦点管理、组合键）

**待改进领域**：
| 问题类型 | 影响程度 | 当前状态 |
|----------|----------|----------|
| 常用操作步骤多 | 高 | 3+ 步访问常用功能 |
| 文本/数字输入 | 中 | 依赖系统键盘 |
| 流媒体中调整设置 | 中 | 需断开重连 |

### 建议汇总

| 编号 | 标题 | 来源 | 优先级 | 状态 |
|------|------|------|--------|------|
| INS-028 | 主机快速操作栏（替代长按菜单） | 🎨 | P1 | 🔄 已转化 |
| INS-029 | 流媒体中音量快捷调节 | 🎨 | P2 | 🔄 已转化 |
| INS-030 | PIN 输入数字键盘优化 | 🎨 | P2 | 🔄 已转化 |
| INS-031 | 设置快捷入口（流媒体中直接访问） | 🎨 | P3 | 🔄 已转化 |

### 详细建议

#### INS-028: 主机快速操作栏

- **现状**: 唤醒、设置 PIN、删除等操作需要长按主机卡片打开上下文菜单，手柄操作需要 3 步（聚焦 → 长按 → 选择）
- **建议**: 为选中的主机卡片添加底部快速操作栏，显示常用按钮
- **影响范围**: HostListView.swift, TVHostCardView.swift
- **预期收益**:
  - 减少操作步骤：3 步 → 1 步
  - 手柄 Select 键直接显示操作选项
  - 避免长按等待时间
- **实现要点**:
  ```swift
  // 选中主机时显示操作栏
  if focusedHost == host.id {
      HStack(spacing: 16) {
          Button("唤醒") { wakeUp(host) }
              .focused($focusedAction, equals: .wake)
          Button("PIN") { showPinView(host) }
              .focused($focusedAction, equals: .pin)
          Button("删除") { deleteHost(host) }
              .focused($focusedAction, equals: .delete)
      }
      .transition(.move(edge: .bottom).combined(with: .opacity))
  }
  ```

#### INS-029: 流媒体中音量快捷调节

- **现状**: 调整音量需要：点击屏幕 → 打开控制菜单 → 找到滑块 → 调整（4 步）
- **建议**: 添加手柄快捷键：PS+L2 音量减、PS+R2 音量加（±5%），无需打开菜单
- **影响范围**: ControllerShortcutDetector.swift, StreamingViewModel.swift
- **预期收益**:
  - 游戏中快速调节音量
  - 无需中断游戏打开菜单
  - 与常见游戏机操作习惯一致
- **实现要点**:
  ```swift
  // 在 ControllerShortcutDetector 中扩展
  var onVolumeUp: (() -> Void)?
  var onVolumeDown: (() -> Void)?

  // PS + L2 → 音量 -5%
  if buttons.contains([.ps, .l2]) && !buttons.contains(.r2) {
      onVolumeDown?()
  }
  // PS + R2 → 音量 +5%
  if buttons.contains([.ps, .r2]) && !buttons.contains(.l2) {
      onVolumeUp?()
  }
  ```
- **注意**: 需要显示临时音量提示（OSD 风格）

#### INS-030: PIN 输入数字键盘优化

- **现状**: ConsolePinView 使用标准 TextField，tvOS 需要调出系统键盘输入 4 位数字
- **建议**: 创建手柄友好的数字键盘视图，用方向键选择数字
- **影响范围**: ConsolePinView.swift, 新建 GamepadNumPad.swift
- **预期收益**:
  - 消除对系统键盘的依赖
  - 手柄方向键 + 确认键即可输入
  - 更快的输入体验（约 3 秒 vs 10+ 秒）
- **实现要点**:
  ```swift
  // 3x4 数字键盘布局
  struct GamepadNumPad: View {
      @Binding var value: String
      @FocusState private var focusedKey: String?

      let keys = [
          ["1", "2", "3"],
          ["4", "5", "6"],
          ["7", "8", "9"],
          ["", "0", "⌫"]
      ]

      var body: some View {
          VStack(spacing: 12) {
              ForEach(keys, id: \.self) { row in
                  HStack(spacing: 12) {
                      ForEach(row, id: \.self) { key in
                          NumPadKey(key: key, action: { handleKey(key) })
                              .focused($focusedKey, equals: key)
                      }
                  }
              }
          }
      }
  }
  ```

#### INS-031: 设置快捷入口

- **现状**: 流媒体中修改视频设置需要：断开 → 返回主界面 → 设置 → 视频 → 修改 → 重新连接（6 步）
- **建议**: 在控制菜单中添加"快速设置"入口，可直接调整常用视频/音频参数
- **影响范围**: StreamingControlsView.swift, 新建 QuickSettingsSection.swift
- **预期收益**:
  - 流媒体中直接调整码率、分辨率
  - 无需断开连接即可优化体验
  - 减少 6 步操作为 2 步
- **实现要点**:
  ```swift
  // 在 StreamingControlsView 中添加
  Section {
      DisclosureGroup("快速设置") {
          // 码率调整
          Stepper("码率: \(bitrate/1000)Mbps",
                  value: $bitrate,
                  in: 5000...50000,
                  step: 5000)

          // 分辨率选择（需要重连生效）
          Picker("分辨率", selection: $resolution) {
              Text("720p").tag(Resolution.r720p)
              Text("1080p").tag(Resolution.r1080p)
          }
          .disabled(true) // 标注需要重连

          Text("* 分辨率变更需重新连接")
              .font(.caption)
              .foregroundStyle(.secondary)
      }
  }
  ```
- **注意**: 部分设置（如分辨率）无法热更新，需要标注"重连后生效"

---

### 确认结果

- [x] INS-028: 已确认 → F-022 / AC-065
- [x] INS-029: 已确认 → F-022 / AC-066
- [x] INS-030: 已确认 → F-022 / AC-067
- [x] INS-031: 已确认 → F-022 / AC-068
