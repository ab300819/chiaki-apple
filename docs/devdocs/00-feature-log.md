# 新功能开发日志

---

## F-040: 控制器架构分层重构 (2026-02-10)

### 来源

INS-078 ~ INS-081 (BUG-018/019 修复经验 + chiaki-ng SDL/HIDAPI 参考)

### 新增内容

| 类型 | 编号 | 描述 |
|------|------|------|
| 功能点 | F-040 | 控制器架构分层重构 |
| 用户故事 | US-040 | Provider 协议分离、HID 优先策略 |
| 验收标准 | AC-151 ~ AC-157 | 7 条 |
| 单元测试 | UT-049 ~ UT-054 | 6 组 (24 个用例) |
| 集成测试 | IT-017 ~ IT-018 | 2 组 (7 个用例) |
| E2E 测试 | E2E-013 | 1 组 (4 个用例) |
| 开发任务 | T-229 ~ T-235 | 7 个 (M17 里程碑) |

### 影响范围

- **新增模块**: ControllerInputProvider (协议), GameControllerProvider, DualSenseHIDProvider, DualShock4HIDProvider, ControllerOrchestrator
- **重构模块**: DualSenseHIDManager → DualSenseHIDProvider
- **删除模块**: ControllerManager (由 ControllerOrchestrator 替代)
- **修改集成**: StreamingViewModel (切换到 Orchestrator)
- **回归风险**: iOS/tvOS 标准输入路径、macOS DualSense rumble

### 关联文档

- [01-requirements.md](01-requirements.md) — F-040, US-040, AC-151~157
- [02-system-design.md](02-system-design.md) — §21 控制器架构分层重构
- [03-test-cases.md](03-test-cases.md) — §27 F-040 测试用例
- [04-dev-tasks.md](04-dev-tasks.md) — M17 里程碑 (T-229~T-235)
- [05-insights.md](05-insights.md) — INS-078~081

---
