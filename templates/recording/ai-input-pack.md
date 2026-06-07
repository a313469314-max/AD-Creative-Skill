# Product Recording AI Input Pack

Read this file before analyzing the recording evidence.

## Scope

- This is one product recording directory only.
- Do not read sibling recording directories.
- Do not create a six-video summary unless the user explicitly asks for it.
- Do not use the original video as chat input; use the local evidence files.

## Paths

- Recording directory: {{RecordingRootPath}}
- Source video: {{SourceVideo}}
- Metadata: {{MetadataPath}}
- Frame index: {{FrameIndexPath}}
- Review contact sheet: {{ReviewContactSheetPath}}
- Review frames directory: {{ReviewFramesDir}}
- Detail contact sheet: {{ContactSheetPath}}
- Detail frames directory: {{FramesDir}}
- Source notes: {{SourceNotesPath}}
- Recording analysis: {{AnalysisPath}}

## Context Budget Rules

- Default visual input: open evidence/review/contact-sheet.jpg first.
- Use review_relative_file entries from frame-index.json for ordinary frame checks.
- Treat evidence/contact-sheet.jpg and evidence/frames as local detail evidence, not default chat inputs.
- Only open the detail contact sheet or detail frames when review evidence cannot resolve UI text, asset identity, or a critical gameplay state.
- Open at most 2-3 detail frames per turn, and name the exact frame indexes before opening them.

## Analysis Rules

- Base conclusions on the review contact sheet, review frames, video_metadata.json, and frame-index.json.
- Use detail frames only for targeted confirmation after identifying exact timestamps or frame indexes.
- Bind observations to timestamps or frame indexes where possible.
- If the evidence does not cover a system, mark it as not covered.
- Theme and art analysis is required.
- Do not write ad scripts, production storyboards, prompts, or production assets.
- This recording analysis is evidence only. It does not automatically update long-term product facts.
