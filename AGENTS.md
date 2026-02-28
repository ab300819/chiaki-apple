<!-- 由 /agent-memory 生成，请通过该命令更新 -->

# Chiaki Apple

## 技术栈

- Swift 5 + SwiftUI（Observation / `@MainActor`），辅以 Objective-C/C bridge
- 平台：iOS 17+、macOS 14+、tvOS 17+
- 核心依赖：`chiaki-ng`（libchiaki）、Metal（默认渲染）、libplacebo + MoltenVK（可选）
- 工程形态：单一 Xcode Scheme `Chiaki`，测试框架为 Swift Testing

## 架构决策

- ADR-Media-001：渲染通过 `VideoRenderer` 协议抽象，libplacebo 初始化失败时回退 Metal。
- ADR-Bridge-001：C API 通过 ObjC 封装（`PlaceboContext.m` / `ChiakiBridge.h`）后暴露给 Swift。
- ADR-License-001：libplacebo 以动态 framework 集成，保持 LGPL 合规。

## 领域术语

| 术语 | 含义 |
|------|------|
| Host | 可连接的 PS5/PS4 主机实体 |
| Session | 一次 Remote Play 串流会话生命周期 |
| Renderer Backend | 视频渲染后端实现（Metal Native / libplacebo） |
| Placebo Context | libplacebo/Vulkan 初始化与资源生命周期管理层 |
| Fallback | 首选渲染后端失败后自动切回 Metal 的机制 |

## 当前状态

- 活跃：BUG-021 libplacebo 渲染链路修复（当前阻塞：应用启动失败 / 回退到 Metal）
- 下一步：修复 libplacebo 初始化失败并验证日志出现 `libplacebo init success`（不再 fallback）
- 进度：M19（T-243~T-250）已完成，后续通过 BUG 修复推进（当前至 BUG-026）

## 命令

- 依赖构建：`make setup && make`
- libplacebo 构建：`make libplacebo`
- macOS 构建：`xcodebuild build -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS'`
- macOS 测试：`xcodebuild test -project Chiaki.xcodeproj -scheme Chiaki -destination 'platform=macOS'`

## 约定

- 提交：`feat(scope):` / `fix(scope):` / `chore(scope):`，并带 `T-XXX` 或 `BUG-XXX`
- 追溯：代码与测试使用 `@requirement/@satisfies/@verifies/@testcase`
- 日志：统一使用 `logInfo/logWarning/logError`，避免 `print`

## 详细文档

完整 DevDocs 位于 `docs/devdocs/`：`01-requirements.md`、`02-system-design.md`、`03-test-cases.md`、`04-dev-tasks.md`、`05-bugfix-log.md`。
