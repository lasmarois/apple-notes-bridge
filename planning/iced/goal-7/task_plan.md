# Goal 7: M6.5 - Rich Text Support

## Objective
Test and ensure clean support for all Notes.app typography features: formatting, fonts, colors, emojis, links, tags, and other rich text elements.

## Current Phase
Phase 5 (Fix Issues & Document)

## Phases

### Phase 1: Research Rich Text Storage
- [x] Understand how rich text is stored (protobuf structure)
- [x] Understand how AppleScript handles rich text (HTML body)
- [x] Create test note with all formatting types
- [x] Document current read/write capabilities
- **Status:** complete

### Phase 2: Test Typography Reading
- [x] Bold, italic, underline, strikethrough
- [x] Headings (Title, Heading, Subheading)
- [x] Lists (bullet, numbered, checklist)
- [x] Document what's preserved vs lost
- **Status:** complete

### Phase 3: Test Additional Features Reading
- [x] Fonts and font sizes
- [x] Text colors and highlights
- [x] Emojis
- [x] Links (URLs, mailto, note links)
- [x] Hashtags/tags
- [ ] Tables
- **Status:** complete

### Phase 4: Test Writing Rich Text
- [x] Test AppleScript HTML body formatting
- [x] Test what formatting survives create/update
- [x] Document limitations
- **Status:** complete

### Phase 5: Fix Issues & Document
- [x] Add `format` parameter to read_note (plain/html)
- [x] Document supported vs unsupported features
- [x] Add `list_note_links` tool
- [x] Add `noteLinks` field to NoteContent
- [x] Update hashtag/link implementation to use embedded objects (ZTYPEUTI1)
- **Status:** complete

### Phase 6: Archive Goal
- [ ] Update ROADMAP.md
- [ ] Move files to planning/history/goal-7/
- [ ] Commit
- **Status:** pending

## Remaining Work

**Tables not tested:** Phase 3 skipped table testing. Need to verify:
- [ ] How tables are stored in protobuf
- [ ] How tables render when read via AppleScript HTML
- [ ] Whether tables can be created/preserved via AppleScript
- [ ] Round-trip behavior (create → read → update)

## Open Questions - ANSWERED
1. Does the protobuf decoder preserve formatting? → **NO**, only extracts plain text
2. What HTML tags does AppleScript body accept? → **b, i, u, strike, h1-h3, span style, font color/face**
3. Are hashtags stored specially or just as text? → **Stored as inline attachments** in protobuf; extractable from ZSNIPPET and ZDISPLAYTEXT
4. How are note-to-note links represented? → **NOT SUPPORTED** - AppleScript strips href
5. Can hashtags be created programmatically? → **NO** - AppleScript writes `#tag` as plain text, Notes doesn't auto-convert to inline attachment

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Add `format` parameter to read_note | Allow users to choose plain (fast, DB) or html (rich text, AppleScript) |
| Keep plain as default | Most use cases need text content, HTML is opt-in |
| Add `list_hashtags` tool | Allows discovering all tags used across notes |
| Add `search_by_hashtag` tool | Enables finding notes by tag |
| Extract hashtags from ZSNIPPET | More reliable than parsing protobuf inline attachments |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
