# Task Plan: Goal-9 Enhanced Search

## Goal
Implement enhanced search capabilities for Apple Notes including content search, fuzzy matching, multi-term queries, and optionally context-aware/semantic search.

## Current Phase
All phases complete! Goal-9 ready to archive.

## Phases

### Phase 1: Requirements & Discovery
- [x] Analyze current search implementation
- [x] Document limitations in findings.md
- [x] Research context search approaches
- [x] Discuss options with user and decide approach
- **Status:** complete ✅

### Phase 2: Core Search Improvements
- [x] Implement case-insensitive search
- [x] Add content search (decode protobuf and search body)
- [x] Add snippet search
- [x] Add folder-aware search
- [x] Add multi-term support (AND/OR)
- [x] Add threshold hint when few results found
- **Status:** complete ✅

### Phase 3: Advanced Search Features
- [x] Implement fuzzy matching (typo tolerance)
- [x] Add search filters (date range, folder scope)
- [x] Add search result snippets with highlights
- [x] Implement FTS5 index for performance
- [x] Add auto-build and staleness detection for FTS5
- **Status:** complete ✅

### Phase 4: Context Search (Semantic/AI)
- [x] Design semantic search architecture
- [x] Choose embedding approach (custom MiniLM implementation)
- [x] Research Swift libraries (SimilaritySearchKit, swift-embeddings)
- [x] Implement BertTokenizer.swift, MiniLMEmbeddings.swift
- [x] Implement SemanticSearch.swift with cosine similarity
- [x] Create GitHub Actions workflow to compile .mlpackage → .mlmodelc
- [x] Add semantic_search MCP tool
- **Status:** complete ✅

**Solution:** Built custom MiniLM implementation instead of SimilaritySearchKit:
- GitHub Actions compiles .mlpackage to .mlmodelc with Xcode
- Compiled model bundled as SPM resource
- Custom BERT tokenizer using vocab.txt
- Core ML inference with cosine similarity ranking

### Phase 5: Testing & Polish
- [x] Update MCP tool descriptions
- [x] Test semantic search (verified with 1798 notes)
- **Status:** complete ✅

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Start with analysis | Need to understand current implementation first |
| Quick wins first | Immediate value, low complexity, builds foundation |
| Separate FTS5 index file | Don't modify Apple's database |
| Auto-build on first use | Better UX than requiring manual build |
| Background rebuild when stale | Non-blocking, user sees results immediately |
| Skip external APIs | Privacy preference - keep data local |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| SimilaritySearchKit Core ML build failure | 1 | Built custom MiniLM implementation |
| SPM can't compile .mlpackage | 1 | GitHub Actions pre-compiles to .mlmodelc |
| GH Actions push denied | 1 | Added `permissions: contents: write` |

## Summary of Implemented Features

### search_notes tool
- Case-insensitive search
- Multi-term: `term1 AND term2` or `term1 OR term2`
- Fuzzy matching: `fuzzy=true` for typo tolerance
- Content search: `search_content=true` to search note bodies
- Filters: `folder`, `modified_after`, `modified_before`, `created_after`, `created_before`
- Result snippets with **highlighted** matches
- Threshold hint when <5 results found

### fts_search tool
- FTS5 full-text search (3000x faster than content scan)
- Auto-builds index on first use (~0.6s for 1798 notes)
- Detects staleness and rebuilds in background
- Porter stemmer tokenization
- Ranked results with highlighted snippets

### build_search_index tool
- Manually trigger index rebuild
- Indexes title, folder, and full note content

### semantic_search tool
- AI-powered semantic search using MiniLM embeddings
- 384-dimensional vectors, cosine similarity ranking
- Auto-builds index on first use
- Finds conceptually similar notes (not just keyword matches)
- Example: "cooking recipes" finds food preparation notes

## Performance Benchmarks

| Method | Time (1798 notes) |
|--------|-------------------|
| Index only (title/snippet/folder) | 7ms |
| Content scan | 170ms |
| **FTS5** | **0.1ms** |

FTS5 is 1500-3000x faster than content scan.
