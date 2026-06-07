# 竞品素材模块

本模块用于保存同玩法、同市场或同投放场景的竞品广告素材、优秀案例和品类表达观察。竞品素材必须独立于 `products/<product-id>/`，不能放进具体产品目录，也不能覆盖产品事实。

## 使用边界

- `products/<product-id>/recordings/`：当前产品真实录屏，只证明产品实际能玩到什么。
- `products/<product-id>/materials/` 和 `products/<product-id>/memory/`：当前产品自己的素材、测试表现、成功/失败模式。
- `competitors/`：竞品或品类素材，只用于判断同玩法常见表达、平台素材语法、差异化机会和风险。

广告表达形式、素材结构、测试优先级或创意方向池，必须同时结合当前产品玩法事实、本产品具体素材和本模块中的同玩法竞品素材。缺少任一类证据时，只能输出待补证据清单和分析框架，不能给出定稿式表达结论。

## 推荐结构

```text
competitors/
  competitor-index.yaml
  <category-or-playstyle>/
    category-notes.md
    material-index.yaml
    materials/
      <competitor-material-id>/
        source-notes.md
        analysis.md
        evidence/
```

## 记录字段

每条竞品素材至少记录：

- `competitor_id`：竞品或案例标识。
- `category`：玩法品类或素材语法类别。
- `source_path_or_link`：素材来源。
- `market_channel`：市场、平台或投放渠道。
- `core_hook`：开头抓点。
- `creative_structure`：素材结构。
- `gameplay_claim`：它宣称或展示的玩法。
- `proof_style`：如何证明用户下载后能获得对应体验。
- `transferable_pattern`：可迁移的结构。
- `non_transferable_surface`：不可照搬的表层题材、包装或风险点。
- `risk_notes`：合规、误导、产品无法承接或同质化风险。

## 关系规则

- 竞品素材可以影响广告表达假设，不能定义当前产品事实。
- 如果竞品结构需要的系统在当前产品录屏或产品资料中不存在，必须标记为不适配。
- 竞品素材和本产品历史素材要分开复盘；不要把竞品表现当作本产品已验证表现。
