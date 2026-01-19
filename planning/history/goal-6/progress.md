# Goal 6: Progress Log

## Session: 2026-01-19

### Phase 1: Research Attachment Storage
- **Status:** complete
- **Started:** 2026-01-19
- Discovered database schema (Z_ENT=5 for attachments, Z_ENT=11 for media)
- Found file storage location in `~/Library/Group Containers/group.com.apple.notes/Accounts/.../Media/`
- Tested AppleScript read capabilities - `contents` property returns HFS file path
- Tested AppleScript write capabilities - `make new attachment with data (POSIX file)` works!
- Documented all findings

### Phase 2: Implement Read Attachments
- **Status:** complete
- Added `Attachment` model to Models.swift
- Added `fetchAttachments(forNotePK:)` and `getAttachment(id:)` to Database.swift
- Updated `read_note` to include attachments in response
- Added `get_attachment` MCP tool
- Fixed AppleScript quirk: must get `contents` from properties record

### Phase 3: Implement Create with Attachments
- **Status:** complete
- Added `addAttachment(noteId:filePath:)` to AppleScript.swift
- Added `add_attachment` MCP tool
- Tested with text files and images

### Phase 4: Test & Verify
- **Status:** in_progress
- All tools tested via MCP JSON-RPC:
  - `read_note` shows attachments ✅
  - `get_attachment` returns file path ✅
  - `add_attachment` adds files to notes ✅
- Pending: iCloud sync verification

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 - testing |
| Where am I going? | Archive goal after sync verification |
| What's the goal? | Enable attachments in notes |
| What have I learned? | DB for metadata, AppleScript for file paths and creation |
| What have I done? | Implemented read/add attachment tools |
