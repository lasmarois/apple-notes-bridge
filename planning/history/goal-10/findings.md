# Goal-10: Findings

## Search Components to Test

### BertTokenizer
Located in `Sources/NotesLib/Search/BertTokenizer.swift`
- Tokenizes text using BERT WordPiece algorithm
- Uses vocab from `bert_tokenizer_vocab.txt` (30k tokens)
- Outputs `MLMultiArray` for Core ML model input

### MiniLMEmbeddings
Located in `Sources/NotesLib/Search/MiniLMEmbeddings.swift`
- Wraps Core ML model `all-MiniLM-L6-v2.mlmodelc`
- Generates 384-dimensional embeddings
- Used by SemanticSearch for similarity matching

### SemanticSearch
Located in `Sources/NotesLib/Search/SemanticSearch.swift`
- Builds index of note embeddings
- Performs cosine similarity search
- Returns ranked results

### SearchIndex (FTS5)
Located in `Sources/NotesLib/Search/SearchIndex.swift`
- SQLite FTS5 full-text search index
- Porter stemmer tokenization
- Auto-builds and detects staleness

### Database Search
Located in `Sources/NotesLib/Notes/Database.swift`
- Case-insensitive search
- Multi-term AND/OR queries
- Fuzzy matching (Levenshtein distance)
- Date range and folder filters
