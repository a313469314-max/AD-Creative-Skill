# AD Creative Skill

这是一个面向游戏买量广告参考视频的 Codex Skill。它不是传统 App，而是一套本地工作流：先把视频和录屏转成可复查的证据包，再让 AI 基于证据、产品资料和方法论做 Phase1 创意分析。

## 核心目录

```text
SKILL.md                 # AI 路由和执行规则
AI_HANDOFF.md            # 接手说明
PROMPT_USAGE.md          # 人类提示词调用指南
DATA_ANALYSIS_ARCHITECTURE.md # 实际投放素材与分日数据分析架构
scripts/                 # PowerShell 入口脚本
scripts/lib/             # 脚本公共函数
templates/               # Markdown/YAML 产物模板
methodology/             # 创意方法论
products/                # 产品资料和产品专属证据索引
playbooks/               # 玩法表达建议
competitors/             # 竞品素材和品类观察
```

## 常用入口

```powershell
.\scripts\process-reference-video-phase1.ps1 -VideoPath "C:\path\ref.mp4" -Slug "short-slug" -Name "name"
```

```powershell
.\scripts\process-reference-videos-mix.ps1 -VideoPaths "C:\a.mp4","C:\b.mp4" -Slug "shared" -Name "shared-direction"
```

```powershell
.\scripts\new-product-directory.ps1 -ProductId "my-game" -Name "My Game"
```

```powershell
.\scripts\process-product-recording-evidence.ps1 -RecordingDir ".\products\my-game\recordings\2026-06-06-video-01"
```

## 产物管理

视频、抽帧图、证据图和日志默认视为本地生成物，不建议直接进 Git。产品事实、分析文档、索引文件和模板才是仓库的主要长期内容。

## 全局买量数据口径

真实游戏录屏只证明产品实际玩法和资产边界；实际投放广告素材可以包含平台默认容忍范围内的虚假玩法、夸大宣传、伪实机包装和概念化演出。素材好坏以实际数据为准，不以“真实玩法”或“虚假玩法”标签直接判断。

当前全局指标优先级：T0 为消耗、付费率、付费成本；T1 为首次付费率、首次付费成本、激活成本；T2 为点击率、eCPM。缺少 ROI 或真实收益时，仍可基于可得数据输出阶段性结论，但必须标注数据层级。

全局最小样本门槛：单条素材或素材版本消耗低于 300，或激活数低于 5 时，不能下素材质量好坏判断，但可以初步标记为吸量能力不足或未起量，并列入样本不足清单。

实际投放素材和数据表优先按素材 ID 精确匹配：从素材文件名中提取长数字素材 ID，例如 `2026-03-23_12864095765_10043-0317...mp4` 中的 `12864095765`，再匹配数据表中的同 ID。文件名匹配只作为兜底。

实际投放素材还需要按视频内容标注创意复盘分类：一级为 `玩法`、`展示`、`副玩法`；二级为粗粒度内容分类，一级为 `副玩法` 时二级固定为 `副玩法`。分类只用于复盘分组，不替代数据判断。

每次实际投放素材分析结束后，都要总结跑量能力和数据质量的关系，并提取可能带来起量的角色、地图、技能、特效、Boss、怪物、阵容、福利或视觉反馈等元素。
