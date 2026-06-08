# 素材与投放数据分析架构设计

本设计用于扩展当前 `ad-creative-skill`，让它能处理“特定产品的一批实际投放广告素材 + 分日广告投放数据 + 产品事实”这一类新任务。首个适配产品是 `products/daihao-shouwei/`。

这里必须区分两类视频证据：游戏真实录屏只证明产品实际玩法和资产边界；实际投放广告素材证明市场上使用过什么表达。广告素材可以包含平台默认容忍范围内的虚假玩法、夸大宣传、伪实机包装或概念化演出。它们是买量素材里的常规表达策略，需要被记录、评估和复盘，但不能被回写成真实产品事实。

## 1. 设计目标

现有 skill 的核心能力是把参考视频或产品录屏转成可复查证据包，再基于产品事实和方法论做 Phase1 创意分析。新需求需要在这个能力旁边增加一条“实际投放素材复盘”链路：

1. 管理本产品自己的广告素材和素材版本。
2. 导入广告平台分日投放数据，并保留数据版本。
3. 建立素材文件中的素材 ID 与数据表素材 ID 之间的精确映射。
4. 基于素材内容、表达偏差、分日指标、产品事实和竞品证据输出素材端建议。
5. 把经过确认的结论沉淀到产品 memory，而不是把原始数据直接混进长期产品事实。

这条链路不替代 `single`、`mix` 和 `recording-evidence`，而是新增面向本产品历史素材复盘的分析能力。

## 2. 架构原则

### 2.1 保持证据分层

优先级仍沿用现有产品目录规则：

```text
真实玩法事实 product-profile/gameplay-systems/recordings
> 产品可用资产 asset-inventory
> 本产品广告素材表达 materials
> 本产品投放表现 performance
> 本产品历史记忆 memory
> 竞品素材 competitors
> playbooks
> methodology
```

真实录屏只能证明“产品实际能玩到什么”。广告素材只能证明“投放中使用了什么表达”。投放数据只能证明“这批素材在某渠道、某市场、某时间段的表现”。三者都不能互相反向定义。

### 2.2 广告表达偏差要显式建模

实际广告素材可能不是对真实玩法的直接复刻。它可能包含：

- `faithful_gameplay`：基本忠于真实游戏。
- `edited_gameplay`：真实玩法剪辑强化，节奏、顺序或反馈被重组。
- `exaggerated_claim`：真实机制存在，但效果、奖励、难度或爽感被放大。
- `fictionalized_gameplay`：平台默认容忍范围内的伪玩法或概念玩法，产品中没有一比一系统。
- `metaphor_demo`：用外部隐喻、剧情或小剧场表达产品欲望点。
- `explainable_overclaim`：有解释空间的夸张承诺，例如奖励数量、福利价值或爽感被放大。
- `misleading_risk`：尺度过大，可能造成用户预期错配，需要人工复核。

这些偏差不是自动失败项，也不应该默认被视为“不能用”。分析时要同时看它带来的获量效率、转化质量、留存/付费后果、平台容忍度和用户预期风险。

### 2.3 投放可用性优先于实机一致性

广告素材的核心判断不是“是否完全等于实机”，而是“是否能在投放环境中有效、可解释、可持续”。默认口径：

- 同品类虚假玩法通常可用。例如塔防游戏的广告虚假玩法仍然是塔防表达，可以作为吸引用户的素材语法。
- 同商业模型或同用户欲望的夸张承诺通常可用。例如抽卡游戏真实只有送 10 抽，广告写送 1000 抽，如果能解释为活动累计、福利价值、礼包叠加或表达夸张，可以进入测试。
- 广告更关注用户注意力、欲望触发和点击动机，不要求每一帧都能在游戏内一比一复现。
- 真正需要警惕的是跨品类骗量、完全无解释空间、后链路质量崩坏、账号或素材审核反复出问题。

因此，架构里要记录的不是简单的“真/假”，而是：

- `category_fit`：虚假玩法是否仍属于产品所在品类或相邻品类。
- `claim_elasticity`：夸张承诺是否有解释空间。
- `explainability_bridge`：用什么口径解释素材和产品之间的关系。
- `scale_level`：夸张尺度是轻度、中度还是重度。
- `platform_precedent`：是否已有同类素材通过审核或正在投放。
- `quality_tradeoff`：获量收益是否值得承受后链路波动。

### 2.4 可得数据优先于素材类型判断

真实玩法广告和虚假玩法广告都不能只靠类型判断好坏。玩法真实度、休闲化程度、虚假承诺尺度都只是解释变量，不是评分结论。

理想情况下，最终判断以实际数据和最终收益为准；但实际复盘中，很多时候拿不到真实收益、ROI、LTV 或完整回收数据。因此架构必须支持“按可得数据分层判断”：

- 虚假玩法素材可能用更低 CPI 买到更大规模，即使用户流失更高，最终 ROI 仍然可能优于真实玩法素材。
- 真实玩法素材可能用户质量更高，但如果受众窄、CPI 高、放量困难，综合收益可能不如偏休闲虚假玩法。
- 真实玩法素材也可能以低成本获得高质量用户，应该被数据证明后放量。
- 虚假玩法素材也可能成本高、后链路差、ROI 不成立，不能因为“偏休闲”就默认更好。

因此，分析必须把素材拆成两层：

1. **表达特征层**：真实玩法、虚假玩法、休闲化包装、夸张承诺、解释桥、品类贴合度。
2. **数据评估层**：花费、规模、CTR、CVR、CPI、IPM、留存、付费、LTV、ROAS、ROI、回收周期和可放量性；缺少后链路时，用当前可得代理指标判断。

表达特征只用于解释“为什么这个素材可能有效或无效”；素材好坏必须由当前可得数据决定，并标明结论置信度。ROI、净收益和回收周期是最高优先级参考，不是每次分析的必填前提。

数据可得性分层：

- `level_4_profit`：有收入、LTV、ROAS、ROI 或净收益，可做收益结论。
- `level_3_quality`：有留存、付费率、注册率或关键行为，可做质量倾向结论。
- `level_2_acquisition`：有 CTR、CVR、CPI、IPM、消耗和规模，可做获量效率结论。
- `level_1_delivery`：只有消耗、曝光、点击或审核/投放状态，只能做投放现象记录。

如果没有 ROI，不要停止分析；应输出“当前基于哪一层数据判断”，并把缺失的收益数据列为后续验证项。

当前项目的数据重要程度按 T0/T1/T2 分级。素材排序优先看 T0，其次看 T1，T2 只作为前链路解释和诊断，不单独决定素材好坏：

- `T0`：消耗、付费率、付费成本。
- `T1`：首次付费率、首次付费成本、激活成本。
- `T2`：点击率、eCPM。

指标定义：

- `first_pay_rate = first_payers / activations`
- `pay_rate = payers / activations`
- `first_pay_cost = spend / first_payers`
- `pay_cost = spend / payment_count`
- `activation_cost = spend / activations`
- `ctr = clicks / impressions`
- `ecpm = spend / impressions * 1000`

如果 T0 缺失，可以用 T1/T2 做阶段性判断；如果 T0 与 T2 冲突，以 T0 为准。例如点击率高但付费成本差，不能判定为好素材。

最小样本门槛：单条素材或素材版本的消耗低于 300，或激活数低于 5 时，不能下素材质量判断，也不能纳入类型优劣总结。但可以初步标记为“吸量能力不足 / 未起量”，作为后续是否补量、换包装或暂停观察的依据。

### 2.5 素材类型分类用于创意复盘

素材类型是全局创意复盘标签，不直接决定素材好坏。所有视频都必须根据具体视频内容判断归类，不能只根据素材名、题材关键词或画面里出现了角色、阵容、Boss、地图、福利等对象来默认归类。

一级分类固定为：

- `玩法`：视频重点在讲机制、操作、策略、过关方法、搭配逻辑、成长路径、战斗决策或玩法教学。
- `展示`：视频重点在展示对象、资源、结果、卖点或视觉内容本身，而不是解释玩法逻辑。
- `副玩法`：视频主体是非主游戏玩法的吸量包装、休闲小游戏、广告外层玩法或独立的虚假/概念玩法。

二级分类由 AI 根据视频内容概括，但必须保持粗粒度，服务复盘和分组，不服务逐条描述。优先复用常见粗类，避免为单条素材发明过细分类：

- `玩法介绍`：介绍玩法是什么、怎么玩。
- `玩法攻略`：包含 Boss 打法、通关策略、阵容打法、关卡技巧、战斗策略等，不再继续细拆。
- `阵容搭配`：重点讲不同角色/单位组合的搭配逻辑。
- `角色展示`：包含单角色、多角色、英雄、单位展示。
- `怪物展示`：包含怪物、敌人、怪潮展示。
- `地图展示`：包含章节、场景、地图路线、环境展示。
- `BOSS展示`：展示 Boss 外观、压迫感、战斗画面，但不细拆打法。
- `充值福利`：包含礼包、首充、月卡、福利、抽卡奖励、资源赠送。
- `阵容展示`：只展示阵容或队伍结果，不讲策略逻辑。

特殊规则：一级分类为 `副玩法` 时，二级分类固定为 `副玩法`。如果副玩法仍属于同品类或相邻品类，仍可作为有效广告素材进入复盘，不因“不等于实机”被打回。

### 2.6 原始数据和可提交知识分离

原始素材、原始表格、归一化明细、join 后的大表默认放在根目录 `data/` 下。该目录已经被 `.gitignore` 忽略，适合保存敏感或较大的本地文件。

产品目录只保留轻量索引、字段口径、分析结论、可复查摘要和经过人工确认的长期记忆。

### 2.7 分日数据必须保留版本

同一批投放数据可能多次导出，且 D1、D3、D7、ROI 等指标会随时间成熟。每次导入必须生成独立 `dataset_id`，记录：

- `pulled_at`：导出或导入时间。
- `date_range`：数据覆盖日期。
- `source_platform`：广告平台或数据源。
- `timezone`、`currency`、`attribution_window`。
- `maturity_rules`：哪些指标已经成熟，哪些不能比较。

### 2.8 AI 不直接吃整张原始表

脚本先做字段校验、去重、聚合、异常标记和素材映射，生成小而稳的 `ai-input-pack.md`、摘要 JSON 和必要 CSV。AI 基于这些审阅包写分析，避免在对话里直接扫描大体量表格。

## 3. 推荐目录结构

### 3.1 可提交的产品知识层

```text
products/daihao-shouwei/
  product.yaml
  product-profile.md
  gameplay-systems.md
  hook-mapping.md
  asset-inventory.md
  creative-rules.md
  metrics-policy.md

  materials/
    material-index.yaml
    <material-id>/
      material-card.md
      versions/
        <version-id>.yaml
      expression-deviation.md
      evidence-manifest.yaml

  performance/
    performance-index.yaml
    data-dictionary.md
    mappings/
      creative-material-map.yaml
      campaign-taxonomy.yaml

  analyses/
    <YYYY-MM-DD>-<analysis-slug>/
      analysis-brief.md
      source-manifest.yaml
      material-performance-summary.md
      material-economics-summary.md
      findings.md
      recommendations.md
      _system-review/
        ai-input-pack.md
        data-quality-report.md
        daily-performance-aggregate.json
        material-feature-matrix.csv
        material-economics.json

  memory/
    winning-patterns.md
    rejected-patterns.md
    test-history.md
    performance-learnings.md
```

### 3.2 本地数据与重资产层

```text
data/
  products/
    daihao-shouwei/
      materials/
        raw/
          <material-batch-id>/
        evidence/
          <material-id>/
      performance/
        raw/
          <dataset-id>/
        normalized/
          <dataset-id>/
            daily.csv
            schema.json
            import-report.json
        joined/
          <analysis-id>/
            material-daily.csv
            unmapped-rows.csv
```

`products/` 下保存“可复用知识”，`data/` 下保存“可再生成或敏感的证据与数据”。

## 4. 核心实体

### 4.1 Material

`material_id` 是本地稳定 ID，代表一个广告创意概念或素材母版。

建议格式：

```text
dhsw-mat-0001
```

`material-card.md` 记录：

- 素材类型：视频、图片、试玩、混剪、伪实机等。
- 源素材 ID：从文件名中提取的数字素材 ID，用于和数据表精确匹配。
- 一级素材分类：`玩法`、`展示` 或 `副玩法`。
- 二级素材分类：粗粒度自由文本；一级为 `副玩法` 时固定为 `副玩法`。
- 分类依据：简短说明为什么按该视频内容归类。
- 核心 hook。
- 前 3 秒开头形式。
- 创意结构。
- 承接桥。
- 广告承诺。
- 产品证明。
- 表达偏差类型。
- 虚假玩法或夸张宣传点。
- 品类贴合度。
- 解释桥。
- 夸张尺度。
- 审核状态和审核备注。
- 用户预期错配风险。
- 使用的产品资产。
- 用户欲望和目标人群信号。
- 风险和误导边界。
- 关联产品事实证据。
- 关联版本和平台 ID。

`expression-deviation.md` 专门记录广告素材与真实玩法之间的差异，不写进 `product-profile.md`。它回答：

- 这条素材展示了什么真实玩法。
- 这条素材展示了什么非真实玩法或夸张包装。
- 该表达是否在审核规范内已经投放。
- 它是否仍属于同品类或相邻品类表达。
- 夸张承诺的解释空间是什么。
- 它可能提升哪一段指标：CTR、CVR、IPM、CPI、ROI 或留存。
- 它可能伤害哪一段指标：次留、付费、评论反馈、品牌信任或后续审核。
- 如果要保留表达，应该强化哪条解释桥或把尺度控制到什么范围。

### 4.2 Material Version

`version_id` 代表同一个素材母版的具体变体，例如字幕、封面、前 3 秒、时长、比例、语言、渠道适配不同。

建议格式：

```text
dhsw-mat-0001-v001
```

`versions/<version-id>.yaml` 记录：

- `material_id`
- `version_id`
- `source_material_id`
- `source_path`
- `format`
- `duration`
- `aspect_ratio`
- `language`
- `market`
- `channel`
- `opening_variant`
- `cover_variant`
- `cta_variant`
- `expression_fidelity`
- `exaggeration_type`
- `category_fit`
- `claim_elasticity`
- `explainability_bridge`
- `scale_level`
- `compliance_status`
- `review_notes`
- `expectation_risk`
- `status`

### 4.3 Ad Expression Deviation

广告素材需要单独抽取一组“表达偏差”字段，用于解释素材为什么和真实录屏不同，以及这种不同在数据里是否有效。

建议字段：

- `shown_gameplay_claim`：素材让用户以为能玩到什么。
- `true_product_match`：真实产品中能否找到对应机制。
- `deviation_type`：忠实、剪辑强化、夸张、伪玩法、隐喻演出、误导风险。
- `deviation_detail`：具体差异，例如敌人数量、奖励倍率、失败惩罚、操作自由度、Boss 强度。
- `category_fit`：是否仍属于同品类、相邻品类或同用户欲望表达。
- `claim_elasticity`：夸张承诺是否能通过活动、累计、福利价值、礼包叠加或文案口径解释。
- `explainability_bridge`：对用户、审核或内部复盘时如何解释该表达。
- `scale_level`：轻度、中度、重度夸张。
- `platform_precedent`：同类素材是否已经通过审核、正在投放或有历史成功案例。
- `approved_or_live_status`：已投放、审核通过、审核失败、未知。
- `compliance_notes`：审核规范相关备注。
- `player_expectation_gap`：下载后预期错配风险。
- `data_hypothesis`：为什么这种表达可能带来更高点击或更低成本。
- `quality_hypothesis`：为什么这种表达可能影响留存、付费或 ROI。
- `recommended_handling`：放量、保留、强化、控尺度、换解释桥、隔离预算、暂停或补测。

这组字段服务于素材复盘，不服务于产品事实沉淀。只有当素材中的机制被真实录屏或产品资料确认存在时，才允许进入 `product-profile.md` 或 `gameplay-systems.md`。

### 4.4 Material ID Mapping

实际投放素材和数据表优先按素材 ID 精确匹配，而不是按完整文件名匹配。素材文件名中通常包含一段数字素材 ID，例如：

```text
2026-03-23_12864095765_10043-0317（测试）【国王重生】-AI剧情(换字幕位置).mp4
```

其中 `12864095765` 是素材 ID。导入素材时必须从文件名中提取该 ID，并与数据表中的相同数字素材 ID 字段精确匹配。

匹配优先级：

1. `source_material_id` / 数据表素材 ID 精确匹配。
2. 如果素材 ID 缺失，才使用人工映射表。
3. 如果没有素材 ID 也没有人工映射表，才允许使用文件名归一化兜底匹配。

广告平台的 `creative_id`、`ad_id`、`campaign_id` 不应该直接等于本地素材 ID。它们可以作为辅助字段保留，但不能替代素材 ID 精确匹配。需要显式映射：

```text
products/daihao-shouwei/performance/mappings/creative-material-map.yaml
```

字段建议：

- `source_platform`
- `source_material_id`
- `material_file_name`
- `account_id`
- `campaign_id`
- `adgroup_id`
- `ad_id`
- `creative_id`
- `material_id`
- `version_id`
- `valid_from`
- `valid_to`
- `mapping_confidence`
- `mapping_method`
- `notes`

没有素材 ID 精确匹配、人工映射或可靠兜底匹配的投放行进入 `unmapped-rows.csv`，不能参与素材结论。多个文件或多条数据命中同一个素材 ID 时，必须标记为 `ambiguous` 并人工确认。

### 4.5 Daily Performance Row

归一化后的日粒度数据至少包含：

- `report_date`
- `source_platform`
- `account_id`
- `campaign_id`
- `campaign_name`
- `adgroup_id`
- `adgroup_name`
- `ad_id`
- `ad_name`
- `creative_id`
- `creative_name`
- `source_material_id`
- `material_id`
- `version_id`
- `market`
- `os`
- `placement`
- `spend`
- `impressions`
- `clicks`
- `installs`
- `activations`
- `registrations`
- `first_payers`
- `payers`
- `payment_count`
- `purchases`
- `revenue_d0`
- `revenue_d1`
- `revenue_d3`
- `revenue_d7`
- `retention_d1`
- `retention_d3`
- `retention_d7`

派生指标由脚本计算：

- `ctr`
- `ecpm`
- `cvr_click_to_install`
- `cpi`
- `activation_cost`
- `ipm`
- `first_pay_rate`
- `pay_rate`
- `first_pay_cost`
- `pay_cost`
- `cpa_purchase`
- `roas_d0`
- `roas_d1`
- `roas_d3`
- `roas_d7`

### 4.6 Material Economics And Proxy Signals

素材评估必须独立于玩法真假标签。每个素材或素材版本都尽量生成一组经济性指标；拿不到真实收益时，允许生成代理信号并降低结论置信度：

- `spend`：累计消耗，T0。
- `first_pay_rate`：首次付费率，T1。
- `pay_rate`：付费率，T0。
- `first_pay_cost`：首次付费成本，T1，`spend / first_payers`。
- `pay_cost`：付费成本，T0，`spend / payment_count`。
- `activation_cost`：激活成本，T1，`spend / activations`。
- `ctr`：点击率，T2。
- `ecpm`：千次曝光成本，T2。
- `scale`：曝光、点击、激活、首次付费、付费次数等规模。
- `cpi`：获客成本；如数据源中激活等同安装，可作为 `activation_cost` 的源指标。
- `arpu` / `arppu`：人均收入 / 付费用户收入。
- `ltv_d1`、`ltv_d3`、`ltv_d7`、`ltv_d30`：分窗口 LTV。
- `roas_d1`、`roas_d3`、`roas_d7`、`roas_d30`：分窗口 ROAS。
- `roi`：按当前团队口径计算的最终收益指标。
- `payback_days`：回本周期。
- `retention_penalty`：因为表达错配带来的留存损耗。
- `volume_ceiling`：当前成本下的可放量上限。
- `quality_adjusted_profit`：扣除质量损耗后的预估收益。
- `available_data_level`：当前素材可用于判断的数据层级。
- `proxy_decision_metric`：没有 ROI 时，本次使用的代理判断指标。
- `missing_profit_fields`：缺失的收益字段。

推荐在分析包中同时生成两类对比：

- **同类型对比**：真实玩法素材之间、虚假玩法素材之间、休闲化包装素材之间。
- **跨类型对比**：真实玩法 vs 虚假玩法 vs 休闲化包装，按当前可得核心指标排序；有收益数据时按最终收益排序。

跨类型对比必须控制市场、渠道、版位、日期、预算阶段和归因窗口，否则只能作为假设，不能作为定论。

## 5. 新增工作流

### 5.1 material-import

目的：把本产品广告素材登记到 `materials/`，并生成可供 AI 审阅的素材卡片骨架。

输入：

- 素材文件路径或素材批次目录。
- 产品 ID。
- 可选人工标签：hook、市场、渠道、投放批次。

输出：

- `materials/material-index.yaml` 更新。
- `materials/<material-id>/material-card.md`
- `materials/<material-id>/versions/<version-id>.yaml`
- `materials/<material-id>/expression-deviation.md`
- 本地 evidence 或缩略图写入 `data/products/<product-id>/materials/evidence/`。

### 5.2 performance-import

目的：导入分日投放数据，做字段标准化和数据质量检查。

输入：

- CSV 或 XLSX。
- 产品 ID。
- 数据源平台。
- 导出时间和归因窗口。

输出：

- `data/products/<product-id>/performance/raw/<dataset-id>/`
- `data/products/<product-id>/performance/normalized/<dataset-id>/daily.csv`
- `data/products/<product-id>/performance/normalized/<dataset-id>/import-report.json`
- `products/<product-id>/performance/performance-index.yaml` 更新。
- `products/<product-id>/performance/data-dictionary.md` 缺字段提示。

### 5.3 material-performance-analysis

目的：将素材内容、表达偏差、素材版本映射、分日表现和产品上下文合并成 AI 可读分析包。

输入：

- `ProductId`
- 一个或多个 `dataset_id`
- 可选素材范围、渠道、市场、日期范围。

输出：

```text
products/<product-id>/analyses/<analysis-id>/
  analysis-brief.md
  source-manifest.yaml
  material-performance-summary.md
  material-economics-summary.md
  findings.md
  recommendations.md
  _system-review/
    ai-input-pack.md
    data-quality-report.md
    daily-performance-aggregate.json
    material-feature-matrix.csv
    material-economics.json
```

### 5.4 memory-sync

目的：只把经过确认的复盘结论写回长期 memory。

输入：

- 一个 analysis 目录。
- 人工确认：哪些结论可以沉淀。

输出：

- `memory/test-history.md`
- `memory/winning-patterns.md`
- `memory/rejected-patterns.md`
- `memory/performance-learnings.md`

该流程不自动改 `product-profile.md` 或 `gameplay-systems.md`。

## 6. 分析输出合同

每条素材结论必须同时写清七件事：

1. 数据信号：指标、时间范围、样本量、成熟度、异常。
2. 创意解释：hook、前 3 秒、结构、广告承诺、产品证明、视觉资产。
3. 素材类型：一级分类、二级分类、分类依据；分类必须基于视频内容，二级分类保持粗粒度。
4. 表达偏差：哪些是真实玩法，哪些是剪辑强化、伪玩法、夸张宣传或隐喻演出。
5. 可用性判断：品类是否贴合，夸张是否有解释空间，平台是否已有通过或投放先例。
6. 数据判断：本次可得数据层级是什么；T0/T1/T2 哪些指标可用；消耗、首次付费率、付费率、首次付费成本、付费成本、激活成本、CTR、eCPM 是否成立。
7. 动作建议：放量、复测、改版、暂停、补证据、补竞品、补产品录屏。

分析输出中必须增加“素材类型复盘”小节：

- 各一级/二级分类的素材数量。
- 各分类常见 hook 和表达模式。
- 各分类 T0/T1/T2 表现对比。
- 哪些类型适合复刻，哪些只适合小预算验证。
- 分类不确定的素材清单及原因。

分析输出中还必须增加“跑量能力 × 数据质量”总结：

- 什么类型更容易跑量，且 T0/T1/T2 数据好。
- 什么类型数据好，但难以跑量。
- 什么类型好跑量，但数据较差。
- 什么类型既难跑量，数据也较差。

跑量能力和数据质量必须分开判断。跑量能力主要看消耗规模、曝光/激活规模、放量后成本稳定性和素材衰减；数据质量优先看 T0，其次 T1，T2 只作为前链路解释。不能只因为消耗大就说数据好，也不能只因为付费成本好就说容易跑量。

分析输出中必须增加“起量元素归因”小节：

- 识别可能带来起量的元素，例如角色、怪物、Boss、地图、技能、特效、阵容、奖励、福利、数值膨胀、失败压力、爽感反馈、视觉反差等。
- 每个元素都要说明出现在哪些素材中、对应素材的跑量能力和 T0/T1/T2 表现。
- 只能把元素标记为“可能起量因素”，不能在缺少对照素材或足够样本时断言因果。
- 如果多个起量素材共享同一元素，应优先建议围绕该元素做变体复测。

结论必须按当前可得数据排序，而不是按玩法真实度排序。有 ROI 或净收益时按收益排序；没有收益数据时按本次指定代理指标排序，并明确“这不是最终 ROI 结论”。可以说“这个虚假玩法素材当前获量效率优于真实玩法素材”，也可以说“这个真实玩法素材当前质量代理指标优于虚假玩法素材”，但依据必须来自实际数据。

结论置信度分四级：

- `confirmed`：数据样本、素材映射、产品承接都充分。
- `probable`：数据方向清楚，但还需要更多日期或渠道验证。
- `hypothesis`：只是创意假设，需要下一轮测试。
- `blocked`：素材映射、样本量或产品证据不足。

结论类型必须显式标注：

- `profit_conclusion`：有收益或 ROI 支持。
- `t0_conclusion`：有 T0 指标支持，可作为当前项目的核心素材判断。
- `t1_conclusion`：有首次付费率、首次付费成本或激活成本等 T1 指标支持，可做阶段性质量和获量成本判断。
- `t2_conclusion`：只有点击率、eCPM 等 T2 指标支持，只能解释前链路吸引力和流量价格。
- `quality_conclusion`：有留存、付费、关键行为或 T0 付费指标支持。
- `acquisition_conclusion`：只有获量效率支持，例如激活成本、CTR、CPI、IPM、消耗和规模。
- `delivery_observation`：只有投放现象记录，不能转成优劣判断。

对含虚假玩法或夸张宣传的素材，不使用“真实/不真实”一刀切判断。建议用以下动作标签：

- `scale_as_acquisition_hook`：可作为获量主 hook 放量。
- `scale_with_monitoring`：可继续投放，但要监控后链路和审核风险。
- `keep_with_explanation_bridge`：保留虚假或夸张表达，同时补强解释桥。
- `amplify_with_variant`：该表达有效，可以继续做更大尺度或不同包装的变体。
- `revise_scale_only`：方向有效，只需要控制夸张尺度。
- `isolate_for_acquisition`：只作为获量测试，不沉淀为产品表达主线。
- `pause_for_quality_gap`：点击或成本好看，但后链路质量损伤过高。
- `scale_because_profit_wins`：即使留存或玩法匹配较弱，最终收益更高，可以放量。
- `prefer_true_gameplay_because_profit_wins`：真实玩法素材在成本和收益上胜出，应优先放量。
- `needs_policy_review`：审核边界不清，需要人工确认。

## 7. 数据质量闸门

以下情况不能输出“赢家/输家”定论：

- 数据表素材 ID 没有映射到 `material_id/version_id`。
- 素材文件名未能提取素材 ID，且没有人工映射或可靠兜底匹配。
- 同一个素材 ID 对应多个候选文件或多个候选素材版本，且未人工确认。
- 素材没有标注 `expression_fidelity`、`exaggeration_type`、`category_fit` 或 `claim_elasticity`。
- 单条素材或素材版本消耗低于 300。
- 单条素材或素材版本激活数低于 5。
- 花费、曝光、点击或安装低于 `metrics-policy.md` 的最小样本门槛。
- 不同市场、渠道、版位混在一起但未分层。
- 同一素材版本在同一天重复导出且未去重。
- 素材版本实际不同，但被映射成同一个 `version_id`。
- 没有声明本次使用的数据层级、T0/T1/T2 可用性和代理判断指标。

样本不足素材的处理方式：

- 不能判断素材质量好坏，不能进入类型优劣总结。
- 可以初步判断为吸量能力不足或未起量。
- 需要单独输出样本不足清单，记录消耗、激活数、点击率、eCPM 和可能原因。
- 如果该素材点击率高但消耗/激活不足，应标记为“有吸引信号但未起量”，而不是直接判差。

以下情况不能输出“最终收益赢家”定论，但可以输出“阶段性赢家”或“代理指标赢家”：

- D7、ROI、留存等指标尚未成熟。
- 只有前链路指标，没有收入、付费、LTV、ROAS 或 ROI。
- 只有 CTR/CPI/IPM 表现，没有后链路质量指标。
- 只有 T2 指标，没有 T0 或 T1。
- 只有短期数据，尚未覆盖素材衰减和放量后的成本变化。

以下情况不能输出“稳定放量该表达”的结论，但可以输出“小预算继续测试”：

- 广告素材中的主要玩法跨出产品品类或相邻品类，且没有清晰解释桥。
- 只看到 CTR/CPI 变好，没有后链路质量指标或足够成熟的留存/ROI。
- 已知素材造成明显用户预期错配，且后链路质量损伤超过获量收益。
- 审核状态未知，表达又依赖重度夸张承诺，且没有同类投放先例。

以下情况必须允许输出“虚假玩法优于真实玩法”：

- 虚假玩法素材 CPI 明显更低，安装或付费规模更大。
- 虚假玩法素材虽然留存或付费率较低，但 LTV、ROAS、ROI 或净收益仍优于真实玩法素材。
- 相同预算下，虚假玩法素材带来的最终收益更高，且质量损耗可接受。
- 平台投放状态稳定，没有因为素材尺度导致不可控审核损耗。
- 如果没有收益数据，也可以输出“虚假玩法在获量效率上优于真实玩法”，但必须标注为 `acquisition_conclusion`。

以下情况必须允许输出“真实玩法优于虚假玩法”：

- 真实玩法素材成本不高，且后链路质量明显更好。
- 虚假玩法素材前链路便宜，但留存、付费或 ROI 损伤过大。
- 真实玩法素材可放量规模足够，且最终收益更高。
- 如果没有收益数据，也可以输出“真实玩法在质量代理指标上优于虚假玩法”，但必须标注为 `quality_conclusion` 或 `acquisition_conclusion`。

## 8. Skill 路由扩展建议

在 `SKILL.md` 中新增路线，但不改变现有路线语义：

| 用户意图 | 路线 | 脚本 |
| --- | --- | --- |
| 登记本产品广告素材 | `material-import` | `scripts/import-product-materials.ps1` |
| 导入分日投放数据 | `performance-import` | `scripts/import-performance-data.ps1` |
| 结合素材和投放数据分析 | `material-performance-analysis` | `scripts/analyze-material-performance.ps1` |
| 将确认结论写回记忆 | `memory-sync` | `scripts/sync-performance-memory.ps1` |

现有 `single` 和 `mix` 仍用于参考素材拆解；`recording-evidence` 仍只服务真实游戏录屏证据；新路线用于本产品已投放广告素材和真实投放数据复盘。

## 9. 代号守卫的初始落位

`daihao-shouwei` 当前已经有产品目录、真实游戏录屏证据和“广告表达分析待补证据框架”。这些录屏不是广告素材，只能作为玩法事实和资产边界参考。下一步适配时优先补：

1. `products/daihao-shouwei/performance/` 目录与模板。
2. `products/daihao-shouwei/materials/<material-id>/` 素材卡片结构。
3. 每条实际投放广告素材的 `expression-deviation.md`，标记真实玩法、伪玩法、夸张宣传、品类贴合度、解释空间和投放状态。
4. 平台 creative/ad 到本地素材版本的映射表。
5. 第一个 `analyses/<date>-material-performance-review/` 分析包。
6. `memory/performance-learnings.md`，用于保存经确认的数据复盘结论。

这会把之前缺失的“本产品实际投放素材”“广告表达偏差”“解释桥”和“投放表现证据”补齐，使后续广告素材建议可以从“待补证据框架”升级为可执行复盘。

## 10. 分阶段实施

### Phase A：结构与模板

- 新增 `performance/`、`analyses/`、`memory/performance-learnings.md` 模板。
- 扩展 `materials/material-index.yaml` schema。
- 新增 `material-card.md` 和 `expression-deviation.md` 模板。
- 更新 `products/README.md` 和 `PROMPT_USAGE.md`。

### Phase B：数据导入和映射

- 增加 `import-performance-data.ps1`。
- 增加字段映射配置和数据质量报告。
- 增加 `creative-material-map.yaml`。

### Phase C：分析包生成

- 增加 `analyze-material-performance.ps1`。
- 生成 `ai-input-pack.md`、聚合 JSON、素材特征矩阵和数据质量报告。
- AI 基于分析包补写 `findings.md` 与 `recommendations.md`。

### Phase D：记忆沉淀

- 增加 `sync-performance-memory.ps1`。
- 只同步人工确认的结论。
- 回归测试覆盖：导入、映射、分析包、缺映射阻断、低样本阻断。
