# Goal-12: Progress Log

## Session: 2026-01-20 (continued)

### Completed Today
1. **Unified Streaming Search** - All search engines run in parallel
2. **Source Badges** - Show which search found each result
3. **Keyboard Navigation** - ↑/↓ arrows, Enter, Escape
4. **Auto-scroll** - List scrolls to keep selection visible
5. **Build Instructions** - Added `.claude/rules/build.md`

### Now Working On
**Rich Text Preview** - Render notes with proper formatting (titles, headings, code blocks)

### Investigation Findings
- Protobuf stores `attribute_run` (field 5) with style info
- Style types: 0=body, 1=title, 2=heading, 3=subheading, 4=monospaced
- Need to enhance NoteDecoder to extract these
- Will convert to HTML and render with WKWebView

## Session: 2026-01-20 (continued - after clear)

### Previous Session Findings (recovered)
- Created `dump_protobuf.swift` - raw protobuf dumper
- Added debug methods to `Database.swift`
- **Key Discovery**: Tables stored as separate objects
  - Note protobuf field 12 contains table reference (UUID + "com.apple.notes.table")
  - `U+FFFC` placeholder marks table position in text
  - Actual table data in separate DB row

### Completed Today (Phase 6)
1. **Extracted table references** from note protobuf (field 12 in attribute_run)
2. **Added fetchTableData()** to Database.swift - fetches ZMERGEABLEDATA1 by UUID
3. **Implemented CRDT parser** - extracts cell text from Field 10 messages
4. **Connected table rendering** - tables now display in note preview
5. **Tested** with Typography Showcase note - tables render correctly!

### Debugging Session (continued)
- Initial table implementation caused app hang on search
- Root cause: `parseAttributeRunWithTable` used `try?` which caused silent failures
- Fix: Rewrote to use `do/catch` pattern like working `parseAttributeRun`
- Added `includeTables: Bool` param to `readNote` to skip table fetch during indexing
- Current: App works, debugging why tables don't render

### Table Support Complete ✅
Fixed all table rendering issues:
1. **Search hang** - Disabled blocking content search, made FTS index build async
2. **CRDT decompression** - Table data is gzipped, added decompression step
3. **Position matching** - Match tables to U+FFFC placeholders by order, not exact position
4. **Character tracking** - Fixed toHTML() to use character positions instead of bytes

Tables now render inline with content before and after displaying correctly.

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Goal-12 (M9) - Complete with table support |
| Where am I going? | Goal complete, ready for next task |
| What's the goal? | Visual search with formatted note preview including tables |
| What have I learned? | CRDT data is gzipped; position matching by order is more robust |
| What have I done? | Full table rendering working |
