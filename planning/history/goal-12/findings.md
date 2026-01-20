# Goal-12: Findings

## SwiftUI macOS App Structure

### Package.swift App Target
```swift
.executableTarget(
    name: "NotesSearch",
    dependencies: ["NotesLib"],
    path: "Sources/NotesSearch"
)
```

### Basic App Structure
```swift
@main
struct NotesSearchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
```

### Search Debouncing
```swift
.onChange(of: searchText) { _, newValue in
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await performSearch(newValue)
    }
}
```

### Opening Notes in Notes.app
```swift
// Using AppleScript or URL scheme
NSWorkspace.shared.open(URL(string: "notes://showNote?identifier=\(noteId)")!)

// Or AppleScript for reliability
let script = "tell application \"Notes\" to show note id \"\(noteId)\""
```

## UI Patterns

### Split View
```swift
NavigationSplitView {
    // Sidebar with results
    ResultsList(results: viewModel.results, selection: $selection)
} detail: {
    // Detail pane with preview
    if let note = selection {
        NotePreview(note: note)
    } else {
        Text("Select a note")
    }
}
```

### Search Modes
- **Basic**: Title/snippet search (instant)
- **FTS**: Full-text search with snippets (fast, needs index)
- **Semantic**: AI-powered similarity (slower, ~1-2s)

## Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| ⌘F | Focus search bar |
| ↑/↓ | Navigate results |
| ⏎ | Open in Notes.app |
| ⌘C | Copy note content |
| ⎋ | Clear search |

## Table Rendering Investigation (Phase 6)

### How Tables Are Stored
Tables in Apple Notes are **NOT** inline in the note protobuf. Instead:

1. **Placeholder Character** - `U+FFFC` in note text marks where table appears
2. **Table Reference** (field 12) - Contains:
   ```
   Field 12 [len-delim]:
     Field 1: "UUID-OF-TABLE"
     Field 2: "com.apple.notes.table"
   ```
3. **Actual Table Data** - Stored as a separate object in `ZICCLOUDSYNCINGOBJECT`

### Query to Find Table Data
```sql
SELECT ZIDENTIFIER, ZTYPEUTI
FROM ZICCLOUDSYNCINGOBJECT
WHERE ZIDENTIFIER = '<table-uuid>'
```

### Table Protobuf Structure (Decoded)

Tables use Apple's **CRDT format** (Conflict-free Replicated Data Type) for collaboration.

**Storage Location**: `ZMERGEABLEDATA1` column in `ZICCLOUDSYNCINGOBJECT`

**Key Fields**:
- `Field 4`: Property names (`"crRows"`, `"crColumns"`, `"cellColumns"`)
- `Field 5`: Type identifiers (`"com.apple.notes.CRTable"`, `"com.apple.notes.ICTable"`)
- `Field 10`: **Cell content** (nested, contains actual text)
  - `Field 2`: Text string
  - `Field 5`: Style info (font, etc.)

**Cell Extraction Path**:
```
Root → Field 2 → Field 3 → Field 3 → Field 10 → Field 2 (text content)
```

**Example cells found**:
- "Category" (header)
- "Emojis" (header)
- "Tech", "Food", "Nature", "Faces" (column 1)
- Emoji bytes: 💻📱🖥️⌨️, 🍕🍔🍟🌮, 🌸🌺🌻🌷, 😀😎🤔🥳

### Implementation Approach
1. Parse CRDT structure to extract Field 10 messages
2. Build 2D array from cell contents
3. Match row/column ordering from Field 6/Field 16 structures
4. Render as HTML table

### Complexity Note
The CRDT format is designed for collaborative editing. Full parsing requires:
- Understanding CRTree structure for row/column ordering
- Handling multiple cell versions (for conflict resolution)
- Mapping UUID indices to actual cell positions

For read-only display, we can extract cell text from Field 10 and infer structure.
