# 产品目录与增强包

每个独立游戏产品必须有一个专门目录：`products/<product-id>/`。该目录用于隔离这个产品的真实录屏、录屏分析、产品事实、素材记忆、产品专属 playbook 和后续复盘文件，避免不同游戏的判断互相污染。

产品增强包是产品目录中可长期复用的那部分资料。通用 skill 负责参考视频处理、方法论和 Phase1 方向池；产品目录提供产品事实、真实承接边界、可用资产、录屏证据、历史素材记忆和玩法表达建议。

真实游戏录屏默认只是当前任务的产品依据。如果需要落盘，必须放到对应产品目录的 `recordings/` 下；这不等于自动更新长期产品事实。只有用户明确要求保存为长期产品资料时，才把录屏分析结论同步到 `product-profile.md`、`gameplay-systems.md`、`asset-inventory.md` 等文件。

`products/<product-id>/materials/` 和 `memory/` 只保存当前产品自己的素材、测试表现、成功/失败模式和复盘结论。竞品素材不属于任何单个产品目录，必须放在根级独立模块 `competitors/`。

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
