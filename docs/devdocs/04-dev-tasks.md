# Chiaki-ng Apple 原生客户端 - 任务拆解

> **状态更新**: 2026-01-20
> **整体进度**: 95% 已完成。UI 还原度审查后发现需优化项，已规划 M8 迭代。

## 里程碑概览

| 阶段 | 名称 | 说明 | 状态 |
|------|------|------|------|
| **M1** | **项目初始化** | Xcode 项目、目录结构、子模块 | ✅ 已完成 |
| **M2** | **UI 框架** | 数据模型、SwiftUI 页面、Mock 数据、导航整合 | ✅ 已完成 |
| **M3** | **核心库构建** | 依赖交叉编译 (mbedtls/opus)、libchiaki 桥接、渲染器 & 解码器 | ✅ 已完成 |
| **M4** | **功能集成** | 真实主机发现、会话管理、Metal 渲染、音频播放 | ✅ 已完成 |
| **M5** | **完善功能** | PSN 登录、主机注册配对、UI 交互优化、安全适配 | ✅ 已完成 |
| **M6** | **平台适配** | macOS 菜单、tvOS 焦点、iOS 后台与 PiP | ✅ 已完成 |
| **M7** | **发布准备** | 文档完善、最终构建验证、图标与元数据 | ✅ 已完成 |
| **M8** | **UI 优化迭代** | 基于 chiaki-ng Qt/QML 参考的 UI 还原度修复 | 🔄 进行中 |

---

## 任务详情 (已完成阶段)

### 1. 跨平台优化 (M6) ✅
- **macOS**: 实现了原生菜单栏 (Host, View, Settings) 与窗口管理。
- **tvOS**: 优化了 Siri Remote 焦点导航与 Card 视图布局。
- **iOS**: 实现了后台音频播放与画中画 (PiP) 支持。

---

## 待办任务 (M7 发布准备)

### 2. 最后冲刺 (P1)

#### T7.1: 完善项目文档
- 更新主 `README.md`，包含多平台安装指引、构建说明及功能列表。
- 完善 `docs/` 下的架构说明。

#### T7.2: 全平台构建验证
- 验证 `iOS`, `macOS`, `tvOS` 三个 Target 在 Release 模式下的构建稳定性。

#### T7.3: 资源与元数据
- 最终确认应用图标 (AppIcon) 与多语言支持 (i18n) 基础。

---

## M8: UI 优化迭代 (基于 Qt/QML 还原度审查)

> **审查时间**: 2026-01-20
> **参考来源**: chiaki-ng/gui (Qt/QML 实现)
> **审查结论**: 核心功能完整，但部分 UI 细节与参考实现存在差距

### 审查发现汇总

| 优先级 | 类别 | 问题 | 参考位置 |
|--------|------|------|----------|
| **P0** | 流媒体统计 | 缺少丢包率/丢帧数显示 | `StreamView.qml:240-260` |
| **P0** | 网络质量 | 无实时网络质量指示器 | `StreamView.qml:280-300` |
| **P1** | 流媒体菜单 | 缺少音量/缩放/拉伸控制 | `StreamView.qml:350-420` |
| **P1** | 设置页面 | 高级视频/音频设置不完整 | `SettingsDialog.qml` |
| **P2** | 主机信息 | 缺少固件版本、MAC 地址显示 | `HostGrid.qml:80-120` |
| **P2** | 品牌色彩 | 未应用 Chiaki 品牌紫色 (#6750A4) | 全局样式 |
| **P2** | 统计着色 | 统计数值无语义化颜色 | `StreamView.qml:260` |
| **P2** | 控制器提示 | 缺少手柄按键操作提示 | `StreamView.qml:500-520` |
| **P3** | 日志查看 | 无内置日志查看功能 | `LogDialog.qml` |

### T8.1: 流媒体统计增强 (P0) 🔴

**目标**: 完善 StreamingView 的实时统计显示，对齐 Qt 参考实现

**子任务**:
- [ ] T8.1.1: 在 `StreamStatistics` 中添加 `packetLoss` 和 `droppedFrames` 字段
- [ ] T8.1.2: 从 libchiaki 回调获取丢包/丢帧数据
- [ ] T8.1.3: 在 `StreamingOverlay` 中显示丢包率 (%) 和丢帧计数
- [ ] T8.1.4: 添加网络质量指示器 (优/良/差 三档)

**验收标准**:
- 显示: 比特率 | 帧率 | 延迟 | 丢包率 | 丢帧数
- 网络质量指示器根据丢包率自动变色 (绿/黄/红)

**参考实现**:
```qml
// chiaki-ng/gui/StreamView.qml:240-260
Text {
    text: qsTr("Packet Loss: %1%").arg(streamStats.packetLoss.toFixed(2))
    color: streamStats.packetLoss > 1.0 ? "red" :
           streamStats.packetLoss > 0.1 ? "yellow" : "green"
}
```

### T8.2: 流媒体控制菜单 (P1) 🟡

**目标**: 实现完整的流媒体控制浮层

**子任务**:
- [ ] T8.2.1: 添加音量滑块控制 (0-100%)
- [ ] T8.2.2: 添加视频缩放模式 (Fit/Fill/Stretch)
- [ ] T8.2.3: 添加画面比例调整 (16:9/4:3/原始)
- [ ] T8.2.4: 添加快捷断开/重连按钮
- [ ] T8.2.5: macOS: 集成到菜单栏 View 菜单

**验收标准**:
- 手势/按键呼出控制菜单
- 所有调整实时生效
- 设置自动持久化

**涉及文件**:
- `Chiaki/Features/Streaming/StreamingOverlay.swift`
- `Chiaki/Features/Streaming/StreamingControlsView.swift` (新建)
- `Chiaki/Core/Video/MetalVideoRenderer.swift` (添加 displayMode)

### T8.3: 设置页面完善 (P1) 🟡

**目标**: 补充高级设置选项

**子任务**:
- [ ] T8.3.1: 视频设置 - 添加硬件解码开关、色彩空间选择
- [ ] T8.3.2: 音频设置 - 添加缓冲大小、输出设备选择 (macOS)
- [ ] T8.3.3: 网络设置 - 添加 MTU 配置、端口范围设置
- [ ] T8.3.4: 控制器设置 - 添加按键映射自定义
- [ ] T8.3.5: 添加设置导入/导出功能

**验收标准**:
- 设置项与 chiaki-ng 桌面版对齐
- 敏感设置带警告提示

**涉及文件**:
- `Chiaki/Features/Settings/AdvancedSettingsView.swift` (新建)
- `Chiaki/Domain/Models/StreamSettings.swift`

### T8.4: 视觉样式优化 (P2) 🟢

**目标**: 提升 UI 视觉一致性和品牌辨识度

**子任务**:
- [ ] T8.4.1: 定义品牌色彩 (主色 #6750A4、强调色、语义色)
- [ ] T8.4.2: 创建 `ChiakiTheme` 统一管理颜色/字体/间距
- [ ] T8.4.3: 统计数值应用语义化颜色 (绿=优/黄=中/红=差)
- [ ] T8.4.4: 主机卡片显示更多信息 (固件、MAC、最后连接时间)
- [ ] T8.4.5: tvOS 卡片添加聚焦动效

**涉及文件**:
- `Chiaki/Utilities/ChiakiTheme.swift` (新建)
- `Chiaki/Features/HostList/HostRowView.swift`
- `ChiakiTV/Features/TVHostCardView.swift`

### T8.5: 控制器交互提示 (P2) 🟢

**目标**: 在流媒体界面添加控制器操作提示

**子任务**:
- [ ] T8.5.1: 检测当前连接的控制器类型
- [ ] T8.5.2: 显示对应按键图标 (PlayStation/Xbox/通用)
- [ ] T8.5.3: 提示: "按 ○ 返回 | 按 OPTIONS 打开菜单"
- [ ] T8.5.4: 首次使用时显示，之后可在设置中关闭

**涉及文件**:
- `Chiaki/Features/Streaming/ControllerHintView.swift` (新建)
- `Chiaki/Core/Controllers/ControllerManager.swift`

### T8.6: 日志与诊断 (P3) 🔵

**目标**: 添加内置日志查看和导出功能

**子任务**:
- [ ] T8.6.1: 实现日志缓冲区 (最近 1000 条)
- [ ] T8.6.2: 创建 `LogViewerView` 支持筛选/搜索
- [ ] T8.6.3: 添加日志导出为文件功能
- [ ] T8.6.4: 在设置中添加"诊断信息"入口

**涉及文件**:
- `Chiaki/Features/Settings/LogViewerView.swift` (新建)
- `Chiaki/Utilities/Logger.swift`

---

### M8 任务优先级矩阵

```
紧急程度 →
↑      ┌─────────────┬─────────────┐
重      │ T8.1 统计   │ T8.2 菜单   │
要      │ T8.3 设置   │             │
程      ├─────────────┼─────────────┤
度      │ T8.4 视觉   │ T8.6 日志   │
↓      │ T8.5 提示   │             │
       └─────────────┴─────────────┘
          高优先          低优先
```

### M8 执行计划

| 阶段 | 任务 | 预计工作量 | 依赖 |
|------|------|-----------|------|
| **Phase 1** | T8.1 流媒体统计增强 | 4h | 无 |
| **Phase 1** | T8.4.1-8.4.3 主题定义 | 2h | 无 |
| **Phase 2** | T8.2 流媒体控制菜单 | 6h | T8.4 |
| **Phase 2** | T8.3 设置页面完善 | 4h | 无 |
| **Phase 3** | T8.4.4-8.4.5 卡片优化 | 2h | T8.4.1 |
| **Phase 3** | T8.5 控制器提示 | 3h | 无 |
| **Phase 4** | T8.6 日志诊断 | 4h | 无 |

---

## 测试任务 (Testing)

> **更新时间**: 2026-01-19
> **测试框架**: Swift Testing + XCUITest

### T8: 测试实现 ✅

| 任务编号 | 任务名称 | 状态 | 测试数量 |
|----------|----------|------|----------|
| T8.1 | 单元测试 UT-001~005 | ✅ 完成 | 70 |
| T8.2 | 集成测试 IT-001~003 | ✅ 完成 | 28 |
| T8.3 | E2E 测试 E2E-001 | ✅ 完成 | 4 |
| T8.4 | 高级测试 (P0/P1) | ✅ 完成 | 44 |

### 测试覆盖详情

| 测试文件 | 用例数 | 覆盖模块 |
|----------|--------|----------|
| `ChiakiTests.swift` | 39 | ConsoleHost, HostState, StreamSettings, SettingsStore, HostStore, CircularAudioBuffer, LockFreeQueue |
| `SessionAndDiscoveryTests.swift` | 31 | SessionState, SessionError, HostConfig, StreamConfig, DiscoveryError, ChiakiTypes, ControllerInput, ControllerButtons, RegisteredHostInfo, VideoProfile |
| `IntegrationTests.swift` | 28 | MetalVideoRenderer, AudioPlayer, AudioPlayerBridge, ControllerManager, DualSenseIntensity, DiscoveredHostInfo, ChiakiHostState |
| `AdvancedTests.swift` | 44 | ChiakiSessionWrapper, DiscoveryService, StreamingViewModel, KeychainManager, StreamStatistics, VideoDecoderBridge, PiPManager |
| `ChiakiUITests.swift` | 4 | 应用启动、性能测试 |

### 覆盖率统计

| 指标 | 值 |
|------|-----|
| **总测试数** | 146 |
| **通过率** | 100% |
| **代码覆盖率** | ~25% (估算) |
| **模型层覆盖** | ~90% |
| **服务层覆盖** | ~60% |
| **视图层覆盖** | ~15% |

### 已补充测试 (原 Tech Debt)

| 优先级 | 测试项 | 状态 | 说明 |
|--------|--------|------|------|
| P0 | ChiakiSessionWrapper | ✅ | 状态转换、配置、回调、错误映射 |
| P0 | DiscoveryService | ✅ | 初始化、启停、唤醒验证 |
| P1 | StreamingViewModel | ✅ | 状态机、连接验证、PiP |
| P1 | KeychainManager | ✅ | 存取、更新、删除、错误处理 |
| P1 | StreamStatistics | ✅ | 帧统计、质量指标、会话生命周期 |

### 待补充测试 (剩余 Tech Debt)

| 优先级 | 测试项 | 阻塞原因 |
|--------|--------|----------|
| P2 | E2E-002 流媒体页面 | 需真实 PS 主机 |
| P2 | E2E-003 设置页面 | UI 自动化补充 |
| P2 | E2E-004 tvOS 焦点 | 需 tvOS 环境 |

---

## 执行检查清单

### 已完成任务

| 任务 | 测试 (Testable) | 验收 (Acceptable) | 提交 |
|------|------|------|------|
| M6.1: macOS 菜单 | 菜单项响应正常 | 符合 Mac 操作逻辑 | ✅ |
| M6.3: tvOS 焦点 | Remote 导航流畅 | 焦点状态清晰 | ✅ |
| M6.4: iOS PiP | 切换至桌面后小窗显示 | 音视频同步正常 | ✅ |
| T7.1: 文档更新 | 内容准确无误 | 涵盖所有新功能 | ✅ |
| T-Test.1: 单元测试 | 102 测试通过 | 覆盖核心模块 | ✅ |
| T-Test.2: 集成测试 | IT-001~003 通过 | 视频/音频/控制器 | ✅ |
| T-Test.3: E2E 测试 | 应用可启动 | 基础功能可用 | ⚠️ |

### M8 UI 优化任务

| 任务 | 测试 (Testable) | 验收 (Acceptable) | 提交 |
|------|------|------|------|
| T8.1: 流媒体统计增强 | 显示丢包率/丢帧数 | 数值与 libchiaki 一致 | ⏳ |
| T8.2: 流媒体控制菜单 | 音量/缩放调整生效 | 设置持久化 | ⏳ |
| T8.3: 设置页面完善 | 新增设置项可配置 | 与桌面版功能对齐 | ⏳ |
| T8.4: 视觉样式优化 | 主题色正确应用 | UI 一致性提升 | ⏳ |
| T8.5: 控制器交互提示 | 正确识别控制器类型 | 提示信息准确 | ⏳ |
| T8.6: 日志与诊断 | 日志可查看/导出 | 便于问题排查 | ⏳ |
