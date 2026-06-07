# Source Notes

## 源文件

- 源视频：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\source\第二关结束主界面操作-1.mp4`
- 时长：`32.167` 秒。
- 视频规格：竖屏 `288x640`，`30 fps`，`965` 帧。
- 音频：AAC，时长 `32.136` 秒。
- 证据生成前目录状态：干净。第四段目录内仅有 `source\第二关结束主界面操作-1.mp4`。

## 证据生成

在 `D:\skills\AD-Creative-Skill` 执行：

```powershell
.\scripts\process-product-recording-evidence.ps1 `
  -RecordingDir "D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04" `
  -FrameCount 24 `
  -Columns 4 `
  -Force
```

生成的证据文件：

- 元数据：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\_system-review\video_metadata.json`
- 帧索引：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\_system-review\frame-index.json`
- AI 输入包：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\_system-review\ai-input-pack.md`
- 运行清单：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\_system-review\run-manifest.json`
- review contact sheet：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\evidence\review\contact-sheet.jpg`
- review frames：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\evidence\review\frames\source-1`
- detail contact sheet：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\evidence\contact-sheet.jpg`
- detail frames：`D:\skills\AD-Creative-Skill\products\daihao-shouwei\recordings\2026-06-06-video-04\evidence\frames\source-1`

## 已读取/查看的输入

- 只读取了轻量文本证据：`_system-review\video_metadata.json`、`_system-review\frame-index.json`、`_system-review\ai-input-pack.md`、`_system-review\run-manifest.json`。
- 打开了 1 张视觉总览：`evidence\review\contact-sheet.jpg`。
- 只额外打开了 2 张关键 detail 帧：`evidence\frames\source-1\frame-013.jpg`、`evidence\frames\source-1\frame-017.jpg`。
- 未打开兄弟录屏目录、旧 session、旧 log，也未分析其他视频段落。

## 覆盖说明

- 第四段覆盖第二关结束后的主界面操作：地图页、角色/养成页、技能或奖励说明、英雄阵容浏览、装备对比、首充/礼包商业化弹窗、下一关战斗准备与加载。
- 强证据包括：`尘垢腰带` 装备对比，攻击 `10` 提升到 `27`；首充/礼包弹窗中的 `¥6`、`召唤英雄+1`、`500%返利` 与分日奖励。
- 当前视频没有展示下一关真实战斗。
- 当前证据不足以确认技能弹窗完整文案、金色奖励的具体内容、以及该视频之外的任何系统事实。
