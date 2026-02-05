# Chiaki-ng Apple 原生客户端 - 开发任务

> **状态更新**: 2026-02-06
> **当前里程碑**: M14 规划中
> **归档**: [archive/04-dev-tasks-archive.md](archive/04-dev-tasks-archive.md) (M11: 35 任务, M12: 24 任务, M13: 23 任务)

---

## 归档摘要

### M13 归档 (2026-02-05)

> **阶段目标**: HDR 配置落地 + MainActor 边界规范化 + 日志规范化 + 主题色系统化 + 自动发现 + macOS 布局优化 | **完成率**: 100% (23/23)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m13-归档---hdr-配置落地mainactor-边界日志规范化主题色自动发现macos-布局)

| 功能 | 任务 | 提交 |
|------|------|------|
| F-028 HDR 配置落地 | T-171~T-174, T-182 | cf958bd, b736a4c |
| F-029 MainActor 边界 | T-175~T-177, T-183 | 83444ad, 61866a3, 6f6e6eb, 452f1eb |
| F-030 日志规范化 | T-178~T-181 | 8c975cd |
| F-031 主题色系统化 | T-189~T-191 | 6ae26c5 |
| F-032 自动发现主机 | T-192~T-194 | e6a08d7 |
| F-033 macOS TabView | T-195~T-198 | b1ce996 |

### M12 归档 (2026-02-05)

> **阶段目标**: HDR 渲染优化、渲染模块解耦、UI 层 MVVM 合规重构 | **完成率**: 100% (24/24)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m12-归档---hdr-渲染优化渲染模块解耦ui-层-mvvm-重构)

| 状态 | 数量 | 说明 |
|------|------|------|
| ✅ 已完成 | 24 | T-147~T-170 |

### M11 归档 (2026-02-04)

> **阶段目标**: Beta 1 发布冲刺 | **完成率**: 97% (35/36)
> **详情**: [查看归档文件](archive/04-dev-tasks-archive.md#m11-归档---beta-1-发布冲刺)

| 状态 | 数量 | 说明 |
|------|------|------|
| ✅ 已完成 | 30 | T-111~T-134, T-136~T-139, T-145~T-146 |
| 📦 早前归档 | 5 | T-140~T-144 |
| ⏳ 进行中 | 1 | T-115 (待设计师资产) |

---

## 遗留任务

### T-115: 分发：多平台 App Icon 资产准备 ⏳

- **关联需求**: F-018, AC-048
- **当前进度**: tvOS 配置已完成，待设计师提供实际图像资产
- **涉及文件**: `Assets.xcassets/AppIcon.appiconset/`

---

## Bug 修复任务

### BUG-005: 音频播放异常（咯哒声/杂音） ✅ 已修复

> **来源**: 用户反馈
> **严重程度**: P0
> **状态**: ✅ 已修复
> **关联 Bug 记录**: [05-bugfix-log.md#BUG-005](05-bugfix-log.md#bug-005-音频播放异常咯哒声杂音)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-185 | Audio: OpusDecoderBridge 创建 | ✅ |
| T-186 | Audio: ChiakiSession Opus 集成 | ✅ |
| T-187 | Audio: AudioPlayerBridge 接口适配 | ✅ |
| T-188 | Audio: 音频流端到端测试 | ✅ |

---

### BUG-004: 唤醒主机后首次连接失败 ✅ 已修复

> **来源**: 用户反馈
> **严重程度**: P1
> **状态**: ✅ 已修复
> **关联 Bug 记录**: [05-bugfix-log.md#BUG-004](05-bugfix-log.md#bug-004-唤醒主机后首次连接失败)

| 编号 | 名称 | 状态 |
|------|------|------|
| T-184 | 修复唤醒后连接逻辑 | ✅ |

---

## M14 任务：F-034 macOS 设置侧边栏导航

> **阶段目标**: macOS 设置页面布局优化，消除双层 TabView 混淆
> **来源**: INS-052 (UI/UX 审查)
> **优先级**: P2

### 依赖关系图

```
T-199 (SettingsCategory 枚举)
   │
   ▼
T-200 (侧边栏列表)
   │
   ▼
T-201 (详情视图切换)
   │
   ▼
T-202 (验证与调整)
```

---

### T-199: 定义 SettingsCategory 枚举 ✅

- **关联需求**: F-034, AC-122, AC-125
- **优先级**: P2
- **依赖**: 无
- **TDD 模式**: 🟢 可选
- **提交**: 9f94de7

**描述**：
创建 `SettingsCategory` 枚举，定义所有设置分类及其图标、标题映射。

**涉及文件**：
- `Chiaki/Features/Settings/SettingsView.swift`

**验收标准**：
- [ ] 枚举包含 8 个分类：general, video, audio, controller, account, consoles, logs, data
- [ ] 每个分类有对应的 `title` (使用 L10n) 和 `systemImage`
- [ ] 枚举遵循 `CaseIterable, Identifiable, Hashable` 协议

**测试方法**：
- 编译通过，枚举可正常使用

**Review 要点**：
- 枚举命名与现有 Tab 顺序一致
- 使用 L10n 本地化字符串

---

### T-200: 实现侧边栏列表视图 ✅

- **关联需求**: F-034, AC-121, AC-122
- **优先级**: P2
- **依赖**: T-199 ✅
- **TDD 模式**: 🟢 可选
- **提交**: 88ba705

**描述**：
在 macOS 分支中，将 `TabView` 替换为 `NavigationSplitView`，左侧显示设置分类列表。

**涉及文件**：
- `Chiaki/Features/Settings/SettingsView.swift`

**验收标准**：
- [ ] macOS 使用 `NavigationSplitView` 替代 `TabView`
- [ ] 左侧 List 显示所有 8 个设置分类
- [ ] 列表项使用 Label 显示图标和标题
- [ ] 列表支持单选 (`selection: $selectedCategory`)

**测试方法**：
- macOS 运行，验证侧边栏正常显示
- 点击列表项可选中

**Review 要点**：
- `#if os(macOS)` 条件编译正确
- iOS/tvOS 保持原有实现不变

---

### T-201: 实现详情视图切换逻辑 ✅

- **关联需求**: F-034, AC-123, AC-124
- **优先级**: P2
- **依赖**: T-200 ✅
- **TDD 模式**: 🟢 可选
- **提交**: 88ba705

**描述**：
根据选中的分类，在 NavigationSplitView 的 detail 区域显示对应的设置视图。

**涉及文件**：
- `Chiaki/Features/Settings/SettingsView.swift`

**验收标准**：
- [ ] 选中 general 显示 `GeneralSettingsView`
- [ ] 选中 video 显示 `VideoSettingsView`
- [ ] 选中 audio 显示 `AudioSettingsView`
- [ ] 选中 controller 显示 `ControllerSettingsView`
- [ ] 选中 account 显示 `AccountSettingsView`
- [ ] 选中 consoles 显示 `ConsolesSettingsView`
- [ ] 选中 logs 显示 `LogViewerView`
- [ ] 选中 data 显示 `DataSettingsView`
- [ ] 默认选中 general

**测试方法**：
- macOS 运行，验证切换分类时内容正确更新
- 验证 iOS/tvOS 未受影响

**Review 要点**：
- switch 语句完整覆盖所有 case
- 无 default 分支（保证编译时检查）

---

### T-202: 布局验证与样式调整 ✅

- **关联需求**: F-034, AC-121~AC-125
- **优先级**: P2
- **依赖**: T-201 ✅
- **TDD 模式**: 🟢 可选
- **备注**: 验证通过，无需额外修改

**描述**：
验证整体布局效果，调整侧边栏宽度、间距等样式参数。

**涉及文件**：
- `Chiaki/Features/Settings/SettingsView.swift`

**验收标准**：
- [ ] 侧边栏宽度合适（建议 200-250pt）
- [ ] 内容区域保持原有样式
- [ ] 窗口最小尺寸合理（保持 500x400）
- [ ] 无双层 Tab 视觉混淆
- [ ] 编译无警告

**测试方法**：
- macOS 运行完整测试：
  1. 切换所有设置分类
  2. 调整窗口大小验证响应式
  3. 与 iOS 版本对比，确认功能一致

**Review 要点**：
- 移除 macOS 分支中的 `.padding()` 如果不再需要
- 确认 `DataSettingsView` 正常显示（macOS 专有）

---

## 任务汇总

| 编号 | 名称 | 关联 | 状态 | 提交 |
|------|------|------|------|------|
| T-199 | 定义 SettingsCategory 枚举 | F-034, AC-122 | ✅ | 9f94de7 |
| T-200 | 实现侧边栏列表视图 | F-034, AC-121 | ✅ | 88ba705 |
| T-201 | 实现详情视图切换逻辑 | F-034, AC-123 | ✅ | 88ba705 |
| T-202 | 布局验证与样式调整 | F-034, AC-125 | ✅ | - |

---

## 下一步

F-034 macOS 设置侧边栏导航已完成 (4/4 任务)。

1. 运行 `/devdocs-sync --trace` 同步追溯状态
2. 等待 T-115 设计师资产
3. 规划下一个功能需求

---

*文档由 `/devdocs-dev-workflow` 更新 (2026-02-06)*
