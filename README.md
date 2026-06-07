# AD Creative Skill

这是一个面向游戏买量广告参考视频的 Codex Skill。它不是传统 App，而是一套本地工作流：先把视频和录屏转成可复查的证据包，再让 AI 基于证据、产品资料和方法论做 Phase1 创意分析。

## 核心目录

```text
SKILL.md                 # AI 路由和执行规则
AI_HANDOFF.md            # 接手说明
PROMPT_USAGE.md          # 人类提示词调用指南
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
