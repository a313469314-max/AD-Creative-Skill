---
name: AD-Creative-Skill
description: >
  面向游戏买量参考视频的通用素材处理技能。适用于用户调用
  $AD-Creative-Skill、single 或 mix 来处理新的参考视频、
  生成关键帧联系表、创建素材文件夹、产出 product-brief.md、拆解游戏广告钩子、
  将参考结构映射到自己的产品，或建立故事方向池。支持 single 处理单条参考视频，
  也支持 mix 将多条同方向视频汇总到同一个文件夹中分析。
---

# AD Creative Skill

使用这个技能把游戏买量参考视频整理成结构清晰、便于复查的创意分析素材包。

命令模式：

- `single`：一条参考视频，对应一个素材文件夹。
- `mix`：多条同方向参考视频，对应一个方向级素材文件夹。

两种模式都以代码流程为先。先运行内置脚本，再进行 AI 写作。优先使用本技能目录下的 `scripts/`；如果你正在克隆仓库里工作，根目录下的 `scripts/` 也等价。给人看的文件放在素材根目录，自动化辅助文件放在 `_system-review/`。

## 路由规则

当用户只提供一条新参考视频，或者没有明确说明多条视频属于同一个共享方向时，使用 `single`。

当用户明确表示多条视频属于同一个方向、同一种 hook、同一个批次，或者需要放在一起分析时，使用 `mix`。

如果语义不明确，默认使用 `single`。

## 强约束

- 开始写分析前，先完成代码侧素材准备。
- 默认复制源视频。只有用户明确要求移动原文件时，才使用 `-Move`。
- 原始视频和关键帧联系表都保留在素材根目录。
- 产品信息放在 `product-brief.md`。
- metadata、frame index、manifest 和 AI input pack 统一放在 `_system-review/`。
- 做产品映射时必须参考产品信息。如果产品信息缺失，或者仍然含有 TODO，不要编造产品事实；列出缺失问题，并把产品映射标记为待补充。
- 第一阶段先产出故事方向池。在用户选定具体方向之前，不要创建 production storyboard、prompt 或 `script-*` 文件夹。
- 将“选方向”和“做完成稿”拆开：selection 只负责记录选中的方向，completion 才负责归档和清理最终生产资产。
- 输出内容保持便于人阅读：先结论和优先级，再补充细节。

## single 工作流

在仓库根目录运行，或在已安装技能的 `scripts/` 目录下运行：

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "short-slug" `
  -Name "english-name-中文说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

`-ProductBriefPath` 是可选的；如果不传，脚本会自动创建一个空白的 `product-brief.md` 模板。

然后阅读：

- `_system-review/ai-input-pack.md`
- `_system-review/frame-index.json`
- `_system-review/video_metadata.json`
- `keyframes-reference-storyboard-contact-sheet-*.jpg`
- `product-brief.md`

补写：

- `brief.md`
- `outputs/reference-video-storyboard.md`
- `outputs/creative-script-directions.md`

## mix 工作流

当多条视频属于同一个方向时，应创建一个方向级文件夹，而不是拆成多个 `single` 文件夹：

```powershell
.\scripts\process-reference-videos-mix.ps1 `
  -VideoPaths "C:\path\to\video-1.mp4","C:\path\to\video-2.mp4" `
  -Slug "shared-direction" `
  -Name "shared-direction-同方向说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

`brief.md` 需要汇总所有视频的共同主题、差异点、可迁移结构，以及统一的测试目标。

补写：

- `brief.md`
- `product-brief.md`
- `outputs/shared-analysis-mix.md`

## 产品映射要求

在把参考结构转成你自己产品的脚本之前，先检查 `product-brief.md`。

产品映射至少需要这些信息：

- 游戏/产品品类、受众、市场、平台与投放渠道
- 核心玩法循环，以及用户前 30 秒的真实体验
- 哪些机制能真实地把 hook 承接到玩法里
- 可用视觉资产与制作限制
- 必须展示、必须避免、合规限制，以及成功指标

如果这些信息缺失，就输出一份简洁的缺失信息清单。参考视频的拆解仍然要有价值，但不要声称产品映射已经完成。

## 输出要求

无论 `single` 还是 `mix`，都要分析：

- 场景推进
- 开场钩子
- 冲突与压力
- 视觉语言与剪辑节奏
- 可获得时的 BGM、SFX、旁白与字幕
- 可迁移结构与表层风格的区别
- 如何承接到真实玩法或产品价值

每个故事方向都应包含：

- 核心假设
- hook
- 故事前提
- 冲突与触发机制
- 产品承接
- 产品映射适配度与缺失的产品信息
- 可扩展变体
- 待测试指标
- 风险
- 需要人工判断的问题

## 完成前检查

回复前请确认：

- 已确认当前使用的是 `single` 还是 `mix`。
- AI 写作前已经先跑完代码侧准备。
- 已确认素材文件夹路径。
- 已确认 `_system-review/` 中包含 metadata、frame index、manifest 和 AI input pack。
- 已确认根目录包含参考视频、关键帧联系表、brief、product brief 和 outputs。
- 已确认产品映射是已完成，还是因产品信息缺失而暂时待补充。
- 已确认在用户选方向之前，没有提前创建 production 文件夹。
