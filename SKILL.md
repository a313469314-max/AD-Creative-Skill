---
name: ad-creative-skill
description: >
  面向游戏买量广告参考视频的素材处理与创意分析技能。适用于 single、mix、reference video、
  product brief、gameplay recording、keyframe contact sheet、creative materials、产品目录、
  产品映射、录屏证据包、广告 hook 拆解、可迁移结构分析，以及在进入 production（制作阶段）前建立
  Phase1 故事方向池。
---

# 广告创意 Skill

把本 skill 当成 AI 路由器使用：人类可以直接用自然语言描述任务；Codex 需要先判断路线，运行对应脚本准备本地证据包，再基于生成的审阅包补写分析。

保持现有行为不变：

- 先运行确定性脚本，再进行 AI 写作。
- 不改变现有脚本参数语义。
- 不改变生成素材包的目录和文件结构。
- Phase1 只做参考拆解和故事方向筛选。

## 路由规则

按用户意图选择一个主路线：

| 用户意图 | 路线 | 脚本 |
| --- | --- | --- |
| 处理一条新参考视频，或无法确认多条视频属于同一方向 | `single` | `scripts/process-reference-video-phase1.ps1` |
| 多条视频明确属于同一 hook、方向、批次、主题或测试目标 | `mix` | `scripts/process-reference-videos-mix.ps1` |
| 为一个游戏创建独立产品资料目录 | `new-product` | `scripts/new-product-directory.ps1` |
| 把单个产品录屏目录转成 AI 可读证据包 | `recording-evidence` | `scripts/process-product-recording-evidence.ps1` |
| 检查本地 ffmpeg、ffprobe、PowerShell 和文件读写环境 | `environment-check` | `scripts/check-environment.ps1` |
| 把本 skill 安装到 Codex skills 目录 | `install` | `scripts/install-skill.ps1` |

语义不明确时默认使用 `single`。只有当用户明确表示视频属于同一方向，或任务需要方向级汇总分析时，才使用 `mix`。

## 核心流程

`single` 示例：

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "short-slug" `
  -Name "english-name-中文说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md" `
  -ProductId "example-product"
```

`mix` 示例：

```powershell
.\scripts\process-reference-videos-mix.ps1 `
  -VideoPaths "C:\path\to\video-1.mp4","C:\path\to\video-2.mp4" `
  -Slug "shared-direction" `
  -Name "shared-direction-同方向说明" `
  -BaseDir ".\creative-materials" `
  -ProductProfileDir ".\products\example-product"
```

`-ProductBriefPath`、`-ProductId` 和 `-ProductProfileDir` 都是可选参数。`-ProductId` 与 `-ProductProfileDir` 只能二选一。默认复制源视频；只有用户明确要求移动原文件时，才使用 `-Move`。

脚本完成后，读取返回 JSON 里的路径，并检查：

- `methodology/ad-creative-methodology.md`
- `_system-review/ai-input-pack.md`
- `_system-review/frame-index.json`
- `_system-review/video_metadata.json`
- `keyframes-reference-storyboard-contact-sheet-*.jpg`
- `product-brief.md`

然后替换生成的骨架文件：

- `brief.md`
- `single`：`outputs/reference-video-storyboard.md` 和 `outputs/creative-script-directions.md`
- `mix`：`outputs/shared-analysis-mix.md`

## 产品上下文

只有当用户提供 product brief、产品 ID、产品目录或当前产品真实录屏时，才启用产品上下文。

产品事实优先级高于通用方法论：

```text
product-profile/gameplay-systems
> hook-mapping
> asset-inventory
> materials/memory 素材记忆
> competitors 竞品素材模块
> playbooks
> methodology/ad-creative-methodology.md
> methodology/full/*
```

如果产品事实缺失、不完整，或仍包含 `TODO`，不要编造产品细节。把产品映射标记为待补充，并列出缺失信息。

创建或更新产品上下文前，先读 `products/README.md`。每个 `products/<product-id>/` 目录只能代表一个独立游戏产品。

## 录屏证据

如果用户提供真实游戏录屏作为当前产品上下文，不要直接在对话里分析完整视频。先为单个录屏目录生成本地证据包：

```powershell
.\scripts\process-product-recording-evidence.ps1 `
  -RecordingDir ".\products\my-game\recordings\2026-06-06-video-01" `
  -FrameCount 24
```

证据包会生成 `evidence/review/contact-sheet.jpg`、`evidence/review/frames/`、`evidence/contact-sheet.jpg`、`evidence/frames/`、`_system-review/video_metadata.json`、`_system-review/frame-index.json`、`_system-review/ai-input-pack.md` 和 `_system-review/run-manifest.json`。
后续 AI 分析默认只打开 `evidence/review/contact-sheet.jpg` 和 `evidence/review/frames/` 中的轻量图；`evidence/contact-sheet.jpg` 与 `evidence/frames/` 是本地细节证据，只在 UI 文案、资产身份或关键玩法状态无法确认时，按 frame-index 精确挑选 2-3 张打开。

录屏证据默认只服务当前任务。只有用户明确要求沉淀为长期产品事实时，才把结论写入该产品自己的 `products/<product-id>/recordings/` 或长期产品资料文件。

## 广告表达证据规则

广告表达形式不能只根据当前产品真实录屏推导。真实录屏只回答“产品实际能玩到什么”和“哪些产品承接不能编造”；它不能单独决定素材结构、开头形式、剪辑包装、测试优先级或竞品差异化。

正式输出广告表达形式、素材结构、测试优先级或创意方向池前，必须同时检查三类证据：

1. 当前产品玩法事实：`product-profile.md`、`gameplay-systems.md`、`asset-inventory.md`、`recordings/`。
2. 当前产品具体素材：`products/<product-id>/materials/`、`memory/winning-patterns.md`、`memory/rejected-patterns.md`、`memory/test-history.md`，包括已投放、待投放、成功、失败和参考素材。
3. 同玩法品类竞品素材：只能从独立模块 `competitors/` 读取；不要把竞品素材放进任何 `products/<product-id>/` 目录。

如果缺少当前产品具体素材或 `competitors/` 中的同玩法竞品素材，不要给出“最推荐表达形式”“测试顺序”“素材结构定稿”这类结论。只能输出待补证据清单、分析框架、产品录屏能提供的承接边界，以及下一步需要分别收集的本产品素材和竞品素材。

## 方法论

补写任何 `outputs/` 内容前，先阅读 `methodology/ad-creative-methodology.md`，并做一次简短诊断：

- 本次调用了哪些产品上下文。
- 本次主要创意问题是什么。
- 本次选择了哪些方法。
- 哪些方法被排除，为什么。

只有需要更细解释、方法选择依据、案例机制或未来 Phase2 设计时，才阅读 `methodology/full/README.md` 和相关全文方法论。全文方法论可以补充判断，但不能覆盖产品事实或 Phase1 边界。

## 阶段边界

Phase1 可以创建：

- 参考视频场景与结构分析。
- 可迁移结构与不可迁移表层风格判断。
- 承接桥、产品证明、触发机制和目标用户信号分析。
- 候选故事方向池。

用户选择具体方向前，Phase1 不得创建 production storyboard（制作分镜）、prompt / 出图资产、详细 production script（制作脚本）、`script-*` 文件夹或最终制作包。

## 输出要求

正式创意输出先给结论和判断，再补充细节。需要覆盖：

- 场景推进、hook、冲突、压力、视觉语言和剪辑节奏。
- 可获得时的 BGM、SFX、旁白和字幕。
- 可迁移结构与不可照搬表层风格。
- 如何承接真实玩法或产品价值。
- 采用方法、排除方法、产品证明、素材定位和触发机制。
- 故事方向假设、目标用户信号、测试指标、风险和需要人工判断的问题。

## 参考地图

- 读 `AI_HANDOFF.md` 了解架构交接和维护背景。
- 读 `products/README.md` 了解产品目录和产品增强包规则。
- 使用玩法 playbook 前，先读 `playbooks/README.md`。
- 用 `scripts/check-creative-material.ps1` 校验生成后的素材包。
- 改脚本或生成骨架行为后，运行 `scripts/test-regression.ps1`。

## 完成前检查

素材任务回复用户前，确认：

- 已选择 `single`、`mix`、`new-product`、`recording-evidence`、`environment-check` 或 `install`。
- AI 写作前已经完成确定性脚本。
- 写分析前已经读取 `methodology/ad-creative-methodology.md`。
- 已确认素材包或录屏证据包路径。
- 适用时，`_system-review/` 中包含 metadata、frame index、manifest 和 AI input pack。
- 适用时，素材根目录包含参考视频、联系表、brief、product brief 和 outputs。
- 产品映射要么基于真实产品事实完成，要么明确标记为待补充。
- 用户选定方向前，没有创建 Phase2 production（制作阶段）资产。
