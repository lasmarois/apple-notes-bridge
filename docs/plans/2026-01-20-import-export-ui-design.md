# Import/Export UI Integration Design

> Search UI integration for import/export with queue-based workflow

## Overview

Add import/export capabilities to the Notes Search app via a collapsible right sidebar panel. Users build an "export queue" while searching, then execute when ready. Import mirrors this with a staging area for files.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Panel style | Right sidebar (collapsible) | Non-modal, can search while viewing queue |
| Export selection | Queue-based ("shopping cart") | Build selection over multiple searches |
| Queue persistence | Memory only | Simpler, avoids stale data |
| Adding to queue | Individual + multi-select + Add All | Maximum flexibility |
| Import workflow | Staging area (mirrors export) | Consistent UX |
| Panel access | Toolbar buttons + menu bar + shortcuts | Discoverable and accessible |

## Layout

```
┌────────────────────────────────────────────────────────────────────┐
│ [Search icon] ________________________  [Export (3)] [Import]      │
├────────────┬─────────────────────────┬─────────────────────────────┤
│  SEARCH    │    NOTE PREVIEW         │   IMPORT/EXPORT PANEL       │
│  RESULTS   │                         │   [Export] [Import] tabs    │
│            │                         │                             │
│ ☐ Note 1   │   Title                 │   Queued for Export (3)     │
│   [+ Add]  │   Content preview...    │   ┌───────────────────────┐ │
│            │                         │   │ ☑ Note A    [×]       │ │
│ ☐ Note 2   │                         │   │ ☑ Note B    [×]       │ │
│   [+ Add]  │                         │   │ ☑ Note C    [×]       │ │
│            │                         │   └───────────────────────┘ │
│ ☐ Note 3   │                         │                             │
│   [+ Add]  │                         │   Format: [Markdown ▼]      │
│            │                         │   ☑ Include frontmatter     │
│            │                         │   ☐ Include attachments     │
│            │                         │                             │
│            │                         │   [Choose Location...]      │
│            │                         │   ━━━━━━━━━━━━━━━━ 0%       │
│            │                         │   [Clear Queue] [Export]    │
└────────────┴─────────────────────────┴─────────────────────────────┘
```

## Export Tab

### Adding to Queue

Three methods to add notes:

1. **Individual "+" button** - On each search result row
2. **Multi-select** - Cmd+click or Shift+click, then "Add Selected"
3. **"Add All Results"** - Button above results list

Duplicate additions are ignored (note already in queue).

### Queue Display

Notes grouped by folder (collapsible):

```
▼ Work (2)
  ☑ Project Notes    [×]
  ☑ Meeting Summary  [×]
▼ Personal (1)
  ☑ Travel Plans     [×]
```

Each item shows:
- Checkbox (checked by default)
- Note title
- Remove button [×]

### Export Options

| Option | Type | Values |
|--------|------|--------|
| Format | Dropdown | Markdown, JSON |
| Include frontmatter | Checkbox | Markdown only |
| Include attachments | Checkbox | Both formats |
| JSON detail level | Dropdown | Minimal, Full (JSON only) |

### Export Flow

1. Build queue via search
2. Click "Choose Location..." → folder picker
3. Click "Export" → progress bar animates
4. Completion: success message with "Open in Finder" option
5. "Clear Queue" to reset

## Import Tab

### Adding Files

1. **"Add Files..." button** → file picker (.md, .json)
2. **"Add Folder..." button** → folder picker (recursive scan)
3. **Drag and drop** onto panel

### Staging Display

```
┌─────────────────────────────────────────────┐
│ Files to Import (5)                         │
├─────────────────────────────────────────────┤
│ ☑ Meeting Notes.md          → Notes     ✓  │
│ ☑ Project Ideas.md          → Work      ✓  │
│ ☑ Shopping List.md          → Notes     ⚠  │
│ ☑ Travel Plans.md           → Travel    ✓  │
│ ☑ Recipe.md                 → Notes     ✓  │
└─────────────────────────────────────────────┘
```

Status icons:
- ✓ Ready to import
- ⚠ Conflict detected (click for details)

### Conflict Handling

Per-file dropdown: Skip / Replace / Duplicate

Global option: "Apply to all conflicts: [Skip ▼]"

### Import Options

| Option | Type | Values |
|--------|------|--------|
| Default folder | Dropdown | Existing folders |
| On conflict | Dropdown | Skip, Replace, Duplicate |

### Import Flow

1. Add files via picker or drag-drop
2. Automatic conflict detection runs
3. Review staging, resolve conflicts
4. Click "Import" → progress bar
5. Completion summary: "Imported 4, Skipped 1"

## Progress & Feedback

### During Operation

```
┌─────────────────────────────────────────────┐
│ Exporting notes...                          │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░ 75%  │
│ Note 9 of 12: "Meeting Notes"               │
│                               [Cancel]      │
└─────────────────────────────────────────────┘
```

### Success

```
┌─────────────────────────────────────────────┐
│ ✓ Export Complete                           │
│ Exported 12 notes to ~/Desktop/backup       │
│ [Open in Finder]  [Clear Queue]  [Done]     │
└─────────────────────────────────────────────┘
```

### Partial Failure

```
┌─────────────────────────────────────────────┐
│ ⚠ Export Completed with Errors              │
│ Exported: 10  |  Failed: 2                  │
│ ┌─────────────────────────────────────────┐ │
│ │ ✗ "Old Note" - Decode error             │ │
│ │ ✗ "Corrupted" - File write failed       │ │
│ └─────────────────────────────────────────┘ │
│ [View Details]  [Retry Failed]  [Done]      │
└─────────────────────────────────────────────┘
```

## Toolbar & Access

### Toolbar Layout

```
┌────────────────────────────────────────────────────────────────────┐
│ 🔍 [____Search notes..._____] [x]     [Export (3)] [Import]  [⚙]  │
└────────────────────────────────────────────────────────────────────┘
```

- Export button shows badge with queue count
- Clicking toggles panel, switches to respective tab

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘E | Open/close Export panel |
| ⌘I | Open/close Import panel |
| ⌘⇧E | Add selected note to export queue |
| ⌘⌥E | Add all search results to queue |

### Menu Bar (File)

```
File
├── Export...          ⌘E
├── Import...          ⌘I
├── ─────────────────
├── Add to Export      ⌘⇧E
└── Add All to Export  ⌘⌥E
```

## Architecture

### Component Structure

```
NotesSearchApp
├── ContentView
│   ├── SearchSidebar (existing)
│   ├── NotePreview (existing)
│   └── ImportExportPanel (NEW)
│       ├── ExportTab
│       │   ├── ExportQueue
│       │   ├── ExportOptions
│       │   └── ExportProgress
│       └── ImportTab
│           ├── ImportStaging
│           ├── ImportOptions
│           └── ImportProgress
└── ViewModels
    ├── SearchViewModel (existing, extended)
    ├── ExportViewModel (NEW)
    └── ImportViewModel (NEW)
```

### New Files

| File | Purpose |
|------|---------|
| `ImportExportPanel.swift` | Main panel container with tabs |
| `ExportTab.swift` | Export queue UI and options |
| `ImportTab.swift` | Import staging UI and options |
| `ExportViewModel.swift` | Export queue state and operations |
| `ImportViewModel.swift` | Import staging state and operations |

### Integration Points

- **NotesExporter** (existing) - Called by ExportViewModel
- **NotesImporter** (existing) - Called by ImportViewModel
- **SearchViewModel** - Extended with `addToExportQueue()` methods

### State Management

```swift
// ExportViewModel
@Published var queue: [ExportItem] = []
@Published var isExporting: Bool = false
@Published var progress: ExportProgress?
@Published var exportOptions: ExportOptions

// ImportViewModel
@Published var staging: [ImportFile] = []
@Published var isImporting: Bool = false
@Published var progress: ImportProgress?
@Published var importOptions: ImportOptions
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Add duplicate to queue | Ignored, note already queued |
| Export empty queue | Export button disabled |
| Close panel during export | Prompt to cancel or continue |
| Import file with no title | Use filename as title |
| Very long note title | Truncate with ellipsis in queue |
| Export cancelled mid-way | Keep completed, discard remaining |

## Future Enhancements (Out of Scope)

- Export scheduling (export at specific time)
- Export presets (save option combinations)
- Cloud export destinations (Dropbox, iCloud Drive)
- Import from URL
- Batch conflict resolution preview
