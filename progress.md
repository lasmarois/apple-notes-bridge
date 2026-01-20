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

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 5: Rich Text Preview |
| Where am I going? | Styled note preview matching Notes.app |
| What's the goal? | Visual search with formatted note preview |
| What have I learned? | Protobuf has style info in attribute_run |
| What have I done? | Keyboard nav, unified search, investigating rich text |
