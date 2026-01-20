# Findings: Goal-9 Enhanced Search

## Current Search Implementation Analysis

### What Exists (Database.swift:156-204)

```swift
public func searchNotes(query: String, limit: Int = 20) throws -> [Note] {
    // For now, search by title
    // TODO: Search within decoded content
    ...
    AND n.ZTITLE1 LIKE '%' || ? || '%'
}
```

**Current limitations:**
1. **Title-only search** - Only searches `ZTITLE1` column
2. **Exact substring match** - Uses SQL `LIKE` with wildcards
3. **Case-sensitive** - No COLLATE NOCASE
4. **No content search** - Note bodies are protobuf-encoded in `ZICNOTEDATA.ZDATA`
5. **Single term only** - No AND/OR logic
6. **No relevance ranking** - Results sorted by modification date only

### Existing Specialized Searches

| Search Type | Function | How It Works |
|-------------|----------|--------------|
| Hashtag search | `searchNotesByHashtag()` | Queries embedded objects table by `ZTYPEUTI1` |
| Note link search | `listNoteLinks()` | Queries embedded objects with link UTI |

### Data Architecture

```
ZICCLOUDSYNCINGOBJECT (notes)
  ├── ZTITLE1 (searchable, plain text)
  ├── ZSNIPPET (first line, plain text)
  └── ZNOTEDATA → ZICNOTEDATA.ZDATA (protobuf-encoded body)
```

**Key insight:** Content search requires decoding protobuf for each note - expensive operation.

---

## Context Search Exploration

### What is "Context Search"?

The user wants to find notes semantically related to a topic, not just exact keyword matches.

**Example scenario:**
- Query: "grep tricks"
- Should find:
  - Notes titled "grep commands"
  - Notes about regex, awk, sed (related tools)
  - Notes mentioning "pattern matching", "search files"
  - Notes in folders like "Commandes cool", "regex"

### Approaches to Context Search

#### 1. Enhanced Text Search (Low complexity)
- **Fuzzy matching**: Levenshtein distance for typos
- **Stemming**: "grepping" → "grep"
- **Multi-term**: AND/OR/NOT operators
- **Content search**: Decode protobuf and search body text

#### 2. Metadata-Aware Search (Medium complexity)
- Search folder names
- Search hashtags
- Combine title + snippet + folder + hashtags

#### 3. SQLite FTS5 (Medium complexity)
- Create a virtual table with full-text search
- Requires indexing decoded content
- Native SQLite feature, very fast
- Supports phrase search, boolean operators

#### 4. Semantic/Vector Search (High complexity)
- Generate embeddings for note content
- Use vector similarity (cosine distance)
- Requires ML model (local or API)
- True "understanding" of meaning

---

## Research: SQLite FTS5

SQLite has built-in full-text search via FTS5:

```sql
-- Create virtual table
CREATE VIRTUAL TABLE notes_fts USING fts5(
    note_id,
    title,
    content,
    folder,
    hashtags
);

-- Search with ranking
SELECT note_id, rank
FROM notes_fts
WHERE notes_fts MATCH 'grep OR regex'
ORDER BY rank;
```

**Pros:**
- Built into SQLite, no external dependencies
- Very fast queries
- Supports boolean operators, phrase search, prefix search
- BM25 ranking built-in

**Cons:**
- Need to build/maintain the index
- Index must be updated when notes change
- Adds complexity (separate table)

---

## Research: Local Embedding Options

For true semantic search, we'd need embeddings:

### Option A: Apple's NaturalLanguage Framework
```swift
import NaturalLanguage

let embedding = NLEmbedding.wordEmbedding(for: .english)
let vector = embedding?.vector(for: "grep")
```
- **Pros:** Built into macOS, fast, no network
- **Cons:** Word-level only, limited vocabulary

### Option B: Core ML with Custom Model
- Use sentence-transformer model converted to Core ML
- **Pros:** Runs locally, good quality
- **Cons:** Model size (~100MB+), conversion complexity

### Option C: External API (OpenAI, Anthropic, etc.)
- Send content to embedding API
- **Pros:** Best quality, no local resources
- **Cons:** Network dependency, cost, privacy concerns

---

## Decision Matrix

| Approach | Complexity | Quality | Performance | Dependencies |
|----------|------------|---------|-------------|--------------|
| Enhanced text search | Low | Medium | Fast | None |
| FTS5 index | Medium | Good | Very Fast | None |
| Apple NL embeddings | Medium | Medium | Fast | macOS 10.15+ |
| Semantic (external) | High | Excellent | Slow (network) | API key |

---

## Open Questions

1. **Should we modify the Apple Notes database?**
   - Adding FTS5 table might conflict with Notes.app sync
   - Alternative: Maintain separate index file

2. **How often do we rebuild the index?**
   - On every search? (slow)
   - On startup? (stale data)
   - Watch for changes? (complex)

3. **What's the acceptable search latency?**
   - Instant for small collections
   - Users with 1000+ notes?

4. **Should folder search be separate or unified?**
   - Unified: `search_notes("grep", include_folders: true)`
   - Separate: `search_folders("regex")`

---

## Core ML Semantic Search Research (Session 2)

### Option 1: Apple NLEmbedding (Sentence Embedding)

**Built-in to macOS/iOS, no dependencies**

```swift
import NaturalLanguage

let embedding = NLEmbedding.sentenceEmbedding(for: .english)!
let vector = embedding.vector(for: "grep tricks for searching files")
let distance = embedding.distance(between: sentence1, and: sentence2)
```

| Property | Value |
|----------|-------|
| Vector dimensions | 512 |
| Platform | macOS 10.15+, iOS 14+ |
| Languages | Limited (English, Spanish, French, German, etc.) |
| Output | ONE vector per sentence |
| Model size | Bundled with OS |

**Pros:**
- Zero dependencies, always available
- Fast, on-device
- Simple API

**Cons:**
- Limited language support
- Older technology (not transformer-based)
- Quality may be lower than BERT

---

### Option 2: Apple NLContextualEmbedding (BERT-based)

**WWDC23 addition - Transformer architecture**

```swift
import NaturalLanguage

let embedding = NLContextualEmbedding.contextualEmbedding(
    forModelIdentifier: .bert
)
let result = try embedding.embeddingResult(for: text, language: .english)
// Iterate over token vectors
result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, range, stop in
    // vector is 512-dimensional for each TOKEN
}
```

| Property | Value |
|----------|-------|
| Vector dimensions | 512 per token |
| Architecture | BERT (transformer) |
| Platform | macOS 14+, iOS 17+ |
| Languages | Multilingual (3 models) |
| Output | Vector PER TOKEN (not sentence) |
| Model size | Downloaded on-demand |

**Pros:**
- BERT-quality embeddings
- Multilingual
- No bundling required (OS downloads)

**Cons:**
- Returns token vectors, not sentence vectors (need pooling)
- Requires newer OS versions
- Asset download required first use

---

### Option 3: Custom Core ML Model (Sentence Transformers)

**Convert all-MiniLM-L6-v2 or similar**

Python conversion:
```python
import coremltools as ct
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')
# Trace and convert...
mlmodel = ct.convert(traced_model, ...)
mlmodel.save("SentenceEncoder.mlpackage")
```

| Property | Value |
|----------|-------|
| Vector dimensions | 384 (MiniLM) |
| Model size | ~80-100MB |
| Quality | High (sentence-optimized) |
| Platform | macOS 13+, iOS 16+ |
| Output | ONE vector per sentence |

**Pros:**
- Best quality sentence embeddings
- Optimized for semantic similarity
- Direct sentence → vector

**Cons:**
- Must bundle model (~100MB)
- Python conversion step
- Distribution complexity

---

### Vector Storage Options

#### sqlite-vec (Recommended)

Active SQLite extension for vector search:

```sql
-- Create vector table
CREATE VIRTUAL TABLE note_embeddings USING vec0(
    note_id TEXT PRIMARY KEY,
    embedding FLOAT[384] distance_metric=cosine
);

-- Insert
INSERT INTO note_embeddings(note_id, embedding)
VALUES ('uuid-123', vec_f32('[0.1, 0.2, ...]'));

-- Query (KNN search)
SELECT note_id, distance
FROM note_embeddings
WHERE embedding MATCH vec_f32('[query vector]')
ORDER BY distance
LIMIT 10;
```

**Pros:**
- Pure C, SIMD optimized
- Cross-platform (iOS, macOS, etc.)
- ~30MB memory
- Cosine, L2, L1 distance

**Cons:**
- Requires loading extension
- Sandboxing may be tricky

#### Alternative: Pure Swift Implementation

For simplicity, store vectors as BLOBs and compute cosine similarity in Swift:

```swift
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    let normA = sqrt(a.reduce(0) { $0 + $1 * $1 })
    let normB = sqrt(b.reduce(0) { $0 + $1 * $1 })
    return dot / (normA * normB)
}
```

**Pros:**
- No extension needed
- Simple to implement
- Works anywhere

**Cons:**
- Brute force O(n) search
- Slow for large collections

---

### Recommendation: Phased Approach

**Phase A: Start with NLEmbedding**
- Zero dependencies
- Works on older OS
- Good enough for many use cases
- Can compare sentences with `distance(between:)`

**Phase B: Upgrade to NLContextualEmbedding or Core ML**
- If quality isn't sufficient
- If multilingual is needed
- Pool token vectors for sentence embedding

**Phase C: Add sqlite-vec (if needed)**
- If performance is an issue
- If note count exceeds ~1000
- Otherwise brute force is fine

---

### Architecture Sketch

```
User Query: "find text in files"
       ↓
   Embedding Model
   (NLEmbedding or Core ML)
       ↓
   Query Vector [0.12, -0.34, ...]
       ↓
   Compare with Note Vectors
   (SQLite or in-memory)
       ↓
   Top-K Similar Notes
   (by cosine similarity)
       ↓
   Return Results
```

### Open Questions (Semantic)

1. **When to generate embeddings?**
   - On first search? (cold start delay)
   - Background indexing? (complexity)
   - Incremental on note change?

2. **Where to store vectors?**
   - Separate SQLite file (safe)
   - Separate table in Notes DB (risky)
   - In-memory cache (lost on restart)

3. **What to embed?**
   - Title only? (fast, low quality)
   - Title + snippet? (balanced)
   - Full content? (slow, best quality)

---

## Swift Libraries for Semantic Search (Session 2 - continued)

### Discovery: Ready-to-Use Swift Packages!

Found two excellent Swift packages that handle Core ML embeddings:

---

### Option A: SimilaritySearchKit (Recommended)

**GitHub:** https://github.com/ZachNagengast/similarity-search-kit

Complete semantic search solution with bundled models:

```swift
import SimilaritySearchKit
import SimilaritySearchKitMiniLMAll

// Create index with MiniLM model
let index = await SimilarityIndex(
    model: MiniLMAll(),
    metric: CosineSimilarity()
)

// Add notes to index
await index.addItem(id: noteId, text: noteTitle + " " + noteSnippet,
                    metadata: ["folder": folder])

// Semantic search
let results = await index.search("find text in files")
// Returns ranked SearchResult array
```

| Property | Value |
|----------|-------|
| MiniLM model size | 46 MB |
| Vector dimensions | 384 |
| Includes | Tokenizer, embeddings, similarity index |
| Platform | iOS 16+, macOS 13+ |

**Bundled Models:**
- `NativeEmbeddings` - Apple's built-in (smaller, less accurate)
- `MiniLMAll` - 46MB, fast, general purpose ⭐
- `MiniLMMultiQA` - 46MB, Q&A optimized
- `Distilbert` - 86MB, highest accuracy

**Pros:**
- All-in-one solution
- Models already converted to Core ML
- High-level API for indexing and search
- Active maintenance

**Cons:**
- 46MB+ added to app size
- May be overkill if we only need embeddings

---

### Option B: swift-embeddings

**GitHub:** https://github.com/jkrukowski/swift-embeddings

Loads models directly from Hugging Face:

```swift
import Embeddings

// Load model from Hugging Face
let modelBundle = try await Bert.loadModelBundle(
    from: "sentence-transformers/all-MiniLM-L6-v2"
)

// Generate embeddings
let texts = ["grep tricks", "find text in files"]
let encoded = modelBundle.batchEncode(texts)

// Compute similarity
let distance = cosineDistance(encoded, encoded)
```

| Property | Value |
|----------|-------|
| Model download | On-demand from HF |
| Supports | BERT, RoBERTa, XLM-RoBERTa, CLIP |
| Dependencies | MLTensor, MLTensorUtils |
| Platform | macOS 15+, iOS 18+ (requires MLTensor) |

**Pros:**
- Flexible model choice
- Downloads on-demand
- Supports many architectures

**Cons:**
- Newer, requires latest OS
- Lower-level API (need to build index ourselves)
- First-run download required

---

### Recommendation: SimilaritySearchKit

For our use case, **SimilaritySearchKit** is the better choice:

1. **Batteries included** - Model, tokenizer, index all bundled
2. **Stable platform support** - Works on macOS 13+ (we need this)
3. **Proven** - More mature, active community
4. **Simple integration** - Just add SPM package

### Integration Plan

1. Add `SimilaritySearchKitMiniLMAll` to Package.swift
2. Create `SemanticSearch` class wrapping the index
3. On first semantic search:
   - Build index from note titles + snippets
   - Cache in memory
4. Search returns top-K similar notes
5. New MCP tool: `semantic_search(query, limit)`

### Performance Considerations

| Note Count | Index Build | Search Time |
|------------|-------------|-------------|
| 100 | ~1 sec | <50ms |
| 1,000 | ~10 sec | <100ms |
| 10,000 | ~100 sec | ~500ms |

*Estimates based on typical embedding generation speed*

Index can be cached to avoid rebuild on every session.
