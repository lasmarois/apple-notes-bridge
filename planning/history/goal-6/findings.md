# Goal 6: Findings

## Attachment Research (2026-01-19)

### Database Schema

Attachments use the same table (`ZICCLOUDSYNCINGOBJECT`) with different entity types:

| Z_ENT | Type | Count | Description |
|-------|------|-------|-------------|
| 5 | ICAttachment | 1016 | Attachment records |
| 6 | ICAttachmentPreviewImage | 2258 | Preview thumbnails |
| 9 | ICInlineAttachment | 127 | Inline attachments |
| 11 | ICMedia | 914 | Media file records |
| 12 | ICNote | 1858 | Notes |

**Key columns for attachments (Z_ENT=5):**
- `ZIDENTIFIER` - UUID of the attachment
- `ZTYPEUTI` - File type (e.g., `public.jpeg`, `com.apple.notes.table`)
- `ZFILESIZE` - Size in bytes
- `ZTITLE` - Display name
- `ZNOTE` - Foreign key to note (Z_PK)
- `ZMEDIA` - Foreign key to media record

**Common UTI types:**
- `public.jpeg` - JPEG images
- `public.png` - PNG images
- `com.adobe.pdf` - PDF documents
- `com.apple.notes.table` - Tables
- `com.apple.paper.doc.scan` - Scanned documents

### File Storage Locations

**Primary location (original files):**
```
~/Library/Group Containers/group.com.apple.notes/Accounts/<AccountID>/Media/<MediaID>/<hash>/filename
```

**Cache/CloudKit location (synced files):**
```
~/Library/Containers/com.apple.Notes/Data/Library/Caches/CloudKit/<hash>/Assets/
```

**Path structure:**
- `AccountID` - Account UUID (e.g., `91FF283D-E275-466C-A930-7AB24CAEE2D6`)
- `MediaID` - From `ZMEDIA` foreign key → `ZIDENTIFIER` of ICMedia record
- `hash` - Internal hash (e.g., `1_2136C5A2-4346-447C-8227-791728D146B5`)
- `filename` - Original filename (e.g., `IMG_0473.jpg`)

### AppleScript Capabilities

#### Reading Attachments ✅

```applescript
tell application "Notes"
    set theNote to note "Note Name"
    set att to attachment 1 of theNote

    -- Available properties:
    get name of att           -- "IMG_0473.jpg"
    get id of att             -- "x-coredata://...ICAttachment/p538"
    get content identifier of att  -- "cid:UUID@icloud.apple.com"
    get contents of att       -- HFS file path
    get creation date of att
    get modification date of att
    get container of att      -- Parent note
end tell
```

**Key property:** `contents` returns the HFS file path:
```
file Macintosh HD:Users:nicolas:Library:Group Containers:group.com.apple.notes:Accounts:...:Media:...:filename
```

#### Creating Attachments ✅

**Working syntax:**
```applescript
tell application "Notes"
    set newNote to make new note with properties {name:"Title", body:"Content"}
    make new attachment at end of attachments of newNote with data (POSIX file "/path/to/file")
end tell
```

**Critical:** Must use `POSIX file` specifier, not plain string path.

**Tested file types:**
- Text files (.txt) ✅
- Images (.png, .jpg) ✅

### Implementation Strategy

| Operation | Method | Notes |
|-----------|--------|-------|
| List attachments | Database | Fast, includes metadata |
| Get attachment metadata | Database | UTI, size, dates |
| Get attachment file path | AppleScript | `contents` property returns HFS path |
| Get attachment content | Read file | Convert HFS→POSIX, read bytes |
| Create with attachment | AppleScript | `make new attachment with data (POSIX file)` |
| Add attachment to note | AppleScript | Same as above |

### Open Questions - ANSWERED

1. **Where are attachment files stored on disk?**
   → `~/Library/Group Containers/group.com.apple.notes/Accounts/<ID>/Media/<ID>/<hash>/filename`

2. **Can AppleScript add attachments to notes?**
   → **YES** - `make new attachment at end of attachments of note with data (POSIX file "/path")`

3. **How are attachments referenced in the protobuf?**
   → Not needed - use AppleScript `contents` property for file path

4. **What attachment types does Notes support?**
   → Images (jpeg, png, heic), PDFs, scanned docs, tables, files
