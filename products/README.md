# 产品目录与增强包

每个独立游戏产品必须有一个专门目录：`products/<product-id>/`。该目录用于隔离这个产品的真实录屏、录屏分析、产品事实、素材记忆、产品专属 playbook 和后续复盘文件，避免不同游戏的判断互相污染。

产品增强包是产品目录中可长期复用的那部分资料。通用 skill 负责参考视频处理、方法论和 Phase1 方向池；产品目录提供产品事实、真实承接边界、可用资产、录屏证据、历史素材记忆和玩法表达建议。

真实游戏录屏默认只是当前任务的产品依据。如果需要落盘，必须放到对应产品目录的 `recordings/` 下；这不等于自动更新长期产品事实。只有用户明确要求保存为长期产品资料时，才把录屏分析结论同步到 `product-profile.md`、`gameplay-systems.md`、`asset-inventory.md` 等文件。

`products/<product-id>/materials/` 和 `memory/` 只保存当前产品自己的素材、测试表现、成功/失败模式和复盘结论。竞品素材不属于任何单个产品目录，必须放在根级独立模块 `competitors/`。

全局买量分析口径：

- 真实游戏录屏不是广告素材，只能证明产品实际玩法和资产边界。
- 实际投放广告素材可以包含平台默认容忍范围内的虚假玩法、夸大宣传、伪实机包装和概念化演出；这些是常规素材策略，不能直接写入产品事实。
- 虚假玩法如果仍属于同品类或相邻品类，且有解释空间，可以作为有效素材方向进入测试和复盘。
- 素材好坏以实际数据为准，不以“真实玩法”或“虚假玩法”标签直接判断。
- 缺少 ROI、LTV 或真实收益时，仍可基于可得数据输出阶段性结论，但必须标注数据层级和缺失项。

全局数据优先级：

- T0：消耗、付费率、付费成本。
- T1：首次付费率、首次付费成本、激活成本。
- T2：点击率、eCPM。

分析时优先看 T0，其次 T1。T2 只用于解释前链路吸引力和流量价格，不能单独决定素材好坏。

全局最小样本门槛：

- 单条素材或素材版本消耗低于 300 时，不能下素材质量好坏判断。
- 单条素材或素材版本激活数低于 5 时，不能下素材质量好坏判断。
- 样本不足素材不能纳入类型优劣总结。
- 样本不足素材可以初步标记为吸量能力不足或未起量。
- 如果样本不足但点击率高，应标记为“有吸引信号但未起量”，不要直接判差。

全局素材数据匹配规则：

- 优先从素材文件名中提取长数字素材 ID，并匹配数据表中的相同素材 ID。
- 示例：`2026-03-23_12864095765_10043-0317（测试）【国王重生】-AI剧情(换字幕位置).mp4` 中的素材 ID 是 `12864095765`。
- 只有素材 ID 缺失时，才使用人工映射表。
- 文件名归一化匹配只能作为最后兜底，不能作为默认匹配方式。
- 同一个素材 ID 对应多个候选文件或素材版本时，必须标记为 `ambiguous`，人工确认前不能下判断。

全局素材类型分类：

- 素材类型只用于创意复盘、素材归档和分组观察，不替代 T0/T1/T2 数据判断。
- 每条实际投放广告素材必须根据视频具体内容标注一级分类：`玩法`、`展示`、`副玩法`。
- 二级分类由 AI 按内容概括，但保持粗粒度，优先复用 `玩法介绍`、`玩法攻略`、`阵容搭配`、`角色展示`、`怪物展示`、`地图展示`、`BOSS展示`、`充值福利`、`阵容展示` 等常见类。
- 一级分类为 `副玩法` 时，二级分类固定为 `副玩法`。
- 不要只根据文件名、题材关键词或画面里出现了某类对象来归类；同一个对象题材可以根据讲法不同归入不同一级分类。

实际投放素材分析完成后，必须补充两类全局复盘：

- 跑量能力 × 数据质量：总结哪些类型更容易跑量且数据好，哪些类型数据好但难跑量，哪些类型好跑量但数据较差，哪些类型两者都差。
- 起量元素归因：提取可能带来起量的角色、地图、技能、特效、Boss、怪物、阵容、福利、视觉反馈等元素，并说明对应素材和数据表现。缺少对照或样本不足时，只能标记为可能因素。

如果用户明确要求把真实录屏沉淀为产品事实，必须把题材与美术作为必填分析：题材类型、世界观内容壳、美术风格、角色/单位卖相、敌人/Boss 卖相、场景卖相、UI 质感、技能特效、视觉记忆点、可广告化视觉资产，以及不适合作为广告开头的画面。

## 推荐目录结构

```text
products/<product-id>/
  product.yaml
  product-profile.md
  gameplay-systems.md
  hook-mapping.md
  asset-inventory.md
  creative-rules.md
  metrics-policy.md
  recordings/
    recording-index.yaml
    <date>-<recording-slug>/
      recording-analysis.md
      source-notes.md
  materials/
    material-index.yaml
  memory/
    winning-patterns.md
    rejected-patterns.md
    test-history.md
  playbooks/
```

创建新产品目录：

```powershell
.\scripts\new-product-directory.ps1 -ProductId "my-game" -Name "My Game"
```

## 录屏证据生成

不要把完整真实录屏直接上传给 AI。先在本地为单个录屏目录生成证据包：

```powershell
.\scripts\process-product-recording-evidence.ps1 `
  -RecordingDir ".\products\my-game\recordings\2026-06-06-video-01" `
  -FrameCount 24
```

该脚本只处理指定的一个录屏目录。它会从 `source/` 下读取唯一视频，生成：

- `evidence/review/contact-sheet.jpg`
- `evidence/review/frames/`
- `evidence/contact-sheet.jpg`
- `evidence/frames/`
- `_system-review/video_metadata.json`
- `_system-review/frame-index.json`
- `_system-review/ai-input-pack.md`
- `_system-review/run-manifest.json`

后续 AI 分析先读取 `evidence/review/contact-sheet.jpg` 和 `evidence/review/frames/` 这些轻量审阅证据，再结合 `_system-review/frame-index.json` 绑定时间点。`evidence/contact-sheet.jpg` 和 `evidence/frames/` 只作为本地细节证据，除非轻量图无法确认 UI 文案、资产身份或关键玩法状态，否则不要直接打开；需要打开时也应按 frame-index 精确挑选 2-3 张。不要读取完整视频，也不要扫描其他录屏目录。

## 优先级

当资料之间出现冲突时，按以下顺序处理：

1. `product-profile.md` 和 `gameplay-systems.md`：产品事实最高优先级。
2. `hook-mapping.md`：广告 hook 是否能被真实机制承接。
3. `asset-inventory.md`：当前可用素材、题材美术资产和制作能力。
4. `materials/` 与 `memory/`：当前产品自己的历史素材表现和复盘结论。
5. 根目录 `competitors/`：同玩法竞品素材和品类表达观察。
6. `playbooks/` 或根目录 `playbooks/`：玩法广告表达建议。
7. `methodology/ad-creative-methodology.md`：通用创意执行方法论。
8. `methodology/full/`：原始全文方法论参考。

玩法 playbook 只提供表达方法，不定义产品事实。如果 playbook 需要的机制在产品事实中不存在，必须标记为不适配，或改写成产品真实存在的替代表达。

广告表达形式、素材结构、测试优先级或创意方向池不能只根据产品录屏得出。必须同时结合：

- 当前产品玩法事实：产品资料和 `recordings/`。
- 当前产品具体素材：本产品 `materials/` 与 `memory/`。
- 同玩法竞品素材：根级 `competitors/` 模块。

如果当前产品素材或 `competitors/` 证据缺失，只能列出待补证据和分析框架，不能给出定稿式表达结论。

## 接入方式

脚本支持两种可选方式：

```powershell
-ProductId "example-product"
```

或：

```powershell
-ProductProfileDir ".\products\example-product"
```

不传产品参数时，skill 仍然只使用 `product-brief.md` 和通用方法论。
