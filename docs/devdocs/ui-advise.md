# UI 审查建议 (UI Advice)

根据 `ui-skills` 准则对 Chiaki-ng Apple 原生客户端当前 UI 实现的审查记录。

## 1. 核心改进建议

### 1.1 可访问性 (Accessibility) - [必须]
- **问题**: `StreamingView.swift` 中的关闭按钮（第 35 行）仅包含图标，缺乏文本描述。
- **建议**: 为所有仅图标按钮添加 `.accessibilityLabel("Close Stream")`。
- **涉及文件**: `Chiaki/Features/Streaming/StreamingView.swift`

### 1.2 交互安全性 (Interaction Safety) - [建议]
- **问题**: `HostListView.swift` 中的删除操作 (`.onDelete`) 是即时生效的，缺乏二次确认。
- **建议**: 添加 `.confirmationDialog` 或 `.alert`，在执行物理删除前请求用户确认。
- **涉及文件**: `Chiaki/Features/HostList/HostListView.swift`

### 1.3 布局适配 (Layout & Safe Area) - [优化]
- **问题**: `StreamingView.swift` 的顶部 Overlay 使用了固定 `padding(.top, 10)`。
- **建议**: 在全屏（忽略安全区域）模式下，UI 控件应尊重 `safeAreaInsets`，避免被灵动岛或刘海屏遮挡。建议使用 `VisualEffect` 或 `safeAreaInset` 装饰器。
- **涉及文件**: `Chiaki/Features/Streaming/StreamingView.swift`

### 1.4 动画规范 (Animation) - [已修复 ✅]
- **原问题**: Overlay 的显示/隐藏过渡虽然设置了 `.transition(.opacity)`，但缺乏明确的动画曲线。
- **修复状态**: `StreamingViewModel.toggleOverlay()` 已使用 `withAnimation(.easeInOut(duration: 0.2))` 包裹状态切换。
- **验证时间**: 2026-01-19

### 1.5 空状态设计 (Empty State) - [设计提升]
- **问题**: 列表为空时只有文字说明，没有直接的操作入口。
- **建议**: 在空状态视图中直接放置一个 "Add Host" 按钮，符合“给空状态一个明确的下一步动作”的准则。
- **涉及文件**: `Chiaki/Features/HostList/HostListView.swift`

## 2. 已有优点 (Strengths)
- **数据对齐**: 使用 `.monospaced` 字体显示流媒体统计数据，确保了数值变动时布局的稳定性。
- **材质感**: 成功运用了 `.ultraThinMaterial`，提供了良好的系统原生感和视觉层级。
- **性能**: 采用了 `@Observable` 宏和自定义 `Shape` (GridPattern)，有效避免了冗余刷新和过度视图堆叠。

## 3. 下一步行动

### 待修复 (4 项)
- [ ] **1.1** 为关闭按钮添加 `.accessibilityLabel("Close Stream")`
- [ ] **1.2** 为删除操作添加 `.confirmationDialog` 确认弹窗
- [ ] **1.3** 将固定 `padding(.top, 10)` 替换为 `safeAreaInset` 适配
- [ ] **1.5** 在空状态视图中添加 "Add Host" 按钮

### 已完成 (1 项)
- [x] **1.4** 动画曲线优化 (2026-01-19 验证通过)

### 备注
M3/M4 核心库集成已完成，建议在 M5 测试与优化阶段处理这些 UI 改进。
