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

### INS-077: iPhone 串流横屏锁定 ✅ 已确认

- **收集时间**: 2026-02-09
- **来源**: 🔍 外部参考 (PS Remote Play / Steam Link / Moonlight 竞品分析) + 💡 内部反馈
- **优先级**: P1
- **现状**: StreamingView 无运行时方向锁定，iPhone 竖屏时体验差
- **建议**: 串流画面默认锁定横屏（Landscape Left/Right），退出恢复
- **参考**: Steam Link / Moonlight 均为纯横屏；PS Remote Play 支持竖屏但默认横屏
- **状态**: ✅ 已确认 → F-039 (US-039, AC-148~AC-150)

### INS-078: 控制器输入层分离（Input Provider 协议） ✅ 已确认

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈 (BUG-018/019 修复暴露架构问题)
- **参考**: chiaki-ng SDL controllermanager.cpp 分层设计
- **优先级**: P1
- **现状**: ControllerManager 800+ 行单体类，混合输入读取、设备管理、反馈输出
- **建议**: 定义 `ControllerInputProvider` 协议，每种输入源独立实现。ControllerManager 降级为设备编排器
- **影响范围**: ControllerManager、DualSenseHIDManager、VirtualControllerInput、StreamingViewModel
- **状态**: ✅ 已确认 → F-040

### INS-079: HID 优先、GameController Fallback 策略 ✅ 已确认

- **收集时间**: 2026-02-10
- **来源**: 💡 BUG-018/019 根因分析 + 🔍 chiaki-ng SDL/HIDAPI 参考
- **参考**: DualSense HID 协议; chiaki-ng SDL 优先策略
- **优先级**: P1
- **现状**: GameController 作为主通道，HID 仅 macOS 补丁。PS button/rumble 在 macOS BT 下 GameController 不工作
- **建议**: 对已知 VID/PID 手柄优先使用 IOKit HID Provider，GameController 作为通用 fallback，两者非排他共存
- **影响范围**: ControllerManager、DualSenseHIDManager、设备检测逻辑
- **状态**: ✅ 已确认 → F-040

### INS-080: Rumble/Feedback 输出统一封装 ✅ 已确认

- **收集时间**: 2026-02-10
- **来源**: 💡 内部反馈 (rumble 4 层 fallback 散布各处)
- **参考**: chiaki-ng `SDL_GameControllerRumble()` 统一入口
- **优先级**: P1
- **现状**: rumble 路径: macOS HID → GCDeviceHaptics → CoreHaptics → HapticsManager，4 种路径分布在多个文件
- **建议**: 定义 `ControllerFeedbackOutput` 协议，每个 Provider 实现自己的反馈输出，Orchestrator 路由
- **影响范围**: ControllerManager.applyRumble()、DualSenseHIDManager、HapticsManager
- **状态**: ✅ 已确认 → F-040

### INS-081: 扩展 HID 支持到 DualShock 4 ✅ 已确认

- **收集时间**: 2026-02-10
- **来源**: 🔍 chiaki-ng 支持 DS4 + DualSense HID 模式
- **参考**: DualShock 4 HID 协议, VID 0x054C / PID 0x05C4 (v1), 0x09CC (v2)
- **优先级**: P2
- **现状**: 仅支持 DualSense HID，DualShock 4 在 macOS 同样存在 GameController 限制
- **建议**: 在 Provider 架构基础上新增 DualShock4HIDProvider，只需实现不同的 HID 报文格式
- **影响范围**: 新文件 DualShock4HIDManager.swift
- **状态**: ✅ 已确认 → F-040

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

---

## 统计

| 指标 | 数量 |
|------|------|
| 总洞察 | 81 |
| ✅ 已转化完成 | 74 |
| 🔄 已确认待实现 | 5 (INS-077~081) |
| ⏸️ 暂缓 | 1 (INS-047) |
| ⏳ 待定 | 2 (INS-060, INS-061) |

---

*文档更新 (2026-02-10): 新增 INS-078~081 控制器架构分层设计洞察*
