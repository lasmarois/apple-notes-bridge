# Goal 7: Progress Log

## Session: 2026-01-19

### Phase 1-4: Research & Testing
- **Status:** complete
- **Started:** 2026-01-19
- Created test notes with various formatting (bold, italic, colors, fonts, emojis)
- Tested protobuf decoder - extracts plain text only
- Tested AppleScript HTML body - preserves formatting
- Documented supported vs unsupported features (see findings.md)

### Phase 5: Fix Issues & Document
- **Status:** in_progress
- Added `format` parameter to `read_note` tool (plain/html)
- Added `getNoteBody()` to AppleScript.swift
- Added `getNotePK()` to Database.swift
- HTML format returns rich text with formatting preserved
- **Hashtag features added:**
  - `list_hashtags` tool - lists all unique hashtags (55 found in test)
  - `search_by_hashtag` tool - finds notes by tag
  - Hashtags now included in note metadata (extracted from ZSNIPPET)
  - `getHashtags()`, `listHashtags()`, `searchNotesByHashtag()` in Database.swift

### Key Findings
- **Write:** AppleScript HTML body supports most formatting
- **Read (plain):** Protobuf decoder extracts plain text only (fast)
- **Read (html):** AppleScript body returns HTML with formatting (slower)
- **Hashtags:** Read-only - can list, search, extract but cannot create programmatically
- **Note Links:** Read-only - can list and read but cannot create via AppleScript

### Session 2 Progress (2026-01-19)
- Investigated `macnotesapp` and `apple-notes-parser` projects
- Discovered proper embedded objects approach:
  - `ZTYPEUTI1` + `ZALTTEXT` for hashtags
  - `ZTOKENCONTENTIDENTIFIER` for note links
- Updated implementation to use embedded objects table
- Added `list_note_links` tool (found 24 links)
- Added `noteLinks` field to `NoteContent` model
- Note-to-note links now included in `read_note` output
- All hashtag/link features are **read-only** (confirmed limitation)

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 5 - documenting and finalizing |
| Where am I going? | Archive goal |
| What's the goal? | Ensure clean rich text support |
| What have I learned? | Plain=fast/no format, HTML=slow/formatted |
| What have I done? | Added format param, documented support matrix |
