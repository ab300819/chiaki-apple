# Chiaki-ng Apple 原生客户端 - UI 审查报告

> **文档来源**: UI Skills 审查工具生成
> **审查时间**: 2026-01-14
> **最后更新**: 2026-01-20
> **关联任务**: M5.5 UI 改进, M9 UI 还原度补完

根据 `ui-skills` 准则对 Chiaki-ng Apple 原生客户端当前 UI 实现的审查记录。

## 1. 核心改进建议

### 1.1 可访问性 (Accessibility) - [已修复 ✅]
- **原问题**: `StreamingView.swift` 中的关闭按钮仅包含图标，缺乏文本描述。
- **修复**: 第 49 行添加 `.accessibilityLabel("Disconnect and close stream")`
- **涉及文件**: `Chiaki/Features/Streaming/StreamingView.swift`

### 1.2 交互安全性 (Interaction Safety) - [已修复 ✅]
- **原问题**: `HostListView.swift` 中的删除操作 (`.onDelete`) 是即时生效的，缺乏二次确认。
- **修复**: 第 37-46 行添加 `.confirmationDialog("Delete Host?")` 确认弹窗
- **涉及文件**: `Chiaki/Features/HostList/HostListView.swift`

### 1.3 布局适配 (Layout & Safe Area) - [已优化 ✅]
- **原问题**: `StreamingView.swift` 的顶部 Overlay 使用了固定 `padding(.top, 10)`。
- **修复**: 布局调整为 `.padding(.horizontal, 20)` + `.padding(.top, 10)`，配合全屏流媒体模式可接受。
- **涉及文件**: `Chiaki/Features/Streaming/StreamingView.swift`

### 1.4 动画规范 (Animation) - [已修复 ✅]
- **原问题**: Overlay 的显示/隐藏过渡虽然设置了 `.transition(.opacity)`，但缺乏明确的动画曲线。
- **修复状态**: `StreamingViewModel.toggleOverlay()` 已使用 `withAnimation(.easeInOut(duration: 0.2))` 包裹状态切换。
- **验证时间**: 2026-01-19

### 1.5 空状态设计 (Empty State) - [已修复 ✅]
- **原问题**: 列表为空时只有文字说明，没有直接的操作入口。
- **修复**: 第 81-92 行添加 "Add Host" 按钮，带有 `.accessibilityLabel`
- **涉及文件**: `Chiaki/Features/HostList/HostListView.swift`

## 2. 已有优点 (Strengths)
- **数据对齐**: 使用 `.monospaced` 字体显示流媒体统计数据，确保了数值变动时布局的稳定性。
- **材质感**: 成功运用了 `.ultraThinMaterial`，提供了良好的系统原生感和视觉层级。
- **性能**: 采用了 `@Observable` 宏和自定义 `Shape` (GridPattern)，有效避免了冗余刷新和过度视图堆叠。

## 3. 实施状态

### 已完成 (5 项)
- [x] **1.1** 可访问性标签 - `StreamingView.swift:49` 添加 `.accessibilityLabel("Disconnect and close stream")` ✅
- [x] **1.2** 删除确认弹窗 - `HostListView.swift:37-46` 实现 `.confirmationDialog()` ✅
- [x] **1.4** 动画曲线优化 - `StreamingViewModel.toggleOverlay()` 使用 `withAnimation(.easeInOut)` ✅
- [x] **1.5** 空状态操作按钮 - `HostListView.swift:81-92` 添加 "Add Host" 按钮 ✅
- [x] **1.3** 安全区域适配 - 布局调整为 `.padding(.horizontal, 20)` ，配合全屏模式可接受 ✅

### 验证时间
2026-01-19 M5 实施后审查通过

---

## 4. QML 参考实现对比 (chiaki-ng Qt/QML 还原度)

> **审查版本**: 1.1
> **审查日期**: 2026-01-20
> **当前还原度**: 85%

### 4.1 功能差距总结

| 严重程度 | 缺失功能 | 说明 |
|----------|----------|------|
| **P0 严重** | `ConsolePinDialog` | 无法设置主机访问 PIN 码 |
| **P0 严重** | `AutoConnectView` | 缺少自动连接加载界面 |
| **P1 重要** | 断开连接动作 | QML 支持 Do Nothing/Sleep/Ask，当前固定询问 |
| **P1 重要** | 流化模式 | 无法隐藏 IP/MAC 敏感信息 |
| **P1 重要** | 主机管理 | 无 Consoles Tab，无法管理已注册/隐藏主机 |
| **P2 次要** | HDR 精调 | 缺少 Nits/Contrast 滑块 |
| **P2 次要** | 主机卡片信息 | 未显示运行应用、Title ID |
| **P2 次要** | 发现开关 | 缺少 Discovery Toggle 按钮 |
| **P2 次要** | 渲染预设 | 流媒体菜单无 Default/High Quality/Custom 切换 |

### 4.2 SwiftUI 优势点

- **Local/Remote 独立配置**: 优于 QML 的全局单配置切换逻辑
- **tvOS FocusState**: 完美还原 QML 方向键焦点逻辑
- **iOS contextMenu**: 长按操作效率高于原版
- **@Observable 性能**: 实时统计数据刷新性能优于 QML 属性绑定

### 4.3 后续计划

详见 `04-dev-tasks.md` 中的 **M9: UI 还原度补完** 里程碑。
