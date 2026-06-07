# AI 输入包：{{Name}}

请先阅读此文件，再查看关键帧联系表和 frame-index。

## 路径

- 方法库：{{MethodologyPath}}
- 全文方法论索引：{{FullMethodologyIndexPath}}
- 方法库相对路径：methodology/ad-creative-methodology.md
- 全文方法论相对路径：methodology/full/README.md
- 素材文件夹：{{MaterialDir}}
- 源视频：{{DestVideo}}
- 关键帧联系表：{{FinalSheet}}
- 帧索引：{{FrameIndexPath}}
- 参考分镜：{{ReferencePath}}
- 创意方向：{{DirectionsPath}}
- 产品信息：{{ProductBriefOutputPath}}

## 可选产品目录

{{ProductContextMarkdown}}

## 当前产品录屏上下文

如果本次对话另附当前产品真实游戏录屏，请把它作为本次任务局部的产品依据来分析；如果需要落盘，只能放进该游戏自己的 products/<product-id>/recordings/，不要影响其他游戏或其他素材分析。

当前产品录屏必须分析核心玩法体验链路、首个可验证体验、首个爽点或关键反馈出现时间、题材与美术、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产、真实可承接 hook 和不可编造边界。

## 视频信息

- 时长：{{DurationRounded}} 秒
- 尺寸：{{Width}}x{{Height}}
- FPS：{{Fps}}
- 选帧数量：{{StoryboardFrames}}

## 第一阶段规则

- 先阅读方法库，按素材缺口选择采用方法和排除方法。
- 全文方法论仅用于按需补充解释、方法细节、案例机制或未来 Phase2 设计，不能覆盖 Phase1 边界。
- 如果提供了产品目录，必须先以 product-profile 和 gameplay-systems 作为产品事实，再用 hook-mapping、asset-inventory、recordings、当前产品 materials/memory、根级 competitors 模块和 playbooks 做适配判断。
- 广告表达形式、素材结构、测试优先级或创意方向池不能只根据当前产品录屏得出；必须同时结合当前产品具体素材和同玩法竞品素材。竞品素材只能放在根级 competitors/ 模块，不能放进 products/<product-id>/。
- 如果本次对话另附当前产品真实游戏录屏，题材与美术分析是必做项：题材类型、世界观内容壳、美术风格、角色/单位卖相、敌人/Boss 卖相、场景卖相、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产和不适合作为广告开头的画面都必须进入判断；该录屏分析只用于本次产品判断。
- 补写 reference-video-storyboard.md。
- 补写 creative-script-directions.md。
- reference-video-storyboard.md 只拆解原参考视频，不是 production storyboard。
- 做产品映射时请使用 product-brief.md。
- 如果 product-brief.md 仍包含 TODO，或缺少产品特定信息，不要编造产品事实；输出缺失问题，并把产品映射保持为待补充状态。
- 只创建故事方向池。
- 在用户选择方向之前，不要创建 production storyboard、production scripts、prompts 或 script-* 文件夹。
