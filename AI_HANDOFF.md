# AI 接手说明

这份文档给未来接手本仓库的 AI / Codex 对话使用。先读它，再读 `SKILL.md`、`methodology/` 和相关脚本。

## 项目定位

本项目是一个 Codex Skill，不是传统 App。它用于处理游戏买量广告参考视频，把视频整理成可复查的创意分析素材包，并引导 AI 按广告创意方法论完成 Phase1 分析。

核心目标：

- 从参考视频生成素材包：原视频副本、关键帧联系表、metadata、frame index、manifest、AI input pack。
- 拆解参考视频的 hook、冲突、节奏、视觉语言、BGM/SFX/字幕和可迁移结构。
- 基于 `product-brief.md` 和可选产品目录，判断参考结构能否真实承接到具体产品。
- 如果用户提供当前产品的真实游戏录屏，先建立本次任务局部的当前产品录屏上下文，再判断参考结构能否承接到该产品。
- 产出候选故事方向池，而不是直接进入 production（制作阶段）。

产品事实分析以核心玩法体验链路为准：用户从进入游戏到主要玩法、关键反馈、成长或长期动机被验证的完整过程。可以记录首个可验证体验和首个爽点出现时间；如果录屏没有覆盖完整链路，必须标记缺失信息。

如果输入是当前产品的游戏真实录屏，题材与美术分析是必做项。需要记录题材类型、世界观内容壳、美术风格、角色/单位卖相、敌人/Boss 卖相、场景卖相、UI 质感、技能特效、视觉记忆点、可广告化视觉资产，以及不适合作为广告开头的画面。该分析默认只用于本次产品判断；如果需要落盘，只能放入该游戏自己的 `products/<product-id>/recordings/`，不能影响其他游戏或其他素材分析。

广告表达形式不能只根据当前产品录屏推导。正式判断素材结构、表达形式、测试优先级或方向池前，必须同时结合当前产品玩法事实、当前产品自己的具体素材/素材记忆，以及根级 `competitors/` 模块中的同玩法竞品素材。竞品素材是独立模块，不能放进任何 `products/<product-id>/` 目录。

全局买量口径：真实游戏录屏只证明产品实际玩法和资产边界；实际投放广告素材证明市场上使用过什么表达。整个游戏买量市场都允许在平台默认容忍范围内使用虚假玩法、夸大宣传、伪实机包装和概念化演出。这些表达是常规素材策略，不要因为“不等于实机”就默认打回，也不要把它们写成产品事实。

实际投放素材的分析重点是：是否同品类或相邻品类、是否有解释空间、是否有平台通过或投放先例、是否能用更低成本获得更大规模、后链路质量损耗是否可接受。真实玩法素材和虚假玩法素材都必须以实际数据判断好坏；玩法真假、休闲化程度和夸张尺度只作为解释变量，不作为结论。

如果缺少 ROI、LTV 或真实收益，不要停止分析。按当前可得数据分层输出结论：T0 为消耗、付费率、付费成本；T1 为首次付费率、首次付费成本、激活成本；T2 为点击率、eCPM。优先看 T0，其次 T1，T2 只解释前链路吸引力和流量价格。

最小样本门槛是全局硬规则：单条素材或素材版本消耗低于 300，或激活数低于 5 时，不能下素材质量好坏判断，不能纳入类型优劣总结。但可以初步标记为吸量能力不足或未起量，并列入样本不足清单；如果点击率高但没起量，要标记为有吸引信号但未起量。

实际投放素材和数据表优先按素材 ID 精确匹配。素材文件名通常包含长数字素材 ID，例如 `2026-03-23_12864095765_10043-0317（测试）...mp4` 中的 `12864095765`。分析时先从文件名提取该 ID，并匹配数据表中的相同数字素材 ID。只有素材 ID 缺失时，才使用人工映射表；文件名归一化只能作为最后兜底，不能作为默认匹配方式。

全局素材类型分类用于创意复盘，不直接决定素材好坏。每条实际投放广告素材必须根据视频具体内容标注一级分类和二级分类：一级分类只能是 `玩法`、`展示`、`副玩法`；二级分类由 AI 概括，但必须保持粗粒度。一级为 `副玩法` 时，二级固定为 `副玩法`。不能只根据文件名、题材关键词，或画面里出现了角色、阵容、Boss、地图、福利等对象来默认归类。

实际投放素材分析完成后，必须总结跑量能力和数据质量的关系：哪些类型更容易跑量且数据好，哪些类型数据好但难跑量，哪些类型好跑量但数据较差，哪些类型两者都差。还必须提取可能带来起量的元素，例如角色、地图、技能、特效、Boss、怪物、阵容、福利和视觉反馈；这些只能作为可能因素，除非有对照和足够样本，不要断言因果。

## 当前核心概念

### Phase1

当前 skill 的主工作阶段。

Phase1 负责：

- 参考视频拆解。
- 原参考视频结构和关键帧分析。
- 可迁移结构与不可照搬表层的区分。
- 产品承接、承接桥、产品证明、触发机制和目标用户信号判断。
- 候选故事方向池。

Phase1 禁止提前创建：

- production storyboard（制作分镜）。
- prompt / 出图内容。
- `script-*` 文件夹。
- 选方向后的完成稿资产。

### Phase2

用户明确选择某个方向后才进入的制作阶段。当前仓库只保留 Phase2 边界说明，没有实现完整 Phase2 自动化。

Phase2 未来可能负责：

- 分镜级脚本。
- 字幕、旁白、BGM/SFX、镜头节奏。
- 出图 prompt / 图生视频 prompt。
- production（制作阶段）资产目录和版本迭代。

## 主要入口

### single

单条参考视频入口：

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "short-slug" `
  -Name "english-name-中文说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

可选产品目录：

```powershell
-ProductId "example-product"
```

或：

```powershell
-ProductProfileDir ".\products\example-product"
```

`process-reference-video-phase1.ps1` 会调用 `start-reference-video.ps1`，再调用 `check-creative-material.ps1` 做素材包校验。

### mix

多条同方向参考视频入口：

```powershell
.\scripts\process-reference-videos-mix.ps1 `
  -VideoPaths "C:\path\to\video-1.mp4","C:\path\to\video-2.mp4" `
  -Slug "shared-direction" `
  -Name "shared-direction-同方向说明" `
  -BaseDir ".\creative-materials"
```

`mix` 用于多条视频属于同一方向、同一种 hook、同一批参考素材的情况。

## 生成素材包结构

默认生成在 `creative-materials/` 下：

```text
YYYY-MM-DD-slug-name/
  original-*.mp4 或 video-*.mp4
  keyframes-reference-storyboard-contact-sheet-*.jpg
  brief.md
  product-brief.md
  outputs/
    reference-video-storyboard.md
    creative-script-directions.md
    或 shared-analysis-mix.md
  _system-review/
    video_metadata.json
    frame-index.json
    run-manifest.json
    ai-input-pack.md
```

规则：

- 根目录文件和 `outputs/` 给人读。
- `_system-review/` 是自动化和 AI 辅助文件。
- `reference-video-storyboard.md` 只拆解原参考视频，不是 production storyboard（制作分镜）。

## 方法论层

`methodology/ad-creative-methodology.md` 是通用广告创意方法论精简库。AI 写作前必须读取。

`methodology/full/` 保存原始压缩包里的 6 份全文方法论。它是参考原典，用于补充解释、方法选择依据、案例机制和未来 Phase2 设计；默认执行仍以精简库、产品事实和 `SKILL.md` 强约束为准。

它包含：

- 默认调用顺序。
- 钩子、承接桥、产品证明、素材即定位、触发机制、可见反馈。
- 10 个方法卡片。
- 优秀案例拆解框架。
- Phase1 参考视频特殊规则。

全文目录：

```text
methodology/full/
  README.md
  00-routing-workflow.md
  01-performance-ad-creative-methodology.md
  02-performance-ad-creative-pattern-library.md
  03-content-creation-to-ad-creatives.md
  04-excellent-creative-cases-methodology.md
  05-gameplay-concept-storyboard-prompt-method.md
```

写 `outputs/` 时至少说明：

- 本次调用了哪些产品上下文。
- 本次主要诊断问题是什么。
- 本次采用了哪些方法。
- 哪些方法被排除，为什么。

## 产品目录与增强包

每个独立游戏产品必须有一个专门目录：`products/<product-id>/`。产品目录用于隔离这个产品的真实录屏、录屏分析、产品事实、素材记忆和产品专属 playbook。

当前产品录屏上下文和长期产品事实不同：录屏上下文可以先保存在 `recordings/` 作为证据；只有用户明确要求沉淀时，才同步到 `product-profile.md`、`gameplay-systems.md`、`asset-inventory.md` 等可复用产品资料。

产品目录下的 `materials/` 和 `memory/` 只保存当前产品自己的素材、测试表现、成功/失败模式和复盘结论。竞品素材必须放在根级 `competitors/` 模块，作为品类和对标素材证据单独管理。

目录：

```text
products/
  product-registry.yaml
  example-product/
    product.yaml
    product-profile.md
    gameplay-systems.md
    hook-mapping.md
    asset-inventory.md
    creative-rules.md
    metrics-policy.md
    recordings/
      recording-index.yaml
    materials/
      material-index.yaml
    memory/
      winning-patterns.md
      rejected-patterns.md
      test-history.md
```

玩法 playbook 在：

```text
playbooks/
  battle-playbook.md
  collection-playbook.md
  progression-playbook.md
  puzzle-challenge-playbook.md
```

竞品素材模块在：

```text
competitors/
  README.md
  competitor-index.yaml
```

冲突优先级：

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

重要原则：

- `product-profile.md` 和 `gameplay-systems.md` 是产品事实。
- 题材与美术也是产品事实的一部分，优先写入 `asset-inventory.md`。
- `competitors/` 是竞品素材模块，只能影响广告表达假设，不能定义当前产品事实。
- playbook 是广告表达建议，不定义产品事实。
- 如果 playbook 建议的机制在真实产品中不存在，必须标记为不适配，或提出真实替代表达。
- 一个产品目录只服务一个游戏产品，不要混放多个游戏。
- 不要把一次当前产品录屏分析自动当成长期产品事实；除非用户明确要求保存，否则只在本次素材包内使用，或仅作为 `recordings/` 下的证据文件。

## 关键脚本

- `scripts/process-reference-video-phase1.ps1`：single 包装入口，调用素材生成和校验。
- `scripts/start-reference-video.ps1`：single 核心处理脚本，复制视频、抽帧、生成模板和 manifest。
- `scripts/process-reference-videos-mix.ps1`：mix 核心处理脚本。
- `scripts/new-product-directory.ps1`：为独立游戏产品创建专属目录。
- `scripts/process-product-recording-evidence.ps1`：复用主功能的本地视频处理方式，为单个产品录屏目录生成 evidence、metadata、frame-index 和 AI input pack。
- `scripts/product-context.ps1`：解析 `-ProductId` / `-ProductProfileDir`，收集产品目录和 playbook 文件。
- `scripts/check-creative-material.ps1`：素材包完整性检查。
- `scripts/test-regression.ps1`：回归测试。
- `scripts/check-environment.ps1`：环境检查。

## 开发注意事项

- 不要改现有入口参数语义；新增能力尽量用可选参数。
- 不传产品目录时，通用 single/mix 流程必须保持可用。
- 产品录屏分析不要把完整视频上传进对话；先运行 `process-product-recording-evidence.ps1`，让 AI 基于 contact sheet、frames、metadata 和 frame-index 分析。
- PowerShell 5.1 会误读无 BOM UTF-8 脚本里的中文字符串。脚本逻辑中尽量避免新增中文运行时字符串；Markdown here-string 模板已有中文可保持，但测试断言中不要直接写中文。
- 不要把 Phase2 production（制作阶段）资产提前混入 Phase1。
- 默认复制源视频，只有用户明确要求移动时才使用 `-Move`。
- 回归测试会生成合成测试视频和临时素材包，正常结束会清理 `.tmp`。

## 验证命令

```powershell
.\scripts\check-environment.ps1
```

```powershell
.\scripts\test-regression.ps1
```

预期：

- 环境检查全部 OK。
- 回归测试 6/6 通过。
- `.tmp` 测试输出被清理。

## 接手建议

如果你是后续 AI，请按这个顺序理解项目：

1. 读 `AI_HANDOFF.md`。
2. 读 `SKILL.md`。
3. 读 `methodology/ad-creative-methodology.md`。
4. 如果需要方法原文细节，读 `methodology/full/README.md` 和相关全文文档。
5. 如果任务涉及具体产品，读 `products/README.md` 和对应产品包。
6. 如果任务涉及玩法表达，读 `playbooks/README.md` 和相关 playbook。
7. 改脚本前先跑 AST 或完整回归测试。

如果要继续扩展，优先方向是：

- 增加真实产品目录。
- 增加更多玩法 playbook。
- 增加素材记忆导入 / 沉淀流程。
- 在用户选定方向后，再设计 Phase2 production workflow（制作流程）。
