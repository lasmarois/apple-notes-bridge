# Task Plan: M3 Create Notes

## Goal
Enable Claude to create new notes in Apple Notes via direct database writes.

## Current Phase
Phase 6 (AppleScript Write Path)

## Phases

### Phase 1: Research Database Write Requirements
- [x] Study existing note structure in DB (all required fields)
- [x] Understand ZICCLOUDSYNCINGOBJECT fields for new notes
- [x] Understand ZICNOTEDATA fields and protobuf encoding
- [x] Identify required UUIDs and relationships
- **Status:** complete

### Phase 2: Implement Protobuf Encoder
- [x] Create encoder for NoteStoreProto.Document.Note
- [x] Generate valid gzipped protobuf blob
- [x] Test encode/decode roundtrip
- **Status:** complete

### Phase 3: Implement Database Writer
- [x] Open database in read-write mode
- [x] Insert into ZICCLOUDSYNCINGOBJECT (metadata)
- [x] Insert into ZICNOTEDATA (content)
- [x] Handle transactions properly
- **Status:** complete

### Phase 4: Add create_note Tool
- [x] Add tool definition to MCP server
- [x] Implement create_note handler
- [x] Test via MCP protocol
- **Status:** complete

### Phase 5: Test & Verify (PIVOTED)
- [x] Create note via MCP
- [x] Verify note appears in Notes.app → **FAILED** (notes invisible)
- [x] Root cause: CloudKit metadata (ZSERVERRECORDDATA) cannot be forged
- **Status:** complete (with blocker - pivoting approach)

### Phase 6: Implement AppleScript Write Path
- [x] Research AppleScript Notes.app API → **DONE** (macnotesapp inspection)
- [x] **DISCOVERY:** AppleScript supports full CRUD (create, update, delete)!
- [x] Implement AppleScript.swift helper module
- [x] Replace direct DB writes with AppleScript calls
- [x] Test create_note tool creates visible notes
- [x] Add update_note tool (AppleScript)
- [x] Add delete_note tool (AppleScript)
- **Status:** complete

### Phase 7: Archive Goal
- [ ] Update ROADMAP.md
- [ ] Move files to planning/history/goal-4/
- [ ] Commit
- **Status:** pending

## Key Questions (Answered)
1. **Minimum fields for ZICCLOUDSYNCINGOBJECT?** → Z_PK, Z_ENT=12, Z_OPT=1, ZACCOUNT7, ZFOLDER, ZNOTEDATA, ZIDENTIFIER (UUID), ZTITLE1, ZSNIPPET, ZCREATIONDATE3, ZMODIFICATIONDATE1
2. **How are Z_PK values generated?** → Read Z_MAX from Z_PRIMARYKEY (entity 3 for notes), increment, use for insert, update Z_MAX
3. **Other tables to update?** → Z_PRIMARYKEY (Z_MAX), ZICNOTEDATA (content)
4. **Will Notes.app pick up new notes?** → TBD (need to test)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Direct DB writes for iCloud accounts | Notes created but invisible until CloudKit syncs |
| Need ZSERVERRECORDDATA for visibility | NSKeyedArchiver-encoded CKRecordID - complex to generate |
| PIVOT: Use AppleScript for writes | CloudKit metadata cannot be forged; AppleScript is reliable |
| Hybrid approach: DB reads + AppleScript writes | Best of both worlds: fast reads, reliable creates |
| DB→AppleScript adopt: REJECTED | AppleScript cannot see DB-created notes |
| Copy ZSERVERRECORDDATA: REJECTED | CloudKit metadata contains internal UUID, can't be reused |
| AppleScript create→DB update: REJECTED | Notes.app caches content, unreliable sync |
| Use osascript (not ScriptingBridge) | Same performance (~300ms), simpler implementation |
| Batch AppleScript operations | 32% faster for bulk creates (133ms vs 195ms per note) |

## Final Architecture
| MCP Tool | Method | Expected Latency |
|----------|--------|------------------|
| `list_notes` | Database | ~5ms |
| `read_note` | Database | ~5ms |
| `search_notes` | Database | ~10ms |
| `list_folders` | Database | ~5ms |
| `create_note` | AppleScript | ~300ms |
| `update_note` | AppleScript | ~600ms |
| `delete_note` | AppleScript | ~300ms |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| | | |

## Notes
- Start with "On My Mac" folder (no iCloud sync complexity)
- Keep note content simple (plain text first)
- Watch for database locking issues
