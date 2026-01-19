import Testing
import Foundation
@testable import NotesLib

@Suite("Encoder/Decoder Tests")
struct EncoderDecoderTests {

    @Test("Roundtrip basic text")
    func testRoundtripBasicText() throws {
        let encoder = NoteEncoder()
        let decoder = NoteDecoder()

        let testCases = [
            "Test Title\n\nThis is the body of the note.",
            "Simple Note\n\nLine 1\nLine 2\nLine 3",
            "Unicode Test 🎉\n\nEmojis work: 👍 ✅ 🚀",
            "Title Only"
        ]

        for originalText in testCases {
            let encoded = try encoder.encode(originalText)
            let decoded = try decoder.decode(encoded)
            #expect(decoded == originalText, "Roundtrip failed for: \(originalText.prefix(20))...")
        }
    }

    @Test("Handle empty text")
    func testEmptyText() throws {
        let encoder = NoteEncoder()
        let decoder = NoteDecoder()

        let encoded = try encoder.encode("")
        let decoded = try decoder.decode(encoded)
        #expect(decoded == "")
    }

    @Test("Handle special characters")
    func testSpecialCharacters() throws {
        let encoder = NoteEncoder()
        let decoder = NoteDecoder()

        let specialChars = "Test <>&\"' Special\n\nChars: \\ / @ # $ % ^ & * ( )"
        let encoded = try encoder.encode(specialChars)
        let decoded = try decoder.decode(encoded)
        #expect(decoded == specialChars)
    }

    @Test("Handle unicode characters")
    func testUnicode() throws {
        let encoder = NoteEncoder()
        let decoder = NoteDecoder()

        let unicode = "日本語テスト\n\n中文测试\n한국어 테스트\nالعربية"
        let encoded = try encoder.encode(unicode)
        let decoded = try decoder.decode(encoded)
        #expect(decoded == unicode)
    }
}

@Suite("Permissions Tests")
struct PermissionsTests {

    @Test("Database path is correctly constructed")
    func testDatabasePath() {
        let path = Permissions.notesDatabasePath
        #expect(path.contains("Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"))
    }
}

@Suite("Markdown Converter Tests")
struct MarkdownConverterTests {
    let converter = MarkdownConverter()

    // MARK: - Bold Tests

    @Test("Convert bold with asterisks")
    func testBoldAsterisks() {
        let result = converter.convert("This is **bold** text")
        #expect(result.contains("<b>bold</b>"))
    }

    @Test("Convert bold with underscores")
    func testBoldUnderscores() {
        let result = converter.convert("This is __bold__ text")
        #expect(result.contains("<b>bold</b>"))
    }

    // MARK: - Italic Tests

    @Test("Convert italic with asterisks")
    func testItalicAsterisks() {
        let result = converter.convert("This is *italic* text")
        #expect(result.contains("<i>italic</i>"))
    }

    // MARK: - Strikethrough Tests

    @Test("Convert strikethrough")
    func testStrikethrough() {
        let result = converter.convert("This is ~~deleted~~ text")
        #expect(result.contains("<strike>deleted</strike>"))
    }

    // MARK: - Header Tests

    @Test("Convert H1 header")
    func testH1Header() {
        let result = converter.convert("# Main Header")
        #expect(result.contains("font-size: 24px"))
        #expect(result.contains("Main Header"))
    }

    @Test("Convert H2 header")
    func testH2Header() {
        let result = converter.convert("## Section Header")
        #expect(result.contains("font-size: 18px"))
        #expect(result.contains("Section Header"))
    }

    @Test("Convert H3 header")
    func testH3Header() {
        let result = converter.convert("### Subsection")
        #expect(result.contains("<b>Subsection</b>"))
    }

    // MARK: - List Tests

    @Test("Convert bullet list with dash")
    func testBulletListDash() {
        let result = converter.convert("- Item one\n- Item two")
        #expect(result.contains("• Item one"))
        #expect(result.contains("• Item two"))
    }

    @Test("Convert bullet list with asterisk")
    func testBulletListAsterisk() {
        let result = converter.convert("* Item one\n* Item two")
        #expect(result.contains("• Item one"))
        #expect(result.contains("• Item two"))
    }

    // MARK: - Code Tests

    @Test("Convert inline code")
    func testInlineCode() {
        let result = converter.convert("Use `npm install` command")
        #expect(result.contains("<font face=\"Menlo\" color=\"#c7254e\">"))
        #expect(result.contains("npm install"))
        #expect(result.contains("</font>"))
    }

    @Test("Convert code block")
    func testCodeBlock() {
        let markdown = """
        ```
        function test() {
            return true;
        }
        ```
        """
        let result = converter.convert(markdown)
        #expect(result.contains("<font face=\"Menlo\">"))
        #expect(result.contains("function test()"))
    }

    @Test("Code preserves special characters")
    func testCodeSpecialChars() {
        let result = converter.convert("Use `<div>` and `&` in HTML")
        #expect(result.contains("&lt;div&gt;"))
        #expect(result.contains("&amp;"))
    }

    // MARK: - Blockquote Tests

    @Test("Convert blockquote")
    func testBlockquote() {
        let result = converter.convert("> This is a quote")
        #expect(result.contains("color=\"#666666\""))
        #expect(result.contains("▎"))
    }

    // MARK: - HTML Escaping Tests

    @Test("Escape HTML special characters")
    func testHTMLEscaping() {
        let result = converter.escapeHTML("<script>alert('xss')</script>")
        #expect(result.contains("&lt;script&gt;"))
        #expect(!result.contains("<script>"))
    }

    // MARK: - Combined Tests

    @Test("Convert mixed markdown")
    func testMixedMarkdown() {
        let markdown = """
        # Title

        This has **bold** and *italic*.

        - List item

        > Quote
        """
        let result = converter.convert(markdown)
        #expect(result.contains("font-size: 24px"))  // H1
        #expect(result.contains("<b>bold</b>"))
        #expect(result.contains("<i>italic</i>"))
        #expect(result.contains("• List item"))
        #expect(result.contains("▎"))  // Quote marker
    }
}

// MARK: - Integration Tests
// These tests interact with actual Apple Notes via AppleScript

@Suite("Integration Tests", .tags(.integration), .serialized)
struct IntegrationTests {
    static let testFolderName = "Claude-Integration-Tests"
    let appleScript = NotesAppleScript()
    let database = NotesDatabase()

    // MARK: - Setup/Teardown Helpers

    /// Create the test folder if it doesn't exist
    private func ensureTestFolder() throws {
        let folders = try appleScript.listFolders()
        if !folders.contains(Self.testFolderName) {
            do {
                _ = try appleScript.createFolder(name: Self.testFolderName)
                // Small delay for folder creation to propagate
                Thread.sleep(forTimeInterval: 0.5)
            } catch {
                // Folder might have been created by another process, ignore duplicate errors
                if !"\(error)".contains("Duplicate folder") {
                    throw error
                }
            }
        }
    }

    /// Clean up a note after test
    private func cleanup(noteId: String) {
        do {
            try appleScript.deleteNote(id: noteId)
        } catch {
            // Ignore cleanup errors
        }
    }

    /// Generate unique test title
    private func uniqueTitle(_ base: String) -> String {
        "\(base)-\(UUID().uuidString.prefix(8))"
    }

    // MARK: - Create Note Tests

    @Test("Create note via AppleScript")
    func testCreateNote() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Test Note")
        let body = "This is a test note body."

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        // Verify result has valid ID format
        #expect(result.id.hasPrefix("x-coredata://"))
        #expect(!result.uuid.isEmpty)

        // Cleanup
        cleanup(noteId: result.id)
    }

    @Test("Create note with markdown")
    func testCreateNoteWithMarkdown() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Markdown Test")
        let body = """
        This has **bold** and *italic* text.

        - List item 1
        - List item 2

        And some `inline code`.
        """

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        #expect(result.id.hasPrefix("x-coredata://"))

        // Verify via getNoteBody that markdown was converted
        let html = try appleScript.getNoteBody(id: result.id)
        #expect(html.contains("<b>bold</b>"))
        #expect(html.contains("<i>italic</i>"))
        #expect(html.contains("• List item 1"))

        cleanup(noteId: result.id)
    }

    // MARK: - Read Note Tests

    @Test("Read note via database")
    func testReadNote() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Read Test")
        let body = "Content to read back."

        // Create via AppleScript
        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        // Small delay for database sync
        Thread.sleep(forTimeInterval: 1.0)

        // Find in database by searching (since we don't have the UUID directly)
        let notes = try database.searchNotes(query: title, limit: 1)
        #expect(!notes.isEmpty, "Note should be found in database")

        if let note = notes.first {
            let content = try database.readNote(id: note.id)
            #expect(content.title == title)
            #expect(content.content.contains(body) || content.content.contains("Content to read back"))
        }

        cleanup(noteId: result.id)
    }

    @Test("Read note HTML via AppleScript")
    func testReadNoteHTML() throws {
        try ensureTestFolder()

        let title = uniqueTitle("HTML Read Test")
        let body = "Simple body text."

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        let html = try appleScript.getNoteBody(id: result.id)

        // Should contain the title (styled) and body
        #expect(html.contains(title))
        #expect(html.contains("Simple body text"))

        cleanup(noteId: result.id)
    }

    // MARK: - Update Note Tests

    @Test("Update note body")
    func testUpdateNoteBody() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Update Body Test")
        let originalBody = "Original body content."

        let result = try appleScript.createNote(
            title: title,
            body: originalBody,
            folder: Self.testFolderName
        )

        // Update the body
        let newBody = "Updated body content."
        try appleScript.updateNote(id: result.id, body: newBody)

        // Verify update
        let html = try appleScript.getNoteBody(id: result.id)
        #expect(html.contains("Updated body content"))

        cleanup(noteId: result.id)
    }

    @Test("Update note title and body together")
    func testUpdateNoteTitleAndBody() throws {
        try ensureTestFolder()

        let originalTitle = uniqueTitle("Original Title")
        let body = "Body stays the same."

        let result = try appleScript.createNote(
            title: originalTitle,
            body: body,
            folder: Self.testFolderName
        )

        // Update both title and body (this rebuilds the entire note content)
        let newTitle = uniqueTitle("New Title")
        let newBody = "Updated body content."
        try appleScript.updateNote(id: result.id, title: newTitle, body: newBody)

        // Small delay
        Thread.sleep(forTimeInterval: 0.5)

        // Verify via getNoteBody - both should be in the HTML
        let html = try appleScript.getNoteBody(id: result.id)
        #expect(html.contains(newTitle), "New title should be in HTML")
        #expect(html.contains("Updated body content"), "New body should be in HTML")

        cleanup(noteId: result.id)
    }

    // MARK: - Delete Note Tests

    @Test("Delete note")
    func testDeleteNote() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Delete Test")
        let body = "This note will be deleted."

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        // Verify we can read it before deletion
        let htmlBefore = try appleScript.getNoteBody(id: result.id)
        #expect(htmlBefore.contains(title), "Note should be readable before deletion")

        // Delete the note (moves to Recently Deleted)
        // This is the main thing we're testing - that deletion doesn't throw
        try appleScript.deleteNote(id: result.id)

        // Note: Apple Notes moves deleted notes to "Recently Deleted" folder
        // The note may still be accessible via its ID for a while
        // The key verification is that deleteNote() succeeded without error
    }

    // MARK: - List Notes Tests

    @Test("List notes in folder")
    func testListNotesInFolder() throws {
        try ensureTestFolder()

        // Create a couple test notes
        let title1 = uniqueTitle("List Test 1")
        let title2 = uniqueTitle("List Test 2")

        let result1 = try appleScript.createNote(title: title1, body: "Body 1", folder: Self.testFolderName)
        let result2 = try appleScript.createNote(title: title2, body: "Body 2", folder: Self.testFolderName)

        // Small delay for database sync
        Thread.sleep(forTimeInterval: 1.0)

        // List notes in test folder
        let notes = try database.listNotes(folder: Self.testFolderName, limit: 50)

        // Should find our test notes
        let titles = notes.map { $0.title }
        #expect(titles.contains(title1), "Should find first test note")
        #expect(titles.contains(title2), "Should find second test note")

        cleanup(noteId: result1.id)
        cleanup(noteId: result2.id)
    }

    // MARK: - Search Notes Tests

    @Test("Search notes by title")
    func testSearchNotes() throws {
        try ensureTestFolder()

        // Create a note with unique searchable term
        let searchTerm = "UniqueSearch\(UUID().uuidString.prefix(6))"
        let title = "\(searchTerm) Note"
        let body = "Body for search test."

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        // Small delay for database sync
        Thread.sleep(forTimeInterval: 1.0)

        // Search for the unique term
        let found = try database.searchNotes(query: searchTerm, limit: 10)

        #expect(!found.isEmpty, "Should find note by search term")
        if let note = found.first {
            #expect(note.title.contains(searchTerm))
        }

        cleanup(noteId: result.id)
    }

    // MARK: - Edge Cases

    @Test("Create note with special characters")
    func testSpecialCharacters() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Special <>&\"' Chars")
        let body = "Body with <html> & \"quotes\" and 'apostrophes'."

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        // Should not throw
        let html = try appleScript.getNoteBody(id: result.id)
        #expect(!html.isEmpty)

        cleanup(noteId: result.id)
    }

    @Test("Create note with unicode")
    func testUnicodeContent() throws {
        try ensureTestFolder()

        let title = uniqueTitle("Unicode Test 🎉")
        let body = "Emojis: 👍 ✅ 🚀\n日本語\n中文\n한국어"

        let result = try appleScript.createNote(
            title: title,
            body: body,
            folder: Self.testFolderName
        )

        let html = try appleScript.getNoteBody(id: result.id)
        #expect(html.contains("🎉") || html.contains("Unicode Test"))

        cleanup(noteId: result.id)
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var integration: Self
}
