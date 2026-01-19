# Goal 6: M6 - Attachments

## Objective
Enable reading and creating notes with attachments (images, PDFs, files) via MCP tools.

## Current Phase
Phase 5 (Archive)

## Phases

### Phase 1: Research Attachment Storage
- [x] Investigate how attachments are stored in NoteStore.sqlite
- [x] Find attachment tables and schema
- [x] Understand attachment file locations on disk
- [x] Test reading attachment metadata via SQL
- [x] Research AppleScript attachment capabilities
- **Status:** complete

### Phase 2: Implement Read Attachments
- [x] Add attachment metadata to `read_note` response
- [x] Include attachments in note metadata (name, type, size, ID)
- [x] Create `get_attachment` tool to get file path
- [x] Handle different attachment types (images, PDFs, files)
- **Status:** complete

### Phase 3: Implement Create with Attachments
- [x] Research AppleScript for adding attachments
- [x] Add `add_attachment` tool for existing notes
- [x] Test with text and image files
- **Status:** complete

### Phase 4: Test & Verify
- [x] Test reading attachments from existing notes
- [x] Test adding attachments to notes
- [x] Test various file types (text, images)
- [x] Verify iCloud sync works correctly
- **Status:** complete

### Phase 5: Archive Goal
- [ ] Update ROADMAP.md
- [ ] Move files to planning/history/goal-6/
- [ ] Commit
- **Status:** pending

## Open Questions
1. Where are attachment files stored on disk?
2. Can AppleScript add attachments to notes?
3. How are attachments referenced in the protobuf?
4. What attachment types does Notes support?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| | |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
