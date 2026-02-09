# 洞察归档 - 已转化洞察

> **归档时间**: 2026-02-08
> **归档原因**: 洞察已转化为需求并完成实现
> **归档版本**: M11 + M12 + M13 + M14 + M15

---

## 归档洞察汇总

| 范围 | 编号 | 数量 | 转化目标 |
|------|------|------|----------|
| SwiftUI 架构 | INS-001 ~ INS-005 | 5 | F-010 ~ F-014 |
| Phase 11 生产就绪 | INS-006 ~ INS-010 | 5 | F-015 ~ F-018 |
| 日志系统 | INS-011 ~ INS-016 | 6 | F-019 |
| 手柄操作 | INS-017 ~ INS-022 | 6 | F-020 |
| GC 框架评估 | INS-023 ~ INS-026 | 4 | F-021 |
| StreamingOverlay | INS-027 | 1 | T-135 |
| 手柄 UI/UX | INS-028 ~ INS-031 | 4 | F-022 |
| HDR 配置审查 | INS-032 ~ INS-033 | 2 | F-024 |
| HDR 渲染管线 | INS-034 ~ INS-038 | 5 | F-025 |
| 渲染模块封装 | INS-039 ~ INS-041 | 3 | F-026 |
| UI 层架构 | INS-042 ~ INS-046 | 5 | F-027 |
| REVIEW_SUMMARY | INS-047 ~ INS-051 | 5 | F-028~F-030 |
| macOS 设置布局 | INS-052 | 1 | F-034 |
| Slider 布局审查 | INS-053 ~ INS-055 | 3 | F-035 |
| HostListView 审查 | INS-056 ~ INS-061 | 6 | F-036 |
| AddHostView 审查 | INS-062 ~ INS-067 | 6 | F-037 |
| ConsolePinView 审查 | INS-068 ~ INS-071 | 4 | F-037 |
| Bridge 安全审查 | INS-072 ~ INS-076 | 5 | F-038 |

---

## SwiftUI 架构洞察 (INS-001 ~ INS-005)

**收集时间**: 2026-01-27 | **来源**: 🎨 UI/UX 审查 & 📄 技术审计

### INS-001: API 现代化：全面迁移至 iOS 17+ 标准 ✅
- **建议**: 全局迁移至 `.foregroundStyle()` 和 `.clipShape()`
- **转化**: F-010 / AC-035, AC-036, AC-037

### INS-002: 状态管理归一化 ✅
- **建议**: 统一迁移至 `@Observable`
- **转化**: F-011 / AC-038

### INS-003: 架构解耦：重构 `StreamingViewModel` ✅
- **建议**: 拆分出统计管理和输入映射模块
- **转化**: F-012 / AC-039, AC-040

### INS-004: 交互精致化：优化动画曲线与原生感 ✅
- **建议**: 使用 `.spring()` 或 `.snappy` 动画曲线
- **转化**: F-013 / AC-041, AC-043

### INS-005: 未来适配：引入 Liquid Glass (iOS 26+) ✅
- **建议**: 在支持的设备上启用 `glassEffect`
- **转化**: F-014 / AC-042

---

## Phase 11 生产就绪洞察 (INS-006 ~ INS-010)

**收集时间**: 2026-01-27 | **来源**: 📄 产品路线图 (Beta 1 冲刺)

### INS-006: i18n 本地化深度补全 (xcstrings) ✅
- **建议**: 全面迁移至 `Localizable.xcstrings`
- **转化**: F-015 / AC-044

### INS-007: 异常恢复：增强重连机制 ✅
- **建议**: 引入 `NWPathMonitor` 并结合 RUDP 保持逻辑
- **转化**: F-016 / AC-045

### INS-008: 能效优化：Metal 渲染器节能调优 ✅
- **建议**: 实现 Variable Refresh Rate (VRR)
- **转化**: F-017 / AC-046

### INS-009: 生产构建元数据完善 (Metadata) ✅
- **建议**: 补全 Info.plist 隐私说明
- **转化**: F-018 / AC-047, AC-048

### INS-010: 触觉反馈 2.0：语义化 haptics 精调 ✅
- **建议**: 为核心操作提供一致的触觉反馈体验
- **转化**: T-116

---

## 日志系统洞察 (INS-011 ~ INS-016)

**收集时间**: 2026-01-28 | **来源**: 💡 内部反馈

### INS-011: 日志文件持久化 ✅
- **建议**: 将日志实时写入文件
- **转化**: F-019 / AC-049

### INS-012: 日志文件轮换策略 ✅
- **建议**: 按大小（5MB/文件）+ 按数量（保留最近 7 个文件）
- **转化**: F-019 / AC-050

### INS-013: 一键导出诊断包 ✅
- **建议**: 提供"导出诊断包"功能
- **转化**: F-019 / AC-051

### INS-014: 崩溃日志自动捕获 ✅
- **建议**: 集成简单的崩溃捕获
- **转化**: F-019 / AC-052

### INS-015: 敏感信息脱敏 ✅
- **建议**: 导出时自动脱敏
- **转化**: F-019 / AC-053

### INS-016: 增强核心流程日志覆盖 ✅
- **建议**: 在关键流程中增加详细日志
- **转化**: F-019 / AC-054

---

## 手柄操作洞察 (INS-017 ~ INS-022)

**收集时间**: 2026-01-30 | **来源**: 💡 内部反馈 + 🎨 UI/UX 审查

### INS-017: 流媒体控制菜单无焦点管理 ✅
- **建议**: 添加焦点枚举和 `.focused()` 修饰符
- **转化**: F-020 / AC-055

### INS-018: tvOS 菜单按钮无焦点反馈 ✅
- **建议**: 创建 `FocusableButtonStyle`
- **转化**: F-020 / AC-056

### INS-019: 控制菜单无焦点陷阱 ✅
- **建议**: 使用 `focusSection()` 实现焦点隔离
- **转化**: F-020 / AC-057

### INS-020: tvOS 方向键导航不完整 ✅
- **建议**: 添加 `onMoveCommand` 处理
- **转化**: F-020 / AC-058

### INS-021: 手柄快捷操作缺失 ✅
- **建议**: 添加组合键：PS+Options 打开菜单
- **转化**: F-020 / AC-059

### INS-022: 控制菜单关闭后焦点丢失 ✅
- **建议**: 实现焦点记忆和恢复逻辑
- **转化**: F-020 / AC-060

---

## GC 框架评估洞察 (INS-023 ~ INS-026)

**收集时间**: 2026-01-30 | **来源**: 📄 技术审计

### INS-023: 启用 DualSense 自适应扳机 ✅
- **建议**: 实现 `GCDualSenseAdaptiveTriggers` 支持
- **转化**: F-021 / AC-061

### INS-024: 启用触控板位置追踪 ✅
- **建议**: 映射触控板 X/Y 坐标
- **转化**: F-021 / AC-062

### INS-025: 统一 Haptics 引擎实例 ✅
- **建议**: 由 HapticsManager 统一管理
- **转化**: F-021 / AC-063

### INS-026: 添加控制器电池电量显示 ✅
- **建议**: 在 UI 中显示连接手柄的电量
- **转化**: F-021 / AC-064

---

## StreamingOverlay 洞察 (INS-027)

**收集时间**: 2026-01-30 | **来源**: 💡 内部反馈

### INS-027: StreamingOverlay HDR 标志 ✅
- **建议**: 在分辨率旁添加 "HDR" 徽章
- **转化**: T-135

---

## 手柄 UI/UX 洞察 (INS-028 ~ INS-031)

**收集时间**: 2026-01-30 | **来源**: 🎨 UI/UX 审查

### INS-028: 主机快速操作栏 ✅
- **建议**: 为选中的主机卡片添加底部快速操作栏
- **转化**: F-022 / AC-065

### INS-029: 流媒体中音量快捷调节 ✅
- **建议**: 添加手柄快捷键：PS+L2/R2 调节音量
- **转化**: F-022 / AC-066

### INS-030: PIN 输入数字键盘优化 ✅
- **建议**: 创建手柄友好的数字键盘视图
- **转化**: F-022 / AC-067

### INS-031: 设置快捷入口 ✅
- **建议**: 在控制菜单中添加"快速设置"入口
- **转化**: F-022 / AC-068

---

## HDR 配置审查洞察 (INS-032 ~ INS-033)

**收集时间**: 2026-02-04 | **来源**: 🔍 外部参考 + 💡 内部反馈

### INS-032: HDR 亮度/EDR 强度调整 ✅
- **建议**: 在"设置-视频"中添加 EDR 强度滑块（0.5x - 2.0x）
- **转化**: F-024 / AC-076, AC-077

### INS-033: 色彩空间选项简化 ✅
- **建议**: HDR 开启时隐藏色彩空间选项；HDR 关闭时仅显示 SDR 选项
- **转化**: F-024 / AC-078

---

## HDR 渲染管线洞察 (INS-034 ~ INS-038)

**收集时间**: 2026-02-04 | **来源**: 📄 文档调研 (GPT/Gemini 方案对比)

### INS-034: Rec.2020 → Display P3 色域映射 ✅
- **建议**: 在 Shader 中实现色域转换矩阵，保留高饱和度细节
- **转化**: F-025 / AC-080

### INS-035: 动态 EDR Headroom 监听与传递 ✅
- **建议**: 监听 `CAMetalLayer.wantsExtendedDynamicRangeContent` 变化并传递至 Shader
- **转化**: F-025 / AC-081, AC-082

### INS-036: HDR 元数据抖动抑制 ✅
- **建议**: 使用滑动窗口平均或指数平滑抑制 EDR Headroom 抖动
- **转化**: F-025 / AC-083

### INS-037: 可选 Tone Mapping 降级路径 ✅
- **建议**: 当 HDR 不可用时，提供 ACES Filmic Tone Mapping 降级选项
- **转化**: F-025 / AC-084

### INS-038: 渲染性能指标扩展 ✅
- **建议**: 导出 GPU 时间、帧耗时、色域/EDR 信息至统计面板
- **转化**: F-025 / AC-085

---

## 渲染模块封装洞察 (INS-039 ~ INS-041)

**收集时间**: 2026-02-04 | **来源**: 💡 架构审查

### INS-039: 渲染器协议抽象 ✅
- **建议**: 定义 `VideoRenderer` 协议，支持 Metal 外的其他渲染器
- **转化**: F-026 / AC-086

### INS-040: 分离 MTKViewDelegate ✅
- **建议**: 创建 `MetalViewCoordinator` 解耦 MTKViewDelegate 与渲染器
- **转化**: F-026 / AC-087

### INS-041: 统一 HDR 配置入口 ✅
- **建议**: 创建 `HDRConfiguration` 结构体统一管理 HDR 相关配置
- **转化**: F-026 / AC-088, AC-089

---

## UI 层架构洞察 (INS-042 ~ INS-046)

**收集时间**: 2026-02-04 | **来源**: 💡 架构审查

### INS-042: Views 直接访问 Singleton Manager 违规 ✅
- **建议**: 所有 View 通过 ViewModel 访问数据/服务层，避免直接访问 `.shared`
- **转化**: F-027 / AC-090, AC-091, AC-092

### INS-043: Settings Views 缺少 ViewModel 层 ✅
- **建议**: 为 Settings Views 创建 ViewModel，封装 SettingsStore 访问
- **转化**: F-027 / AC-093

### INS-044: 业务逻辑泄露到 View 层 ✅
- **建议**: 将 View 层的业务逻辑迁移至 ViewModel
- **转化**: F-027 / AC-094

### INS-045: 核心 Manager 缺少协议抽象 ✅
- **建议**: 为 Manager 类定义协议，便于 Mock 测试
- **转化**: F-027 / AC-095

### INS-046: UI 模块集中管理建议 ✅
- **建议**: 在 UI/ 目录集中管理共享组件
- **转化**: F-027 / AC-096

---

## REVIEW_SUMMARY 洞察 (INS-047 ~ INS-051)

**收集时间**: 2026-02-05 | **来源**: 💡 REVIEW_SUMMARY

### INS-047: 解码重排策略优化 ✅
- **建议**: ⏸️ 暂缓 - 修改重排策略风险较高，当前固定策略虽有延迟但稳定性好
- **转化**: 暂缓

### INS-048: HDR 配置完全落地 ✅
- **建议**: 完整实现 HDR 端到端流程
- **转化**: F-028 / AC-097~AC-100

### INS-049: 全局单例收敛 ✅
- **建议**: ✅ 已完成 (M12) - T-159~T-170 完成协议化与解耦
- **转化**: M12 已完成

### INS-050: MainActor 边界标注 ✅
- **建议**: 标注 `@MainActor` 避免线程安全问题
- **转化**: F-029 / AC-101~AC-103

### INS-051: Debug 输出统一日志 ✅
- **建议**: 将 `print()` 迁移至 `Logger`
- **转化**: F-030 / AC-104~AC-106

---

## macOS 设置布局洞察 (INS-052)

**收集时间**: 2026-02-06 | **来源**: 💡 内部反馈 (UI/UX 审查)

### INS-052: macOS 设置子 Tab 改为侧边栏导航 ✅
- **建议**: 使用 `NavigationSplitView` 实现侧边栏导航，符合 macOS HIG
- **转化**: F-034 / AC-121~AC-125

---

## Slider 布局审查洞察 (INS-053 ~ INS-055)

**收集时间**: 2026-02-06 | **来源**: 🎨 UI/UX 审查

### INS-053: Slider `.tint()` 样式不一致 ✅
- **建议**: 统一 Slider 样式为 `.tint(.accentColor)`
- **转化**: F-035 / AC-126

### INS-054: 部分 Slider 缺少无障碍标签 ✅
- **建议**: 为所有 Slider 添加 `.accessibilityLabel()`
- **转化**: F-035 / AC-127

### INS-055: 百分比数值格式不统一 ✅
- **建议**: 统一使用 `String(format: "%.0f%%", value * 100)`
- **转化**: F-035 / AC-128

---

## HostListView 审查洞察 (INS-056 ~ INS-061)

**收集时间**: 2026-02-06 | **来源**: 🎨 UI/UX 审查

### INS-056: Wake Up 按钮触摸区域偏小 ✅
- **建议**: 为小按钮添加 `.contentShape(Rectangle()).frame(minWidth: 44, minHeight: 44)`
- **转化**: F-036 / AC-129

### INS-057: 列表加载状态位置不佳 ✅
- **建议**: 使用 `.overlay()` 居中显示加载状态
- **转化**: F-036 / AC-130

### INS-058: 运行中应用颜色对比度 ✅
- **建议**: 使用更明显的颜色（如 `.green` 或 `.mint`）
- **转化**: F-036 / AC-131

### INS-059: 状态徽章无障碍标签 ✅
- **建议**: 为状态徽章添加语义化的 `.accessibilityLabel()`
- **转化**: F-036 / AC-132

### INS-060: 空状态视图动画 ✅
- **建议**: ⏳ 待定 (P3)
- **转化**: 待定

### INS-061: 批量删除确认信息 ✅
- **建议**: ⏳ 待定 (P3)
- **转化**: 待定

---

## AddHostView 审查洞察 (INS-062 ~ INS-067)

**收集时间**: 2026-02-07 | **来源**: 🎨 UI/UX 审查

### INS-062: AddHostView 地址输入缺少格式验证 ✅
- **建议**: 添加实时格式验证，提示无效 IP/域名
- **转化**: F-037 / AC-133

### INS-063: ConsolePinView Singleton 直接访问 ✅
- **建议**: 通过 ViewModel 访问 PinManager，避免直接访问 `.shared`
- **转化**: F-037 / AC-134

### INS-064: ConsolePinEntryView 错误提示不够醒目 ✅
- **建议**: 使用 `.foregroundStyle(.red)` + `.bold()` 强调错误提示
- **转化**: F-037 / AC-135

### INS-065: PINDisplay 缺少无障碍支持 ✅
- **建议**: 为 PIN 输入框添加 `.accessibilityLabel()` 和 `.accessibilityValue()`
- **转化**: F-037 / AC-136

### INS-066: AddHostView macOS 表单样式缺失 ✅
- **建议**: 使用 `.formStyle(.grouped)` 为 macOS 添加表单样式
- **转化**: F-037 / AC-137

### INS-067: AddHostView 标题布局优化 ✅
- **建议**: 使用 `Spacer(minLength: 0).frame(maxHeight: 0)` 减少 macOS Sheet 顶部空白
- **转化**: F-037 / AC-138

---

## ConsolePinView 审查洞察 (INS-068 ~ INS-071)

**收集时间**: 2026-02-07 | **来源**: 🎨 UI/UX 审查

### INS-068: ConsolePinView placeholder 文本易混淆 ✅
- **建议**: 将 placeholder "PIN" 改为 "Enter PIN"，避免与输入内容混淆
- **转化**: F-037 / AC-139

### INS-069: ConsolePinView 底部说明本地化问题 ✅
- **建议**: 将底部说明文本移至 `Localizable.xcstrings`
- **转化**: F-037 / AC-140

### INS-070: ConsolePinView macOS 表单样式缺失 ✅
- **建议**: 使用 `.formStyle(.grouped)` 为 macOS 添加表单样式
- **转化**: F-037 / AC-141

### INS-071: ConsolePinView 标题布局优化 ✅
- **建议**: 使用 `Spacer(minLength: 0).frame(maxHeight: 0)` 减少 macOS Sheet 顶部空白
- **转化**: F-037 / AC-142

---

## Bridge 安全审查洞察 (INS-072 ~ INS-076)

**收集时间**: 2026-02-08 | **来源**: 💡 Bridge 安全审查

### INS-072: DiscoveryService deinit 未调用 stopDiscovery() ✅
- **建议**: 在 `deinit` 中调用 `stopDiscovery()` 确保资源释放
- **转化**: F-038 / AC-143

### INS-073: ChiakiRegist strdup 早退路径内存泄漏 ✅
- **建议**: 确保所有 `strdup` 内存在错误路径中正确释放
- **转化**: F-038 / AC-144

### INS-074: Bridge 对象状态更新线程边界不统一 ✅
- **建议**: 统一使用 `DispatchQueue.main.async` 更新 Bridge 对象状态
- **转化**: F-038 / AC-145

### INS-075: ChiakiLogBridge.getLogPointer() 逃逸临时指针 ✅
- **建议**: 重构 `getLogPointer()` 避免返回临时字符串指针
- **转化**: F-038 / AC-146

### INS-076: 回调 userdata 所有权策略文档化 ✅
- **建议**: 在代码注释中明确 `userdata` 的所有权策略
- **转化**: F-038 / AC-147

---

## 归档统计

| 指标 | 数量 |
|------|------|
| 归档洞察 | 76 |
| 转化功能点 | 29 |
| 转化任务 | 1 |
| 转化验收标准 | 114 |

---

*归档操作由 `/devdocs-sync --archive` 执行*
