# 人类提示词调用指南

这份文档给人类使用。你不需要记 PowerShell 参数，也不需要知道脚本细节；只要把任务、素材路径和产品信息说清楚，Codex 会判断路线、运行脚本、生成证据包，再补写分析。

## 使用总原则

每次提示词尽量包含四类信息：

1. 你要做什么：处理单条参考、多条同方向参考、新建产品、处理产品录屏、检查环境等。
2. 素材在哪里：视频路径、录屏目录、产品目录或产品 ID。
3. 这些素材之间是什么关系：单条参考，还是多条同一个 hook / 同一个方向。
4. 要不要绑定产品：是否提供 `product-brief.md`、`ProductId` 或 `ProductProfileDir`。

不要让 AI 直接分析完整视频。这个项目的正确方式是：先生成本地证据包，再基于关键帧、帧索引、产品资料和方法论写分析。

## 1. 单条参考视频

适合场景：你有一条广告参考视频，需要拆解 hook、节奏、可迁移结构，并生成候选故事方向。

推荐提示词：

```text
用 ad-creative-skill 处理这条参考视频，走 single。
视频路径：D:\path\reference.mp4
slug：boss-reversal
名称：boss-reversal-boss逆袭参考
输出到：D:\path\creative-materials

请先生成素材包和关键帧联系表，再基于方法论补写 reference-video-storyboard.md 和 creative-script-directions.md。
```

如果还没有明确 `single`，也可以这样说：

```text
帮我处理这条新的游戏广告参考视频：
D:\path\reference.mp4

我还不确定它属于哪个方向，请按单条参考视频处理，生成 Phase1 的参考拆解和故事方向池。
```

## 2. 单条参考视频绑定产品

适合场景：你希望判断参考视频能不能承接到某个具体游戏。

使用产品 ID：

```text
用 single 处理这条参考视频，并映射到产品 daihao-shouwei。
视频路径：D:\path\reference.mp4
slug：tower-pressure
名称：tower-pressure-塔防压力参考
ProductId：daihao-shouwei

请先生成证据包，再判断这个参考结构哪些能迁移、哪些不能照搬。
如果产品资料里还有 TODO，不要编造，列出缺失信息。
```

使用产品目录：

```text
用 single 处理这条参考视频，并绑定这个产品目录：
视频路径：D:\path\reference.mp4
ProductProfileDir：D:\skills\AD-Creative-Skill\products\daihao-shouwei
slug：upgrade-payoff
名称：upgrade-payoff-升级反馈参考
```

使用单独的产品简报：

```text
处理这条参考视频，走 single。
视频路径：D:\path\reference.mp4
ProductBriefPath：D:\path\my-product-brief.md
slug：merge-reward
名称：merge-reward-合成奖励参考

请基于 product brief 判断产品承接，不要超出 brief 已经提供的信息。
```

## 3. 多条同方向参考视频

适合场景：多条视频明确属于同一个 hook、同一方向、同一批测试目标，想做共性总结。

推荐提示词：

```text
这几条参考视频属于同一个方向，请走 mix。
视频路径：
- D:\path\video-1.mp4
- D:\path\video-2.mp4
- D:\path\video-3.mp4

slug：same-hook-test
名称：same-hook-test-同方向参考
输出到：D:\path\creative-materials

请生成一个 mix 素材包，汇总共同机制、视频差异、可迁移结构、方法匹配和方向池优先级。
```

绑定产品时：

```text
这两条视频是同一个 hook 的参考，请走 mix，并绑定产品 example-product。
视频路径：
- D:\path\a.mp4
- D:\path\b.mp4
slug：collection-hook
名称：collection-hook-收集向hook
ProductId：example-product

请先看产品事实，再判断这个方向能否真实承接。
缺少本产品素材或竞品素材时，不要给定稿式测试顺序，只列待补证据。
```

重要判断：

- 不确定多条视频是不是同方向时，不要走 `mix`，先走 `single`。
- 明确是同一 hook、同一主题、同一批测试素材时，再走 `mix`。

## 4. 新建产品目录

适合场景：要为一个游戏建立长期资料库，后续用来承接参考视频和录屏分析。

推荐提示词：

```text
请为一个新游戏创建产品目录。
ProductId：my-game
Name：My Game

创建后请告诉我产品目录路径，以及后续应该先补哪些文件。
```

如果目录已经存在，只想补齐缺失模板：

```text
产品目录 my-game 已经存在，请用 Force 补齐缺失模板文件，不要覆盖已有内容。
ProductId：my-game
Name：My Game
```

新建后，优先补这些文件：

- `product-profile.md`：产品是什么、核心体验是什么。
- `gameplay-systems.md`：真实玩法和用户操作反馈。
- `asset-inventory.md`：题材、美术、UI、特效、可用资产。
- `hook-mapping.md`：哪些广告 hook 能被产品真实承接。

## 5. 产品真实录屏转证据包

适合场景：你有当前产品的真实游戏录屏，想让 AI 基于证据理解产品实际能玩到什么。

目录要求：

```text
products/<product-id>/recordings/<date>-<recording-slug>/
  source/
    gameplay.mp4
```

推荐提示词：

```text
请把这个产品录屏目录转成 AI 可读证据包，走 recording-evidence。
RecordingDir：D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-01
FrameCount：24

请只处理这一个录屏目录，不要扫描相邻录屏。
生成证据包后，先打开 review contact sheet，再写 recording-analysis.md。
```

如果目录里有多个视频，需要指定一个：

```text
请处理这个录屏目录，但只用指定的视频文件。
RecordingDir：D:\path\recordings\2026-06-06-video-01
SourceVideoPath：D:\path\recordings\2026-06-06-video-01\source\first-run.mp4
FrameCount：24
```

注意：

- 录屏证据只证明“产品实际能玩到什么”。
- 不要只根据录屏决定广告表达形式、测试顺序或素材结构定稿。
- 如果要把录屏结论沉淀为长期产品事实，需要明确说“保存为长期产品资料”。

## 6. 基于录屏沉淀产品事实

适合场景：你已经有录屏证据包和录屏分析，希望把可靠结论写回产品资料。

推荐提示词：

```text
请基于这个录屏证据包，把可靠结论沉淀到产品 daihao-shouwei 的长期资料里。
录屏目录：D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-01

只同步有证据支持的内容到 product-profile.md、gameplay-systems.md、asset-inventory.md。
不确定的内容保留为待补充，不要编造。
题材与美术分析也要同步到 asset-inventory.md。
```

## 7. 检查环境

适合场景：第一次使用、换电脑、ffmpeg 报错、脚本无法抽帧。

推荐提示词：

```text
请检查这个项目的本地运行环境。
重点检查 PowerShell、ffmpeg、ffprobe 和文件读写。
```

如果你知道 ffmpeg 路径：

```text
请检查环境，并使用这个 ffmpeg 路径：
FfmpegPath：C:\path\ffmpeg.exe
FfprobePath：C:\path\ffprobe.exe
```

## 8. 实际投放广告素材与数据复盘

适合场景：你有已经投放过的广告素材，以及分日投放数据，希望结合数据判断素材好坏、虚假玩法是否有效、夸张承诺是否值得继续做。

全局口径：

- 真实录屏只证明产品实际玩法，不等于广告素材。
- 虚假玩法、夸大宣传、伪实机和概念玩法是游戏买量中的常规素材策略。
- 判断素材不能只看真实或虚假，必须以实际数据为准。
- 缺少 ROI 或真实收益也可以分析，但要标注当前结论基于 T0、T1 还是 T2。

推荐提示词：

```text
请按全局买量数据口径分析这批实际投放广告素材。

产品：daihao-shouwei
广告素材目录：D:\path\ad-materials
分日数据文件：D:\path\daily-performance.xlsx

请优先按素材 ID 精确匹配素材和数据：
- 素材文件名示例：2026-03-23_12864095765_10043-0317（测试）【国王重生】-AI剧情(换字幕位置).mp4
- 其中 12864095765 是素材 ID
- 数据表中也会有相同数字素材 ID
- 只有素材 ID 缺失时，才用人工映射或文件名兜底

请先区分真实玩法、虚假玩法、休闲化包装和夸张承诺，再按数据判断素材表现。
请同时按视频具体内容标注素材类型：
- 一级分类：玩法 / 展示 / 副玩法
- 二级分类：粗粒度概括；如果一级是副玩法，二级固定为副玩法
- 不要只按文件名、题材关键词或画面对象默认归类
数据优先级：
- T0：消耗、付费率、付费成本
- T1：首次付费率、首次付费成本、激活成本
- T2：点击率、eCPM

如果缺少 ROI 或真实收益，不要停止分析；请基于可得数据输出阶段性结论，并说明缺失项。
样本门槛：单条素材或素材版本消耗低于 300，或激活数低于 5 时，请不要下素材质量好坏判断；可以初步标记为吸量能力不足或未起量，并列入样本不足清单。
分析完成后请必须总结：
1. 什么类型更容易跑量，且数据好。
2. 什么类型数据好但难以跑量。
3. 什么类型好跑量但数据较差。
4. 哪些元素可能带来起量，例如角色、地图、技能、特效、Boss、怪物、阵容、福利或视觉反馈。
```

补充要求可以这样写：

```text
不要因为素材不等于实机就判定不可用。请重点判断它是否同品类、是否有解释空间、数据是否成立。
```

```text
如果虚假玩法素材比真实玩法素材成本更低或 T0/T1 表现更好，请直接指出，不要按玩法真实性排序。
```

## 9. 安装 skill

适合场景：要把当前项目安装到 Codex 的 skills 目录。

推荐提示词：

```text
请把这个 ad-creative-skill 安装到 Codex skills 目录。
如果已有旧版本，请先备份再安装。
```

如果想覆盖旧版本：

```text
请安装这个 skill，如果目标目录已有旧版本，直接 Force 覆盖。
```

## 10. 常用补充要求

可以在任何任务后面加这些要求：

```text
不要进入 Phase2，不要生成 production storyboard、prompt 或 script-* 文件夹。
```

```text
如果产品信息缺失，不要编造，列出缺失信息和下一步需要补的证据。
```

```text
请先给结论，再给分析依据。
```

```text
请把可迁移结构和不可照搬的表层风格分开写。
```

```text
请重点判断承接桥、产品证明、触发机制和目标用户信号。
```

```text
如果缺少本产品素材或竞品素材，不要给“最终推荐表达形式”或“测试顺序定稿”。
```

## 11. 不推荐的提示词

不要这样说：

```text
直接看完整视频，帮我写广告脚本。
```

原因：这个项目要求先生成本地证据包，再分析；Phase1 也不直接写制作脚本。

不要这样说：

```text
这几条视频都帮我混在一起分析一下。
```

原因：如果视频不是同一 hook 或同一方向，混在一起会污染判断。请先说明它们是否属于同方向。

不要这样说：

```text
根据产品录屏直接给我最推荐的广告形式和测试顺序。
```

原因：正式广告表达判断需要同时看产品事实、本产品素材记忆和竞品素材。录屏只能证明产品真实承接边界。

## 12. 最稳妥的完整提示词模板

```text
请用 ad-creative-skill 处理这次任务。

任务类型：single / mix / new-product / recording-evidence / environment-check / install
素材路径：
- TODO

产品上下文：
- ProductId：TODO
- 或 ProductProfileDir：TODO
- 或 ProductBriefPath：TODO

我希望得到：
- 证据包路径
- 关键帧联系表
- 方法论诊断
- 可迁移结构
- 不可照搬内容
- 产品承接判断
- Phase1 候选故事方向池

约束：
- 先运行脚本生成证据，再写分析。
- 不要编造产品事实。
- 如果信息不足，列出缺失证据。
- 不要进入 Phase2，不要创建 production storyboard、prompt 或 script-* 文件夹。
```
