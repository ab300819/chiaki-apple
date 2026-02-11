# 新功能开发日志

---

## F-042: libplacebo 渲染后端集成 (2026-02-10)

### 来源

INS-088 ~ INS-091 (自有渲染画质不理想 + libplacebo Metal 后端并行推进)
关联: F-041（降级为兼容模式）, INS-085（libplacebo Metal 后端可行性确认）

### 新增内容

| 类型 | 编号 | 描述 |
|------|------|------|
| 功能点 | F-042 | libplacebo 渲染后端集成 |
| 用户故事 | US-042 | libplacebo 替代自有 shader、MoltenVK 初始路径、后端切换 |
| 验收标准 | AC-170 ~ AC-191 | 22 条 |
| 单元测试 | UT-060 ~ UT-066 | 7 组 (28 个用例) |
| 集成测试 | IT-020 ~ IT-022 | 3 组 (12 个用例) |
| E2E 测试 | E2E-015 ~ E2E-016 | 2 组 (8 个用例) |
| 开发任务 | T-243 ~ T-250 | 8 个 (M19 里程碑) |

### 影响范围

- **新增模块**: PlaceboVideoRenderer、Placebo 桥接层（PlaceboBridge.h + PlaceboContext.m + PlaceboTypes.swift）
- **新增依赖**: libplacebo.xcframework（动态, LGPL 2.1）、MoltenVK.xcframework（动态, Apache 2.0）
- **新增脚本**: scripts/build-libplacebo.sh（交叉编译）
- **修改文件**: StreamSettings.swift（RenderBackend 枚举）、StreamingViewModel.swift（后端工厂方法）
- **修改文件**: VideoSettingsView.swift（后端选择 Picker）、StreamingOverlay.swift（后端名称显示）
- **不变模块**: VideoRenderer 协议、MetalVideoRenderer（保留为兼容模式）
- **回归风险**: MoltenVK iOS Vulkan 能力子集、shader 首次编译延迟、IOSurface 零拷贝生命周期

### 方案决策记录

| 方案 | 决策 | 原因 |
|------|------|------|
| 继续扩展 Metal 原生 shader | ❌ 降级为兼容模式 | 功能追赶 libplacebo 不现实，BUG-020 暴露自维护 shader 脆弱性 |
| **libplacebo + MoltenVK (Phase 1)** | ✅ 初始路径 | 可立即开始，验证集成架构和画质效果 |
| **libplacebo Metal 后端 (Phase 2)** | ✅ 迁移目标 | 消除翻译层，最优性能，正在并行开发 |

### 分阶段策略

- **Phase 1**: MoltenVK (Vulkan) 路径集成 libplacebo → M19 里程碑
- **Phase 2**: 自研 Metal 后端替换 MoltenVK → 后续里程碑
- **Phase 3**: libplacebo 作为默认，Metal Native 作为轻量/兼容模式

### 关联文档

- [01-requirements.md](01-requirements.md) — F-042, US-042, AC-170~191
- [02-system-design.md](02-system-design.md) — §23 libplacebo 渲染后端集成
- [03-test-cases.md](03-test-cases.md) — §29 F-042 测试用例
- [04-dev-tasks.md](04-dev-tasks.md) — M19 里程碑 (T-243~T-250)
- [05-insights.md](05-insights.md) — INS-088~091（已确认）, INS-085（Metal 后端可行性）

---

## F-041: Metal 原生高质量视频滤波管线 (2026-02-10)

### 来源

INS-082 ~ INS-084 (深度技术调研：Metal 渲染管线 vs chiaki-ng/libplacebo 对比分析)
关联 Bug: BUG-016（运动模糊残留）, BUG-017（窗口最大化模糊残留）

### 新增内容

| 类型 | 编号 | 描述 |
|------|------|------|
| 功能点 | F-041 | Metal 原生高质量视频滤波管线 |
| 用户故事 | US-041 | Bicubic 上采样 + CAS 锐化 + 去色带 + 预设绑定 + 渲染诊断 |
| 验收标准 | AC-158 ~ AC-169 | 12 条 |
| 单元测试 | UT-055 ~ UT-059 | 5 组 (20 个用例) |
| 集成测试 | IT-019 | 1 组 (5 个用例) |
| E2E 测试 | E2E-014 | 1 组 (4 个用例) |
| 开发任务 | T-236 ~ T-242 | 7 个 (M18 里程碑) |

### 影响范围

- **修改文件**: VideoShaders.txt（新增 3 个滤波函数 + Uniforms 扩展）
- **修改文件**: MetalVideoRenderer.swift（FilterConfig + uniform 映射）
- **新增文件**: VideoFilterConfig.swift（滤波配置模型）
- **修改文件**: StreamingViewModel.swift（预设→渲染参数绑定）
- **修改文件**: StreamStatistics.swift（诊断指标）
- **修改文件**: StreamingOverlay.swift（诊断显示）
- **回归风险**: HDR 路径（EDR 值域下 CAS/去色带参数缩放）、Uniform struct 对齐

### 方案决策记录

| 方案 | 决策 | 原因 |
|------|------|------|
| libplacebo + MoltenVK | ❌ 排除 | 翻译层 5-15% 开销、LGPL 许可证、iOS/tvOS 不原生 |
| MetalFX Spatial Scaler | ❌ 排除 | 需额外 render pass、不支持 YUV 直接处理 |
| **Metal 原生 shader** | ✅ 采用 | 零依赖、全平台统一、单次 fragment shader、保持零拷贝 |

### 关联文档

- [01-requirements.md](01-requirements.md) — F-041, US-041, AC-158~169
- [02-system-design.md](02-system-design.md) — §22 Metal 原生高质量视频滤波管线
- [03-test-cases.md](03-test-cases.md) — §28 F-041 测试用例
- [04-dev-tasks.md](04-dev-tasks.md) — M18 里程碑 (T-236~T-242)
- [05-insights.md](05-insights.md) — INS-082~084（已确认）, INS-085（不推荐）

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
