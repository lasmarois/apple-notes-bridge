# Findings: M3 Create Notes

## Requirements
- Create new notes via database writes
- Notes must appear in Notes.app
- ~~Start with "On My Mac" folder (no iCloud)~~ → Only iCloud account exists

## Database Research

### Entity Types (Z_PRIMARYKEY)
| Z_ENT | Z_NAME | Z_SUPER | Notes |
|-------|--------|---------|-------|
| 3 | ICCloudSyncingObject | 0 | Parent entity, shared Z_PK sequence (MAX: 6405) |
| 12 | ICNote | 3 | Notes inherit from ICCloudSyncingObject |
| 14 | ICAccount | 3 | Account records |
| 15 | ICFolder | 3 | Folder records |
| 19 | ICNoteData | 0 | Separate table with own Z_PK sequence (MAX: 1843) |

### ZICCLOUDSYNCINGOBJECT Fields (for notes, Z_ENT=12)

**Required fields:**
| Field | Type | Description |
|-------|------|-------------|
| Z_PK | INTEGER | Primary key (from ICCloudSyncingObject sequence) |
| Z_ENT | INTEGER | Entity type = 12 (ICNote) |
| Z_OPT | INTEGER | Optimistic locking counter = 1 |
| ZACCOUNT7 | INTEGER | FK to account Z_PK (3 = iCloud) |
| ZFOLDER | INTEGER | FK to folder Z_PK |
| ZNOTEDATA | INTEGER | FK to ZICNOTEDATA.Z_PK |
| ZIDENTIFIER | VARCHAR | UUID (e.g., "F2735AFA-6BD5-4EBF-931C-5A55FD766DBD") |
| ZTITLE1 | VARCHAR | Note title (extracted from content) |
| ZSNIPPET | VARCHAR | Preview snippet (first line after title) |
| ZCREATIONDATE3 | TIMESTAMP | Core Data timestamp (seconds since 2001-01-01) |
| ZMODIFICATIONDATE1 | TIMESTAMP | Core Data timestamp |

**Optional/default fields:**
| Field | Default | Notes |
|-------|---------|-------|
| ZHASCHECKLIST | 0 | Has checklist items |
| ZHASCHECKLISTINPROGRESS | 0 | Has incomplete checklist |
| ZHASEMPHASIS | 0 | Has emphasized text |
| ZHASSYSTEMTEXTATTACHMENTS | 0 | Has system attachments |
| ZISPINNED | 0 | Pinned note |
| ZISSYSTEMPAPER | 0 | System paper type |
| ZPAPERSTYLETYPE | 0-1 | Paper style |
| ZATTRIBUTEDTITLE | NULL | Rich text title (optional) |
| ZATTRIBUTEDSNIPPET | NULL | Rich text snippet (optional) |

### ZICNOTEDATA Fields

| Field | Type | Description |
|-------|------|-------------|
| Z_PK | INTEGER | Primary key (from ICNoteData sequence) |
| Z_ENT | INTEGER | Entity type = 19 (ICNoteData) |
| Z_OPT | INTEGER | Optimistic locking counter = 1 |
| ZNOTE | INTEGER | FK to ZICCLOUDSYNCINGOBJECT.Z_PK |
| ZDATA | BLOB | Gzip-compressed protobuf content |
| ZCRYPTOINITIALIZATIONVECTOR | BLOB | NULL (for unencrypted notes) |
| ZCRYPTOTAG | BLOB | NULL (for unencrypted notes) |

### Protobuf Encoding

**Structure (from raw analysis + notestore.proto):**
```
NoteStoreProto {
  field_1: 0 (varint)                    // Unknown purpose
  document: Document (field 2) {
    field_1: 0 (varint)                  // Unknown purpose
    version: 0 (field 2, varint)         // Document version
    note: Note (field 3) {
      note_text: string (field 2)        // Full note text with \n
      attribute_run: [...] (field 5)     // Repeated formatting
    }
  }
}
```

**AttributeRun structure:**
```protobuf
message AttributeRun {
  required int32 length = 1;             // Character count
  optional ParagraphStyle paragraph_style = 2;
  optional Font font = 3;
  optional int32 font_weight = 5;
  // ... more optional fields
}
```

**Encoding process:**
1. Build Note message with note_text + attribute_run
2. Wrap in Document with version
3. Wrap in NoteStoreProto
4. Serialize to protobuf binary
5. Gzip compress
6. Store in ZDATA

### Z_PK Generation

1. Read Z_MAX from Z_PRIMARYKEY for entity type
2. Increment Z_MAX
3. Use new value as Z_PK for INSERT
4. Update Z_MAX in Z_PRIMARYKEY

**For notes:** Use ICCloudSyncingObject (Z_ENT=3) sequence
**For note data:** Use ICNoteData (Z_ENT=19) sequence

### iCloud Sync Considerations

Only iCloud account exists (Z_PK=3). All notes will sync.

**CRITICAL FINDING:** Notes.app only displays notes that have ZSERVERRECORDDATA (CloudKit metadata). Direct database inserts create notes WITHOUT this metadata, so they're invisible to Notes.app until synced.

| Notes with CloudKit data | Notes without | Visible in app |
|--------------------------|---------------|----------------|
| 225 | 3 (our created) | Only 225 |

**Fields that may affect sync:**
- ZSERVERRECORDDATA - CloudKit record metadata (REQUIRED for visibility)
- ZMODIFICATIONDATE1 - Triggers sync detection
- ZICCLOUDSTATE entries - Created automatically by Notes.app

**Workaround Options:**
1. **"On My Mac" account** - Enable local account in Notes preferences for non-iCloud notes
2. **AppleScript approach** - Use `osascript` to create notes via Notes.app API (slower but reliable)
3. **Hybrid approach** - Database for reads, AppleScript for writes

**Current status:** Database writes work correctly but notes invisible until CloudKit synced

### ZSERVERRECORDDATA Investigation (Session 2026-01-18 continued)

**Goal:** Generate valid `ZSERVERRECORDDATA` to make DB-created notes visible in Notes.app without CloudKit sync.

**Findings:**
- `ZSERVERRECORDDATA` is an NSKeyedArchiver-encoded plist containing CKRecord metadata
- Structure includes: CKRecordID (UUID + zone), recordType, modificationDate, parent reference, system fields
- Contains `KnownToServer` flag (bool) that indicates whether CloudKit knows about the record
- Generated CKRecordID can be created in Swift via CloudKit framework

**Attempts:**
1. Generated minimal CKServerRecord with CKRecordID - inserted but note still invisible
2. Tried patching `KnownToServer` to `true` in plist - still invisible
3. Generated more complete CKRecord with parent reference (folder's CKRecordID) - still invisible

**Conclusion:**
Generating valid `ZSERVERRECORDDATA` is complex and doesn't work reliably. The CloudKit metadata has cryptographic signatures or other validation that can't be forged.

**Recommended approach:**
1. **AppleScript for writes** - Use `osascript` to create notes via Notes.app scripting API
2. **Database for reads** - Continue using SQLite for efficient read operations
3. **Hybrid MCP server** - Route creates through AppleScript, reads through SQLite

## CRITICAL DISCOVERY: AppleScript Supports Full CRUD (2026-01-18)

**Source:** Inspected [macnotesapp](https://github.com/RhetTbull/macnotesapp) library

### Goal-1 Research Was WRONG

The original research claimed AppleScript could only read and create notes. **This is incorrect.**

**Verified capabilities:**
| Operation | Works? | AppleScript |
|-----------|--------|-------------|
| Create | ✅ | `make new note with properties {name:..., body:...}` |
| Read | ✅ | `plaintext of note`, `body of note` |
| **Update** | ✅ | `set body of note id (noteID) to newBody` |
| **Delete** | ✅ | `delete note` |

**Tested and confirmed:**
```applescript
-- UPDATE works:
tell application "Notes"
    set testNote to first note whose name is "Test"
    set body of testNote to "<div>New content</div>"
end tell

-- DELETE works:
tell application "Notes"
    delete first note whose name is "Test"
end tell
```

### Implications

1. **No need for direct DB writes** - AppleScript handles CloudKit metadata automatically
2. **Hybrid approach is optimal:**
   - AppleScript for ALL writes (create, update, delete)
   - Database for reads (faster for bulk operations, richer metadata)
3. **Simpler implementation** - No protobuf encoding needed for writes

### Known AppleScript Limitations
- Cannot access password-protected/locked notes
- Cannot access nested folder contents (Catalina bug, may be fixed)
- Attachment handling is limited
- Slower than direct DB access (~300ms per operation)

## Performance Benchmarks (2026-01-18)

### Raw Measurements

| Operation | Database | AppleScript | Ratio |
|-----------|----------|-------------|-------|
| Read 1 note | **5ms** | 373ms | 75x faster |
| List 100 notes | **5ms** | ~2000ms | 400x faster |
| Search | **7ms** | N/A | - |
| Create | N/A | 310ms | - |
| Update | N/A | 583ms | - |
| Delete | N/A | 271ms | - |

### Scripting Method Comparison

All scripting methods have same ~300ms overhead (IPC bottleneck with Notes.app):
- `osascript` (AppleScript): ~300-600ms
- ScriptingBridge (Swift): ~313ms
- NSAppleScript (Swift): ~359ms
- JXA: Buggy, doesn't work reliably with Notes.app

### Batching Improvement

| Method | Time | Per-note |
|--------|------|----------|
| 3 separate AppleScript calls | 587ms | 195ms |
| 3 notes in 1 AppleScript call | 399ms | 133ms |

**Batching gives ~32% improvement.**

## Hybrid Architecture Experiments (2026-01-18)

### Approach 1: DB Create → AppleScript Adopt ❌
**Hypothesis:** Create note via DB, then use AppleScript to "adopt" it.
**Result:** Failed. AppleScript cannot see DB-created notes (missing CloudKit metadata).

### Approach 2: Copy ZSERVERRECORDDATA Between Notes ❌
**Hypothesis:** Copy CloudKit metadata from AppleScript note to DB note.
**Result:** Failed. CloudKit metadata contains internal UUID that must match the note's ZIDENTIFIER.

### Approach 3: AppleScript Create → DB Update ⚠️
**Hypothesis:** Create via AppleScript, then update content via DB for speed.
**Result:** Partially works but unreliable:
- Notes.app caches content in memory
- Changes not visible until Notes.app restart
- Risk of corruption if protobuf encoding is imperfect
- CloudKit sync could overwrite DB changes

### Conclusion: Pure Hybrid (DB Reads + AppleScript Writes)

The only reliable approach is:
- **Reads:** Database (fast, ~5ms)
- **Writes:** AppleScript (slower but reliable, ~300-600ms)

The ~300-600ms write latency is the cost of reliability. Acceptable for MCP server where most operations are reads.

## Resources
- Goal-1 deliverable: planning/history/goal-1/DELIVERABLE-INTEGRATION-OPTIONS-GOAL-1.md
- Goal-3 findings: planning/history/goal-3/findings.md
- Protobuf schema: https://github.com/threeplanetssoftware/apple_cloud_notes_parser/blob/master/proto/notestore.proto
