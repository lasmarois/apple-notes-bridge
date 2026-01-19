import Foundation

/// Semantic search engine for Apple Notes using MiniLM embeddings
public actor SemanticSearch {
    private var embeddings: MiniLMEmbeddings?
    private var noteEmbeddings: [String: [Float]] = [:]  // noteId -> embedding
    private var noteMetadata: [String: (title: String, folder: String?)] = [:]
    private var isBuilding = false
    private let notesDB: NotesDatabase

    public init(notesDB: NotesDatabase) {
        self.notesDB = notesDB
    }

    /// Check if the index has been built
    public var isIndexed: Bool {
        return !noteEmbeddings.isEmpty
    }

    /// Get the number of indexed notes
    public var indexedCount: Int {
        return noteEmbeddings.count
    }

    /// Build or rebuild the semantic index from all notes
    /// - Parameter forceRebuild: If true, rebuilds even if index exists
    /// - Returns: Number of notes indexed
    @discardableResult
    public func buildIndex(forceRebuild: Bool = false) async throws -> Int {
        // Prevent concurrent builds
        guard !isBuilding else {
            throw SemanticSearchError.buildInProgress
        }

        // Skip if already built and not forcing rebuild
        if !forceRebuild && !noteEmbeddings.isEmpty {
            return noteEmbeddings.count
        }

        isBuilding = true
        defer { isBuilding = false }

        // Initialize embeddings model if needed
        if embeddings == nil {
            embeddings = try MiniLMEmbeddings()
        }

        guard let embeddings = embeddings else {
            throw SemanticSearchError.modelNotInitialized
        }

        // Clear existing index
        noteEmbeddings.removeAll()
        noteMetadata.removeAll()

        // Fetch all notes from database
        let notes = try notesDB.listNotes(limit: 10000)

        for note in notes {
            // Combine title and folder for embedding
            var textToEmbed = note.title
            if let folder = note.folder {
                textToEmbed += " " + folder
            }

            // Generate embedding
            if let embedding = await embeddings.encode(textToEmbed) {
                noteEmbeddings[note.id] = embedding
                noteMetadata[note.id] = (title: note.title, folder: note.folder)
            }
        }

        return noteEmbeddings.count
    }

    /// Search notes semantically
    /// - Parameters:
    ///   - query: Natural language search query
    ///   - limit: Maximum number of results (default 10)
    /// - Returns: Array of search results with note IDs and similarity scores
    public func search(query: String, limit: Int = 10) async throws -> [SemanticSearchResult] {
        // Build index if not already built
        if noteEmbeddings.isEmpty {
            try await buildIndex()
        }

        // Initialize embeddings model if needed
        if embeddings == nil {
            embeddings = try MiniLMEmbeddings()
        }

        guard let embeddings = embeddings else {
            throw SemanticSearchError.modelNotInitialized
        }

        // Encode the query
        guard let queryEmbedding = await embeddings.encode(query) else {
            throw SemanticSearchError.encodingFailed
        }

        // Calculate similarity scores for all notes
        var scores: [(noteId: String, score: Float)] = []

        for (noteId, noteEmbedding) in noteEmbeddings {
            let similarity = MiniLMEmbeddings.cosineSimilarity(queryEmbedding, noteEmbedding)
            scores.append((noteId: noteId, score: similarity))
        }

        // Sort by score (highest first) and take top results
        scores.sort { $0.score > $1.score }
        let topResults = scores.prefix(limit)

        // Convert to SemanticSearchResult
        return topResults.map { result in
            let metadata = noteMetadata[result.noteId]
            return SemanticSearchResult(
                noteId: result.noteId,
                score: result.score,
                title: metadata?.title ?? "",
                folder: metadata?.folder
            )
        }
    }

    /// Add a single note to the index (for incremental updates)
    public func addNote(id: String, title: String, folder: String?) async throws {
        if embeddings == nil {
            embeddings = try MiniLMEmbeddings()
        }

        guard let embeddings = embeddings else {
            throw SemanticSearchError.modelNotInitialized
        }

        var textToEmbed = title
        if let folder = folder {
            textToEmbed += " " + folder
        }

        if let embedding = await embeddings.encode(textToEmbed) {
            noteEmbeddings[id] = embedding
            noteMetadata[id] = (title: title, folder: folder)
        }
    }

    /// Remove a note from the index
    public func removeNote(id: String) {
        noteEmbeddings.removeValue(forKey: id)
        noteMetadata.removeValue(forKey: id)
    }

    /// Clear the entire index
    public func clearIndex() {
        noteEmbeddings.removeAll()
        noteMetadata.removeAll()
    }
}

/// Result from semantic search
public struct SemanticSearchResult: Sendable {
    public let noteId: String
    public let score: Float
    public let title: String
    public let folder: String?

    public init(noteId: String, score: Float, title: String, folder: String?) {
        self.noteId = noteId
        self.score = score
        self.title = title
        self.folder = folder
    }
}

/// Errors for semantic search
public enum SemanticSearchError: Error, LocalizedError {
    case indexNotReady
    case buildInProgress
    case modelNotInitialized
    case encodingFailed
    case searchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .indexNotReady:
            return "Semantic index is not ready. Please wait for indexing to complete."
        case .buildInProgress:
            return "Index build is already in progress."
        case .modelNotInitialized:
            return "MiniLM embedding model could not be initialized."
        case .encodingFailed:
            return "Failed to encode text for semantic search."
        case .searchFailed(let reason):
            return "Semantic search failed: \(reason)"
        }
    }
}
