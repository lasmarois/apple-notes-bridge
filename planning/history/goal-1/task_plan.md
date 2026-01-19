# Task Plan: Research Apple Notes Integrability

## Goal
Discover all viable options for programmatically accessing Apple Notes (read, write, organize) to enable LLM integration.

## Current Phase
Phase 5

## Phases

### Phase 1: Discovery - Official & Native Options
- [x] Research AppleScript/JXA capabilities for Notes.app
- [x] Investigate Apple's native APIs (EventKit, CloudKit, etc.)
- [x] Check Shortcuts/Automator integration possibilities
- [x] Document limitations and permissions required
- **Status:** complete

### Phase 2: Discovery - Third-Party & Reverse Engineering
- [x] Research existing open-source projects accessing Apple Notes
- [x] Investigate the Notes SQLite database structure
- [x] Look for unofficial APIs or workarounds
- [x] Check MCP servers that might already exist
- **Status:** complete

### Phase 3: Discovery - iCloud & Sync Options
- [x] Research iCloud API access possibilities
- [x] Investigate web-based access (icloud.com)
- [x] Check if there are any REST APIs available
- **Status:** complete

### Phase 4: Evaluation & Comparison
- [x] Create comparison matrix of all options
- [x] Evaluate: reliability, maintenance burden, feature coverage
- [x] Identify risks and limitations per approach
- [x] Recommend best approach(es) for LLM integration
- **Status:** complete

### Phase 5: Documentation & Delivery
- [x] Create DELIVERABLE-INTEGRATION-OPTIONS-GOAL-1.md
- [x] Summarize findings and recommendation
- [ ] Archive goal to planning/history/goal-1/
- **Status:** in_progress

## Key Questions
1. Can AppleScript/JXA access note content, folders, and attachments?
   → **Yes for read + create. No update/delete. No encrypted notes. No attachments.**
2. Is there direct database access that's reliable across macOS versions?
   → **Risky. Protobuf format changes between versions. Requires Full Disk Access.**
3. Are there existing MCP servers or tools we can leverage?
   → **Yes! mcp-apple-notes (RafalWilinski) is best - has RAG + semantic search.**
4. What's the most maintainable long-term solution?
   → **AppleScript/JXA via MCP server. Database access is fragile.**
5. What permissions/entitlements are required for each approach?
   → **JXA: Automation permission. DB: Full Disk Access. iCloud: 2FA blocks automation.**

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| **DB-only approach** | Full CRUD, attachments, consistency - AppleScript too limited |
| **Swift** | Zero deps (SQLite + runtime built into macOS), native ecosystem |
| **Native macOS integration** | Proper FDA permission flow, code signing, notarization |
| **iCloud-compatible writes** | Preserve CloudKit metadata, update timestamps correctly |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| | | |

## Notes
- This is a research goal - output is a recommendation document
- Focus on macOS integration first, iOS can be a future goal
- Consider both local-only and iCloud-synced notes scenarios
