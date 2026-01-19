# Progress Log: Goal 4 - M3 Create Notes

## Session: 2026-01-18

### Phase 1: Research Database Write Requirements
- **Status:** complete
- **Started:** 2026-01-18
- Actions taken:
  - Studied ZICCLOUDSYNCINGOBJECT schema (213 columns)
  - Identified required fields for notes (Z_ENT=12)
  - Studied ZICNOTEDATA structure
  - Analyzed protobuf format from actual note data
  - Documented Z_PK generation via Z_PRIMARYKEY table
  - Confirmed only iCloud account exists (no "On My Mac")
  - Documented iCloud sync considerations
- Files created/modified:
  - task_plan.md (created)
  - findings.md (updated with full research)
  - progress.md (created)

### Phase 2: Implement Protobuf Encoder
- **Status:** complete
- **Started:** 2026-01-18
- Actions taken:
  - Created Encoder.swift with NoteEncoder class
  - Implemented protobuf encoding for NoteStoreProto/Document/Note structure
  - Implemented gzip compression with proper header/trailer
  - Added --test-encoder flag for roundtrip testing
  - All 4 test cases pass
- Files created/modified:
  - Sources/claude-notes-bridge/Notes/Encoder.swift (created)
  - Sources/claude-notes-bridge/main.swift (added test mode)

### Phase 3: Implement Database Writer
- **Status:** complete
- **Started:** 2026-01-18
- Actions taken:
  - Added read-write database opening (ensureOpenReadWrite)
  - Implemented Z_PK allocation from Z_PRIMARYKEY table
  - Implemented createNote with proper transactions
  - Added listFolders helper function
  - Added --test-create and --list-folders CLI flags
  - Test note created successfully (ID: D6BBC99C-6D98-40C5-A547-DDEEE817D4B0)
- Files modified:
  - Sources/claude-notes-bridge/Notes/Database.swift (added write operations)
  - Sources/claude-notes-bridge/Notes/Models.swift (added folderNotFound error)
  - Sources/claude-notes-bridge/main.swift (added test commands)

### Phase 4: Add create_note Tool
- **Status:** complete
- **Started:** 2026-01-18
- Actions taken:
  - Added create_note tool definition to MCP tools/list
  - Added list_folders tool definition
  - Implemented create_note and list_folders handlers
  - Tested via MCP protocol - both tools work
  - Created test note via MCP (ID: C92CD61F-B4A6-4EFA-BA2E-D846935AE84D)
- Files modified:
  - Sources/claude-notes-bridge/MCP/Server.swift (added tools)

### Phase 5: Test & Verify
- **Status:** in_progress
- **Started:** 2026-01-18
- Actions taken:
  - Verified notes created in database (Z_PK exists, data correct)
  - Notes NOT visible in Notes.app (225 visible, 3 DB-created invisible)
  - Root cause: Missing ZSERVERRECORDDATA (CloudKit metadata)
  - Attempted to generate CKRecord metadata manually - FAILED
  - CKRecordID generation works but full record has cryptographic validation
  - Tried patching KnownToServer flag - no effect
  - Tried adding parent reference to folder's CKRecordID - no effect
- **Conclusion:** Direct DB writes cannot make notes visible in iCloud-synced Notes.app
- **Pivot decision needed:** Switch to AppleScript for write operations

### Phase 6: Implement AppleScript Write Path
- **Status:** in_progress
- **Started:** 2026-01-18
- Actions taken:
  - User suggested inspecting macnotesapp (RhetTbull/macnotesapp)
  - Cloned and analyzed the library's source code
  - **CRITICAL DISCOVERY:** AppleScript supports FULL CRUD!
    - Goal-1 research was WRONG about update/delete limitations
    - `set body of note id (noteID) to newBody` works for updates
    - `delete note` works for deletion
  - Tested and verified:
    - Created note via AppleScript → visible immediately ✅
    - Updated note body via AppleScript → works ✅
    - Deleted note via AppleScript → works ✅
- **Next steps:**
  - Implement AppleScript wrapper in Swift
  - Replace create_note tool to use AppleScript
  - Add update_note and delete_note tools

### Performance Investigation & Architecture Decision
- **Status:** complete
- **Date:** 2026-01-18
- Actions taken:
  - Benchmarked AppleScript vs Database performance
    - DB reads: ~5ms, AppleScript: ~300-600ms (75-400x slower)
  - Tested alternative scripting methods (ScriptingBridge, NSAppleScript, JXA)
    - All have same ~300ms overhead (IPC bottleneck)
  - Tested batching: 32% improvement (133ms vs 195ms per note)
  - Experimented with hybrid approaches:
    - DB create → AppleScript adopt: FAILED (invisible notes)
    - Copy ZSERVERRECORDDATA: FAILED (UUID mismatch)
    - AppleScript create → DB update: UNRELIABLE (cache issues)
  - Cleaned up test notes from experiments
  - Documented findings and architecture decisions
- **Decision:** Pure hybrid - DB for reads, AppleScript for writes

### Phase 6 Implementation Complete
- **Status:** complete
- **Date:** 2026-01-18
- Actions taken:
  - Created `AppleScript.swift` - helper module for Notes.app operations
  - Implemented `createNote()` - creates via AppleScript, returns x-coredata ID
  - Implemented `updateNote()` - preserves title when updating body only
  - Implemented `deleteNote()` - moves to Recently Deleted
  - Added `update_note` MCP tool
  - Added `delete_note` MCP tool
  - Modified `create_note` to use AppleScript instead of direct DB writes
  - All operations tested and working

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 6 complete - AppleScript write operations implemented |
| Where am I going? | Phase 7 - Archive goal |
| What's the goal? | Enable reliable CRUD with optimal performance |
| What have I learned? | AppleScript handles CloudKit automatically; update needs to preserve title |
| What have I done? | Implemented full CRUD: DB reads + AppleScript writes |
