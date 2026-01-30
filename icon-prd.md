# Chiaki Apple App Icon 设计需求文档

**项目**: Chiaki-ng Apple 原生客户端
**用途**: 委托 AI 图像生成工具创建应用图标
**版本**: 1.1
**日期**: 2026-01-30

---

## 1. 项目背景

### 1.1 应用介绍

Chiaki 是一款开源的 **PlayStation 远程游玩客户端**，允许用户通过 WiFi 或互联网在 Apple 设备（iPhone、iPad、Mac、Apple TV）上远程游玩 PlayStation 4/5 游戏。

### 1.2 品牌定位

- **用户群体**: 游戏玩家、PlayStation 主机拥有者、Apple 生态用户
- **产品调性**: 专业、现代、游戏感、科技感
- **核心价值**: 流畅串流、跨平台、开源免费

### 1.3 原版品牌参考

原版 chiaki-ng 已有成熟的视觉识别系统，Apple 版本应**继承并适配** Apple 平台设计规范。

**原版 Logo 特征**:
- 融合 PlayStation 手柄四大按键符号：△ ○ ✕ □
- △ 三角形上方有 WiFi 信号波（代表远程连接）
- ○ 圆形内部有暂停符号 ‖（代表流媒体）
- 几何化、扁平化的现代设计风格

---

## 2. 确定配色方案

### ✅ 采用方案：继承原版

经评估，推荐继承原版 chiaki-ng 配色，理由：

| 因素 | 评估 |
|------|------|
| **品牌一致性** | 用户跨平台迁移时能立即识别 |
| **辨识度** | 黄绿色在 App Store 游戏类中独特醒目 |
| **验证程度** | 原版设计已被社区广泛接受 |
| **现代感** | 渐变背景符合当前 iOS 设计趋势 |

### 配色规格

```
┌─────────────────────────────────────┐
│  背景渐变                            │
│  起点: #A8E063 (亮黄绿)              │
│  终点: #56CCF2 (青蓝)                │
│  方向: 左下 → 右上 (135°)            │
├─────────────────────────────────────┤
│  前景元素                            │
│  主色: #FFFDE7 (象牙白/米白)         │
│  或者: #FFFFFF (纯白)                │
├─────────────────────────────────────┤
│  可选阴影                            │
│  颜色: #000000 @ 10-15% 透明度       │
│  模糊: 8-12px                        │
│  偏移: (0, 4px)                      │
└─────────────────────────────────────┘
```

### 色值速查

| 用途 | 色值 | 预览 |
|------|------|------|
| 渐变起点 | `#A8E063` | 🟢 亮黄绿 |
| 渐变终点 | `#56CCF2` | 🔵 青蓝 |
| 前景主色 | `#FFFDE7` | ⬜ 象牙白 |
| Dark 模式背景 | `#1A1A2E` | ⬛ 深紫灰 |
| Dark 模式前景 | `#CDDC39` | 🟡 亮黄绿 |

---

## 3. 设计产出规格（简化版）

### 3.1 核心交付物

自 macOS Big Sur 起，**iOS 和 macOS 可共用同一源文件**。

| 文件 | 尺寸 | 用途 | 必需 |
|------|------|------|------|
| **AppIcon-Light.png** | 1024×1024 | iOS/iPadOS/macOS 通用 | ✅ 必需 |
| **AppIcon-Dark.png** | 1024×1024 | iOS 18 深色模式 | ✅ 必需 |
| **AppIcon-Tinted.png** | 1024×1024 | iOS 18 着色模式 | ✅ 必需 |
| AppIcon-tvOS-Front.png | 800×480 | tvOS 前景层 | 可选 |
| AppIcon-tvOS-Back.png | 800×480 | tvOS 背景层 | 可选 |
| TopShelf-Wide.png | 2320×720 | tvOS Top Shelf | 可选 |

### 3.2 设计要求

| 规范 | 要求 |
|------|------|
| **画布** | 方形，1024×1024 像素 |
| **圆角** | 不需要，系统自动裁切 |
| **背景** | 必须填满整个画布，无透明区域 |
| **安全边距** | 核心内容距边缘保持 10-15%（约 100px） |
| **格式** | PNG，RGB 色彩模式，无压缩 |

### 3.3 三种模式说明

```
Light (默认)          Dark (深色)           Tinted (着色)
┌──────────┐         ┌──────────┐         ┌──────────┐
│ 渐变背景  │         │ 深色背景  │         │ 中性灰底  │
│ 白色前景  │         │ 亮色前景  │         │ 白色剪影  │
└──────────┘         └──────────┘         └──────────┘
  全彩显示             深色模式下            系统统一着色
```

---

## 4. 核心设计元素

### 4.1 图形构成

保留原版 chiaki-ng 的标志性元素，适度简化：

```
        ╭───╮  ╭───╮
        │   │  │   │     ← WiFi 信号波 (2-3 条弧线)
        ╰───╯  ╰───╯
           ╲  ╱
            ╲╱
            △              ← 三角形 (PlayStation △ 按钮)
           ╱  ╲
          ╱ ○  ╲           ← 圆形 + 暂停符号 ‖
         ╱  ‖   ╲
        ▔▔▔▔▔▔▔▔▔
```

### 4.2 简化建议

若 AI 生成效果不佳，可进一步简化为：
- 仅保留 **带 WiFi 信号的三角形**
- 或 **三角形 + 圆形暂停符号** 的组合

---

## 5. AI 生成提示词

### 5.1 Light 模式（主图标）

**英文版** (Midjourney / DALL-E / Stable Diffusion):

```
App icon for "Chiaki" - a PlayStation Remote Play streaming app.

Design:
- Geometric hollow triangle symbol with 2 WiFi signal arcs above it
- Small circle with pause bars (||) overlapping the triangle
- Gradient background: lime green (#A8E063) to cyan (#56CCF2), diagonal 135°
- Foreground elements in cream white (#FFFDE7)
- Clean, minimal, flat design, no text
- Square 1024x1024 canvas, content centered with 10% margin

Style: Modern iOS app icon, gaming category, professional and playful
Output: 1024x1024 PNG, RGB
```

**中文版**:

```
为 "Chiaki" PlayStation 远程游玩应用设计图标。

设计要求：
- 几何空心三角形，顶部有 2 条 WiFi 信号弧线
- 三角形上叠加带暂停符号(‖)的小圆形
- 背景：黄绿(#A8E063)到青蓝(#56CCF2)的 135° 对角渐变
- 前景元素使用象牙白(#FFFDE7)
- 干净、极简、扁平设计，无文字
- 1024×1024 方形画布，内容居中，边距 10%

风格：现代 iOS 应用图标，游戏类，专业且有趣
输出：1024×1024 PNG，RGB 色彩
```

### 5.2 Dark 模式

```
Dark mode variant of Chiaki app icon:
- Deep purple-gray background (#1A1A2E to #16213E gradient)
- Bright lime-yellow foreground elements (#CDDC39)
- Same WiFi-triangle and pause-circle motif
- Subtle outer glow on foreground (cyan #56CCF2, 20% opacity)
- 1024x1024 PNG
```

### 5.3 Tinted 模式

```
Tinted/monochrome Chiaki app icon for iOS system tinting:
- Solid medium gray background (#808080)
- Pure white (#FFFFFF) foreground silhouette
- Same WiFi-triangle and pause-circle design
- High contrast, clear edges, no gradients in foreground
- 1024x1024 PNG
```

---

## 6. 参考资源

### 6.1 原版素材

```
chiaki-ng/gui/chiaking.png                                    # 原版 App Icon
chiaki-ng/assets/official-artwork/Chiaki-ng logo color.png    # 官方彩色 Logo
chiaki-ng/assets/official-artwork/Chiaki-ng logo white.png    # 白色版
chiaki-ng/assets/official-artwork/Chiaki-ng logo black.png    # 黑色版
```

### 6.2 Apple 设计指南

- [App Icons - Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple Design Resources](https://developer.apple.com/design/resources/)

---

## 7. 验收清单

生成后请检查：

- [ ] **清晰度**: 1024×1024 图标锐利清晰
- [ ] **可识别性**: 缩小到 60×60 时核心元素仍可辨认
- [ ] **配色一致**: 与原版 chiaki-ng 品牌协调
- [ ] **三模式完整**: Light / Dark / Tinted 三版齐全
- [ ] **无透明区**: 背景完全填满画布
- [ ] **无文字**: 图标不包含任何文字
- [ ] **无版权问题**: 未使用 PlayStation 官方 Logo

---

## 8. 文件提交

将生成的图标放入 `generated-icons/` 目录：

```
generated-icons/
├── AppIcon-Light.png      # 1024×1024 默认
├── AppIcon-Dark.png       # 1024×1024 深色
└── AppIcon-Tinted.png     # 1024×1024 着色
```

Xcode 会自动从 1024×1024 源文件生成所有所需尺寸。

---

*文档版本 1.1 - 简化产出要求，确定配色方案*
