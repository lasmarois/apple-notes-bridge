# Findings & Decisions: Apple Notes Integration Research

## Requirements
- Read notes (content, metadata, folder structure)
- Write/update notes
- Organize notes (folders, move, delete)
- Enable LLM (Claude) to interact with Notes
- macOS focus (iOS future scope)

## Research Findings

### AppleScript/JXA
- Notes.app has AppleScript scripting dictionary enabling query/control
- JXA (JavaScript for Automation) is the main alternative to AppleScript
- Basic pattern: `Application('Notes')` → `notes()` → `note.name()`, `note.body()`
- **Capabilities**: Read notes, create notes, access folders
- **Limitations**:
  - Cannot update/modify existing notes (read + create only)
  - Cannot delete notes
  - Encrypted notes NOT supported (API limitation)
  - JXA documentation is poor, described as "a mess"
  - No native HTTP support (requires Obj-C bridge)

### Native APIs
- **No official Apple Notes API exists** as of 2025
- Apple keeps adding features but keeps Notes walled off
- Other privacy-sensitive subsystems (Contacts, Photos) have APIs, but not Notes
- Apple encourages filing enhancement requests via bugreport.apple.com
- SiriKit has Lists and Notes intents but limited to Siri context
- Web Share API can share text to Notes via native Share sheet (Electron apps)
- Shortcuts app can find/read notes but limited automation

### Database Access (DEEPER ANALYSIS)

**Location**: `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`

**Protobuf Schema is DOCUMENTED:**
- Full `.proto` file available: [notestore.proto](https://github.com/threeplanetssoftware/apple_cloud_notes_parser/blob/master/proto/notestore.proto)
- Schema reverse-engineered by forensics researchers (Ciofeca Forensics, threeplanetssoftware)
- Format stable since iOS 9 (2015) with incremental additions

**Key Data Structures:**
```protobuf
NoteStoreProto {
  Document document = 2 {
    int32 version = 2
    Note note = 3 {
      string note_text = 2        // The actual text
      repeated AttributeRun = 5   // Formatting (bold, lists, etc.)
    }
  }
}
```

**AttributeRun fields:** length, paragraph_style, font, font_weight, underlined, strikethrough, link, color, attachment_info

**Reading is SAFE and FEASIBLE:**
- gzip decompress → protobuf decode → plaintext
- Tools exist: apple_cloud_notes_parser (Ruby), apple-notes-liberator (Java)
- Schema documented enough to build Python implementation

**Writing is RISKY but POSSIBLE:**
- Need to construct valid protobuf → gzip → insert
- Risk: iCloud sync conflicts if notes sync enabled
- Risk: WAL/SHM files must stay in sync
- Risk: Related tables (ZICCLOUDSYNCINGOBJECT) need consistent state
- **Mitigation**: Only write to "On My Mac" notes (local-only, no iCloud)

**Version Alignment:**
- Can detect macOS version via `sw_vers`
- Schema has been stable - additions are additive, not breaking
- Parser projects support iOS 9-26 (wide range)
- Key tables (ZICNOTEDATA, ZICCLOUDSYNCINGOBJECT) structure consistent

**Permissions:**
- Requires **Full Disk Access** (System Settings → Privacy)
- Or copy database file to accessible location for read-only

### Third-Party Tools
- **apple-notes-liberator** (HamburgChimps): Extracts notes to JSON/Markdown
  - Uses JBang for easy installation
  - Outputs: notes.json, markdown files, sqlite copy
  - Based on threeplanetssoftware's protobuf research
- **apple_cloud_notes_parser** (threeplanetssoftware): Forensic-grade parser
  - Handles iCloud-synced notes
  - Decodes protobuf format
- **apple-notes-to-sqlite** (dogsheep): Export to SQLite with notes/folders tables
- **notes-exporter** (KrauseFx): GDPR-motivated export tool

### MCP Servers
Three existing MCP servers for Claude integration:

1. **mcp-apple-notes** (RafalWilinski) - BEST OPTION
   - Semantic search + RAG over notes
   - Uses all-MiniLM-L6-v2 embeddings (local, no API keys)
   - LanceDB for vector storage
   - Uses JXA for native access
   - Requires Bun runtime
   - **Limitation**: Read-only, no note creation yet

2. **apple-notes-mcp** (sirmews) - ARCHIVED (Aug 2025)
   - Read-only: get-all-notes, read-note, search-notes
   - Requires Full Disk Access
   - **Status**: Archived, no longer maintained

3. **apple-mcp** (karlhepler)
   - Claims full CRUD + folder management
   - TypeScript + AppleScript
   - Includes Reminders support
   - Could not verify (404 on fetch)

### iCloud Access
- **pyicloud** (picklepete): Python wrapper for iCloud web services
  - Can access `files['com~apple~Notes']['Documents']`
  - **Major limitation**: 2FA required - blocks most API access
  - Only FindMe works without 2FA code entry
- Legacy IMAP method (`imap.mail.me.com`) no longer works since El Capitan
- Notes no longer stored on IMAP server
- iCloud web interface requires authenticated session

### URL Schemes & Deep Linking
- **macOS**: `notes://showNote?identifier=<UUID>`
- **iOS**: `mobilenotes://showNote?identifier=<UUID>`
- **applenotes**: `applenotes:note/<UUID>` (hidden internal scheme)
- Core Data URLs: `x-coredata://<UUID>/ICNote/p<ID>`
- **Native note linking**: iOS 17+ / macOS 14+ Sonoma has built-in note-to-note links
- Third-party schemes: Hookmark uses `hook://notes/`
- **Limitation**: URL schemes for opening notes, not for CRUD operations

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| DB-only approach | Consistency - single source of truth, no AppleScript limitations |
| **Swift** | Zero runtime deps (built into macOS), system SQLite, native ecosystem |
| Native macOS app patterns | Proper permission requests (Full Disk Access), clean ecosystem integration |
| iCloud-compatible writes | Preserve CloudKit metadata, update timestamps correctly |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| | |

## Resources

### MCP Servers
- https://github.com/RafalWilinski/mcp-apple-notes (RAG + semantic search)
- https://github.com/sirmews/apple-notes-mcp (archived)
- https://github.com/karlhepler/apple-mcp (CRUD claims)

### Database/Export Tools
- https://github.com/HamburgChimps/apple-notes-liberator
- https://github.com/threeplanetssoftware/apple_cloud_notes_parser
- https://github.com/dogsheep/apple-notes-to-sqlite

### Documentation
- http://www.macosxautomation.com/applescript/notes/index.html (AppleScript Notes guide)
- https://gist.github.com/JMichaelTX/d29adaa18088572ce6d4 (JXA resources)
- http://www.swiftforensics.com/2018/02/reading-notes-database-on-macos.html (DB forensics)

### Protobuf Schema & Forensics
- https://github.com/threeplanetssoftware/apple_cloud_notes_parser/blob/master/proto/notestore.proto (THE PROTO FILE)
- https://ciofecaforensics.com/2020/09/18/apple-notes-revisited-protobuf/ (Protobuf deep dive)
- https://ciofecaforensics.com/2020/01/10/apple-notes-revisited/ (Note parsing)
- https://ciofecaforensics.com/2020/07/31/apple-notes-revisited-encrypted-notes/ (Encrypted notes)

### Discussions
- https://developer.apple.com/forums/thread/18917 (No API confirmation)
- https://news.ycombinator.com/item?id=35316679 (Apple Notes Liberator HN)

### iCloud
- https://github.com/picklepete/pyicloud (Python iCloud wrapper)
- https://pypi.org/project/pyicloud/

### URL Schemes
- https://developer.apple.com/forums/thread/701574 (notes:// scheme)
- https://temochka.com/blog/posts/2020/02/22/linking-to-apple-notes.html
- https://hookproductivity.com/help/integration/using-hook-with-apple-notes/

## Visual/Browser Findings
<!-- Capture immediately after viewing -->
-

---
*Update after every 2 search/browse operations*
