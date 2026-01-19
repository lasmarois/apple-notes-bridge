# Apple Notes Integration Options Analysis

## Executive Summary

**Chosen Approach:** Direct database access via Swift with native macOS integration.

**Rationale:**
- **Consistency** — Single source of truth, full CRUD capabilities
- **No AppleScript limitations** — Update/delete/attachments all accessible
- **Truly minimal dependencies** — SQLite + Swift runtime are built into macOS
- **Native macOS integration** — Proper app bundle, entitlements, notarization
- **Apple ecosystem alignment** — Swift for Apple's Notes database

---

## Why Database-Only

> **⚠️ CORRECTION (goal-4, 2026-01-18):** This table was WRONG about AppleScript limitations.
> AppleScript DOES support update and delete operations. See `goal-4/findings.md` for details.
> The recommended architecture is now: **Database for reads, AppleScript for writes.**

| Capability | AppleScript | Database |
|------------|:-----------:|:--------:|
| Read notes | ✅ | ✅ |
| Create notes | ✅ | ⚠️ (invisible without CloudKit) |
| **Update notes** | ✅ *(corrected)* | ⚠️ (requires CloudKit metadata) |
| **Delete notes** | ✅ *(corrected)* | ⚠️ (may leave orphans) |
| Folders | ✅ | ✅ |
| **Attachments** | ⚠️ (limited) | ✅ |
| **Rich metadata** | ❌ | ✅ |
| iCloud sync compat | ✅ (native) | ❌ (cannot forge CloudKit metadata) |

~~The database approach unlocks full CRUD + attachments that AppleScript cannot provide.~~

**Revised approach:** Hybrid architecture — AppleScript for writes (handles CloudKit), Database for reads (faster, richer metadata).

---

## Technical Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Claude Code                        │
└─────────────────────────┬───────────────────────────┘
                          │ MCP Protocol (stdio)
                          ▼
┌─────────────────────────────────────────────────────┐
│          claude-notes-bridge (Swift binary)          │
├─────────────────────────────────────────────────────┤
│  • Code-signed & notarized                          │
│  • Requests Full Disk Access on first run           │
│  • Uses system SQLite (libsqlite3)                  │
│  • Swift runtime built into macOS                   │
├─────────────────────────────────────────────────────┤
│  Tools:                                              │
│  - list_notes      - create_note                    │
│  - read_note       - update_note                    │
│  - search_notes    - delete_note                    │
│  - list_folders    - move_note                      │
│  - get_attachments                                  │
└─────────────────────────┬───────────────────────────┘
                          │ SQLite3 + Protobuf
                          ▼
┌─────────────────────────────────────────────────────┐
│     ~/Library/Group Containers/group.com.apple.notes│
│                   NoteStore.sqlite                   │
└─────────────────────────────────────────────────────┘
```

---

## Database Format (Stable Since iOS 9)

### Location
```
~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite
```

### Key Tables

| Table | Purpose |
|-------|---------|
| `ZICCLOUDSYNCINGOBJECT` | Note metadata, folders, sync state |
| `ZICNOTEDATA` | Note content (protobuf in ZDATA) |

### Protobuf Schema

Full schema available: [notestore.proto](https://github.com/threeplanetssoftware/apple_cloud_notes_parser/blob/master/proto/notestore.proto)

```protobuf
NoteStoreProto {
  Document {
    int32 version = 2
    Note {
      string note_text = 2
      repeated AttributeRun = 5  // Formatting
    }
  }
}
```

### Data Flow
```
Read:  SQLite → gzip decompress → protobuf decode → content
Write: content → protobuf encode → gzip compress → SQLite
```

---

## iCloud Sync Compatibility

### How Sync Works

CloudKit uses **change tokens** for delta sync:
1. Local changes update `ZSERVERRECORDDATA` (NSKeyedArchive)
2. Sync daemon detects changes via `ZMODIFIEDDATE1`
3. Changes pushed to iCloud, merged with other devices

### Safe Write Strategy

| Approach | Risk | Mitigation |
|----------|------|------------|
| Close Notes.app during writes | Low | Check process before write |
| Preserve CloudKit metadata | Medium | Copy existing `ZSERVERRECORDDATA` fields |
| Update `ZMODIFIEDDATE1` correctly | Medium | Use current timestamp |
| Handle WAL/SHM | Low | Proper SQLite transaction handling |
| Test with "On My Mac" first | N/A | Start with local-only notes |

### Key Sync Fields to Preserve

```sql
-- Must preserve on update:
ZIDENTIFIER           -- UUID (consistent across devices)
ZSERVERRECORDDATA     -- CloudKit CKRecord metadata
ZSERVERSHAREDATA      -- Sharing participants
ZMODIFIEDDATE1        -- Sync trigger
```

---

## Swift Implementation

### Why Swift

| Factor | Benefit |
|--------|---------|
| **Zero runtime deps** | Swift runtime ships with macOS (10.14.4+) |
| **System SQLite** | `libsqlite3.dylib` is part of macOS |
| **Native macOS** | Best integration for permissions, signing, notarization |
| **Apple ecosystem** | Swift for Apple's Notes — natural fit |
| **Protobuf** | swift-protobuf (Apple quality) or manual parsing |

### System Dependencies (Already on macOS)

```swift
import Foundation      // Built-in
import SQLite3         // System library (libsqlite3.dylib)
import Compression     // Built-in (for gzip)
```

### External Dependencies (Minimal)

```swift
// Package.swift
dependencies: [
    // Option 1: Apple's swift-protobuf
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),

    // Option 2: Manual protobuf parsing (zero deps)
    // The schema is simple enough to parse manually
]
```

### Project Structure

```
claude-notes-bridge/
├── Package.swift                 # Swift Package Manager
├── Sources/
│   └── claude-notes-bridge/
│       ├── main.swift            # Entry point
│       ├── MCP/
│       │   ├── Server.swift      # MCP protocol (stdio)
│       │   ├── Tools.swift       # Tool definitions
│       │   └── Protocol.swift    # JSON-RPC handling
│       ├── Notes/
│       │   ├── Database.swift    # SQLite access
│       │   ├── Protobuf.swift    # Note encoding/decoding
│       │   ├── Models.swift      # Note, Folder types
│       │   └── Sync.swift        # iCloud sync handling
│       └── Permissions/
│           └── FullDiskAccess.swift
├── Proto/
│   └── notestore.proto           # Apple Notes protobuf schema
└── Makefile                      # Build, sign, notarize
```

### SQLite Access (Zero Dependencies)

```swift
import SQLite3

class NotesDatabase {
    private var db: OpaquePointer?

    init() throws {
        let dbPath = NSHomeDirectory() +
            "/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"

        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw NotesError.cannotOpenDatabase
        }
    }
}
```

### Build Commands

```bash
# Build universal binary (Intel + Apple Silicon)
swift build -c release --arch arm64 --arch x86_64

# Or via Makefile
make build      # Build
make sign       # Code sign
make notarize   # Notarize with Apple
make release    # All of the above
```

---

## macOS Integration

### Full Disk Access

**No entitlement exists** — user must manually grant access.

**Best Practice Flow:**
1. On first run, check if we can read the Notes database
2. If permission denied, open System Settings to FDA panel:
   ```
   x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles
   ```
3. Show clear instructions to user
4. Poll for access until granted

### Code Signing & Notarization

```bash
# Sign the binary
codesign --sign "Developer ID Application: Your Name" \
         --options runtime \
         --timestamp \
         claude-notes-bridge

# Notarize
xcrun notarytool submit claude-notes-bridge.zip \
      --apple-id "you@email.com" \
      --team-id "TEAMID" \
      --password "@keychain:AC_PASSWORD"

# Staple
xcrun stapler staple claude-notes-bridge
```

### Checking FDA Status

```swift
import Foundation

func hasFullDiskAccess() -> Bool {
    let dbPath = NSHomeDirectory() +
        "/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"
    return FileManager.default.isReadableFile(atPath: dbPath)
}

func requestFullDiskAccess() {
    // Open System Settings to FDA panel
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    NSWorkspace.shared.open(url)
}
```

---

## MCP Tools Specification

### Read Operations

| Tool | Parameters | Returns |
|------|------------|---------|
| `list_notes` | `folder?`, `limit?` | Note summaries |
| `read_note` | `id` | Full note content + metadata |
| `search_notes` | `query`, `limit?` | Matching notes |
| `list_folders` | — | Folder hierarchy |
| `get_attachments` | `note_id` | Attachment metadata + content |

### Write Operations

| Tool | Parameters | Returns |
|------|------------|---------|
| `create_note` | `title`, `body`, `folder?` | New note ID |
| `update_note` | `id`, `title?`, `body?` | Updated note |
| `delete_note` | `id` | Success/failure |
| `move_note` | `id`, `folder_id` | Success/failure |
| `create_folder` | `name`, `parent?` | New folder ID |

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| iCloud sync conflict | Medium | High | Preserve CloudKit metadata, update timestamps correctly |
| Format change in future macOS | Low | High | Version detection, schema validation on startup |
| Database corruption | Low | Critical | Backup before writes, use transactions |
| Notes.app locks DB | Medium | Medium | Check for running Notes.app, retry logic |

---

## Development Phases

### Phase 1: Read-Only MVP
- [ ] Go project setup with protobuf
- [ ] SQLite read access
- [ ] Protobuf decode (note content)
- [ ] MCP server with list/read/search
- [ ] FDA permission handling

### Phase 2: Write Support
- [ ] Protobuf encode (create notes)
- [ ] Study CloudKit metadata preservation
- [ ] Implement create_note (local folder first)
- [ ] Test with iCloud-synced folder

### Phase 3: Full CRUD
- [ ] update_note with sync safety
- [ ] delete_note
- [ ] Folder operations
- [ ] Attachment handling

### Phase 4: Production
- [ ] Code signing & notarization
- [ ] Error handling & logging
- [ ] Performance optimization
- [ ] Documentation

---

## Resources

### Protobuf & Database
- [notestore.proto](https://github.com/threeplanetssoftware/apple_cloud_notes_parser/blob/master/proto/notestore.proto) — THE schema file
- [Ciofeca Forensics: Protobuf](https://ciofecaforensics.com/2020/09/18/apple-notes-revisited-protobuf/) — Format deep dive
- [Ciofeca Forensics: CloudKit](https://www.ciofecaforensics.com/2020/10/20/apple-notes-cloudkit-data/) — Sync internals

### Swift Libraries
- [apple/swift-protobuf](https://github.com/apple/swift-protobuf) — Official Apple protobuf
- [SQLite3 (system)](https://developer.apple.com/documentation/sqlite) — Built into macOS
- [Compression (system)](https://developer.apple.com/documentation/compression) — For gzip

### macOS Development
- [Apple: Full Disk Access Rules](https://developer.apple.com/forums/thread/107546)
- [Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Swift Package Manager](https://www.swift.org/package-manager/)

### Reference Implementations
- [apple_cloud_notes_parser](https://github.com/threeplanetssoftware/apple_cloud_notes_parser) — Ruby, forensic-grade
- [apple-notes-liberator](https://github.com/HamburgChimps/apple-notes-liberator) — Java, JSON export
