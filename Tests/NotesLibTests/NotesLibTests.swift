import Testing
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
