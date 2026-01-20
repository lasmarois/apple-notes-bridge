# Goal-12: Search UI (M9) - Rich Text Preview

## Objective
Add rich text rendering to the note preview to match Apple Notes appearance.

## Current Phase
Phase 5: Rich Text Preview (in progress)

## Phases

### Phase 1: Project Setup ✅
- [x] Add new macOS app target to Package.swift
- [x] Create basic SwiftUI app structure
- [x] Configure entitlements (Full Disk Access check)

### Phase 2: Search Interface ✅
- [x] Search bar with debounced input
- [x] Search mode selector → unified search
- [x] Results list with note title, folder, date
- [x] Source badges (Title/Content/AI/Multiple)

### Phase 3: Note Preview ✅
- [x] Split view: results | preview
- [x] Render note content (plain text)
- [x] Show metadata (folder, dates, hashtags)

### Phase 4: Actions & Polish ✅
- [x] "Open in Notes.app" button
- [x] Copy note ID/content
- [x] Keyboard navigation (↑/↓, Enter, Escape)
- [x] Auto-scroll to selected result
- [x] Dark mode support

### Phase 5: Rich Text Preview (in progress)
- [ ] Enhance NoteDecoder to extract attribute_runs from protobuf
- [ ] Create StyledNoteContent struct with text + style info
- [ ] Add HTML conversion from styled content
- [ ] Update NoteContent model with htmlContent field
- [ ] Replace Text view with WKWebView for HTML rendering
- [ ] Style HTML to match Notes.app appearance

## Architecture

### Protobuf Structure (from Encoder.swift)
```
NoteStoreProto {
  document(2) {
    note(3) {
      note_text(2): String
      attribute_run(5)[]: {
        length(1): Int
        paragraph_style(2): {
          style_type(1): Int  // 0=body, 1=title, 2=heading, 3=subheading, 4=monospaced
          alignment(2): Int
        }
      }
    }
  }
}
```

### Style Types
| Value | Style |
|-------|-------|
| 0 | Body (normal text) |
| 1 | Title |
| 2 | Heading |
| 3 | Subheading |
| 4 | Monospaced (code) |
| 100 | Checkbox unchecked |
| 101 | Checkbox checked |

### Implementation Plan
1. **NoteDecoder** - Add `decodeStyled()` method returning (text, attributeRuns)
2. **StyledContent** - New struct holding text + runs
3. **HTMLRenderer** - Convert styled content to HTML
4. **NoteContent** - Add optional `htmlContent` field
5. **NotePreviewView** - Use WKWebView when HTML available

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use WKWebView for HTML | Native rendering, supports all styling |
| Extract styles from protobuf | Database has all info, just need to parse |
| Keep plain text fallback | Graceful degradation if parsing fails |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
