# Goal 7: Findings

## Rich Text Research (2026-01-19)

### How Notes Stores Content

1. **Database (protobuf)**: `ZICNOTEDATA.ZDATA` contains gzipped protobuf
   - `note_text` field contains **plain text only**
   - Formatting attributes stored separately in protobuf (not currently parsed)

2. **AppleScript `body`**: Returns HTML representation
   - Contains formatting tags: `<b>`, `<i>`, `<u>`, `<strike>`, etc.
   - Font colors: `<font color="#FF0000">`
   - Font faces: `<font face="Courier"><tt>`
   - Font sizes: `<span style="font-size: 30px">`

3. **AppleScript `plaintext`**: Returns plain text (matches our protobuf extraction)

### AppleScript HTML Body - Write Capabilities

| Feature | Input | Output | Works? |
|---------|-------|--------|--------|
| Bold | `<b>text</b>` | `<b>text</b>` | ✅ |
| Italic | `<i>text</i>` | `<i>text</i>` | ✅ |
| Underline | `<u>text</u>` | `<u>text</u>` | ✅ |
| Strikethrough | `<strike>text</strike>` | `<strike>text</strike>` | ✅ |
| H1 (title) | `<h1>text</h1>` | `<b><span style="font-size: 24px">` | ✅ |
| H2 | `<h2>text</h2>` | `<b><span style="font-size: 18px">` | ✅ |
| H3 | `<h3>text</h3>` | `<b>text</b>` | ⚠️ (just bold) |
| Text color | `<span style="color: red">` | `<font color="#FF0000">` | ✅ |
| Highlight | `<span style="background-color: yellow">` | (stripped) | ❌ |
| Monospace | `<span style="font-family: Courier">` | `<font face="Courier"><tt>` | ✅ |
| Large font | `<span style="font-size: 30px">` | `<span style="font-size: 30px">` | ✅ |
| Small font | `<span style="font-size: 10px">` | (stripped) | ❌ |
| Links | `<a href="url">text</a>` | `<u>text</u>` (URL lost) | ❌ |
| Bullet lists | `• item` | `• item` (plain text) | ✅ |
| Numbered lists | `1. item` | `1. item` (plain text) | ✅ |
| Emojis | `🎉 🚀` | `🎉 🚀` | ✅ |
| Hashtags | `#tag` | `#tag` (plain text) | ✅ |

### Current Read Capabilities (Protobuf Decoder)

Our decoder extracts `note_text` field which contains **plain text only**:

| Feature | Preserved? | Notes |
|---------|------------|-------|
| Plain text | ✅ | Fully preserved |
| Line breaks | ✅ | Preserved |
| Bullet points | ✅ | `•` character preserved |
| Numbered lists | ✅ | `1.` text preserved |
| Emojis | ✅ | Fully preserved |
| Hashtags | ✅ | Text preserved |
| Bold/Italic/etc | ❌ | Formatting lost |
| Colors | ❌ | Formatting lost |
| Fonts | ❌ | Formatting lost |
| Links | ❌ | URL lost, text preserved |
| Headings | ❌ | Extracted as plain text |

### Key Insights

1. **Writing rich text works well** via AppleScript HTML body
2. **Reading rich text loses formatting** - our protobuf decoder only extracts plain text
3. **To preserve formatting on read**, we'd need to either:
   - Parse the full protobuf structure for formatting attributes
   - Use AppleScript `body` property to get HTML (but slower)
4. **Links are not supported** - AppleScript strips href, only preserves underlined text
5. **Highlights/background colors not supported** by Notes
6. **Native checklists** require special handling (not just checkmark emoji)

### Recommendations

1. **For write operations**: Current AppleScript HTML approach works well for basic formatting
2. **For read operations**: Consider adding option to return HTML body via AppleScript for rich text preservation
3. **Document limitations**: Links cannot be created programmatically via AppleScript

---

## Hashtags & Tags Research (2026-01-19)

### How Hashtags Are Stored

1. **In protobuf**: Inline text attachments with `type_uti = "com.apple.notes.inlinetextattachment.hashtag"`
   - Text contains `\uFFFC` (object replacement character) as placeholder
   - Actual hashtag text stored in `attachment_info`

2. **In database**:
   - `ZICCLOUDSYNCINGOBJECT` with `Z_ENT = 8` (hashtag entity)
   - `ZDISPLAYTEXT` contains the tag name (without `#` prefix)
   - `ZTOKENCONTENTIDENTIFIER` links to the full token

3. **In ZSNIPPET**: Hashtags appear as plain text `#tagname` in the note's snippet

### Hashtag Capabilities

| Feature | Supported | Notes |
|---------|-----------|-------|
| List all hashtags | ✅ | Query Z_ENT=8 for ZDISPLAYTEXT |
| Search notes by hashtag | ✅ | LIKE query on ZSNIPPET |
| Read hashtags from note | ✅ | Regex extract from ZSNIPPET |
| Create hashtag | ❌ | AppleScript writes `#tag` as plain text |

### Note-to-Note Links Research

1. **In protobuf**: Inline text attachments with `type_uti = "com.apple.notes.inlinetextattachment.link"`
   - `attachment_info` contains `applenotes:note/<UUID>` URL
   - Links to other notes in the same account

2. **Via AppleScript**: **NOT SUPPORTED**
   - `<a href="...">text</a>` becomes `<u>text</u>` (href stripped)
   - Cannot create clickable links via AppleScript

### Summary

**Tags are read-only**: We can discover, list, and search by hashtags, but cannot create them programmatically. Users must manually type hashtags in Notes.app for them to be recognized as inline attachments.

**Links are read-only**: AppleScript strips all href attributes when writing. Note-to-note links can be **read** from the database but cannot be created programmatically.

---

## Embedded Objects Implementation (2026-01-19)

### Discovery
After analyzing the `apple-notes-parser` project, discovered the proper way to extract hashtags and links:

- **Column**: `ZTYPEUTI1` (not `ZTYPEUTI` or `Z_ENT=8`)
- **Text**: `ZALTTEXT` contains the display text
- **Link URL**: `ZTOKENCONTENTIDENTIFIER` contains `applenotes:note/UUID`
- **Relationships**: Check `ZNOTE`, `ZNOTE1`, and `ZATTACHMENT` columns

### UTI Constants
```
com.apple.notes.inlinetextattachment.hashtag  - Hashtags
com.apple.notes.inlinetextattachment.mention  - @mentions
com.apple.notes.inlinetextattachment.link     - Links (including note-to-note)
```

### Final Implementation

| Tool | Function | Works |
|------|----------|-------|
| `list_hashtags` | List all unique hashtags | ✅ Found 55 |
| `search_by_hashtag` | Find notes by hashtag | ✅ |
| `list_note_links` | List all note-to-note links | ✅ Found 24 |
| `read_note` | Include hashtags + links in output | ✅ |

### Limitations Confirmed
- **Cannot create hashtags** via AppleScript (writes as plain text)
- **Cannot create links** via AppleScript (strips href)
- Both features are **read-only**
