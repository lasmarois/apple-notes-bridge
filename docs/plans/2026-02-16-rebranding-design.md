# Rebranding Design: claude-notes-bridge → apple-notes-bridge

**Date:** 2026-02-16
**Goal:** Rename the project from `claude-notes-bridge` to `apple-notes-bridge` and the app from `NotesSearch` to `Notes Bridge`.

## Naming Map

| Component | Old | New |
|-----------|-----|-----|
| GitHub repo | `lasmarois/claude-notes-bridge` | `lasmarois/apple-notes-bridge` |
| CLI binary | `claude-notes-bridge` | `apple-notes-bridge` |
| Swift package name | `claude-notes-bridge` | `apple-notes-bridge` |
| Source directory | `Sources/claude-notes-bridge/` | `Sources/apple-notes-bridge/` |
| .app bundle | `NotesSearch.app` | `Notes Bridge.app` |
| .app display name | `Notes Search` | `Notes Bridge` |
| .app binary (CFBundleExecutable) | `NotesSearch` | `NotesBridge` |
| SPM product (app) | `notes-search` | `notes-bridge` |
| SwiftUI app struct | `NotesSearchApp` | `NotesBridgeApp` |
| SwiftUI source dir | `Sources/NotesSearch/` | `Sources/NotesBridge/` |
| CLI entry struct | `NotesBridge` | `AppleNotesBridge` |
| MCP server name | `apple-notes` | `apple-notes-bridge` |
| Bundle ID (CLI pkg) | `com.lasmarois.claude-notes-bridge.cli` | `com.lasmarois.apple-notes-bridge.cli` |
| Bundle ID (app pkg) | `com.lasmarois.claude-notes-bridge.ui` | `com.lasmarois.apple-notes-bridge.ui` |
| Bundle ID (app) | `com.lasmarois.notes-search` | `com.lasmarois.apple-notes-bridge.ui` |
| Icon file | `Resources/NotesSearch.icon` | `Resources/NotesBridge.icon` |
| .icns fallback | `Resources/AppIcon.icns` | `Resources/AppIcon.icns` (unchanged) |
| Install path (CLI) | `/usr/local/bin/claude-notes-bridge` | `/usr/local/bin/apple-notes-bridge` |
| Install path (app) | `/Applications/NotesSearch.app` | `/Applications/Notes Bridge.app` |
| Signing cert | `NotesSearch Dev` | `NotesSearch Dev` (unchanged — just an identity) |
| NotesLib | `NotesLib` | `NotesLib` (unchanged — internal library) |

## Unchanged Components

- **NotesLib** — Internal library name, no user-facing impact
- **Signing certificate** — `NotesSearch Dev` is just an identity name in the keychain, not user-visible
- **AppIcon.icns** — Fallback icon filename, internal
- **Database/protobuf code** — No naming references to change

## Files to Modify

### Package & Build
- `Package.swift` — Package name, product names, target names, source paths
- `Makefile` — Binary name constant

### Swift Source
- `Sources/claude-notes-bridge/` → rename directory to `Sources/apple-notes-bridge/`
- `Sources/apple-notes-bridge/CLI.swift` — `commandName`, struct name, description text, MCP setup references
- `Sources/apple-notes-bridge/Version.swift` — No changes needed
- `Sources/NotesSearch/` → rename directory to `Sources/NotesBridge/`
- `Sources/NotesBridge/NotesSearchApp.swift` → rename to `NotesBridgeApp.swift`, rename struct
- `Sources/NotesBridge/ContentView.swift` — "Notes Search" display strings

### Resources
- `Resources/NotesSearch.icon/` → rename to `Resources/NotesBridge.icon/`

### CI/CD
- `.github/workflows/release.yml` — Product names, paths, bundle IDs, Info.plist, icon references
- `.github/workflows/ci.yml` — Build product names if referenced

### Installer
- `installer/distribution.xml` — Title, package IDs, display names
- `installer/scripts/postinstall` — Binary paths, MCP server name, app path (needs quoting for space)
- `installer/resources/readme.html` — CLI name, MCP command
- `installer/resources/welcome.html` — Display text

### Documentation
- `README.md` — All CLI examples, repo URLs, MCP config, build instructions
- `.mcp.json` — MCP server key and command path

### Planning repo
- `.planning/` docs that reference `claude-notes-bridge`
- `.claude/rules/` files that reference old names
- Memory files

## Breaking Changes for Existing Users

1. **MCP config** — `apple-notes` → `apple-notes-bridge`, binary path changes. The `setup` command handles re-registration.
2. **Full Disk Access** — New `.app` name requires re-granting FDA in System Settings.
3. **Binary path** — `/usr/local/bin/claude-notes-bridge` → `/usr/local/bin/apple-notes-bridge`. Old binary remains until manually removed.
4. **GitHub URLs** — GitHub auto-redirects after repo rename, but `git remote` URLs need updating for contributors.

## Implementation Order

1. **Rename directories & files** — Source dirs, icon, app file
2. **Update Package.swift** — Core build configuration
3. **Update Swift source** — Struct names, display strings, MCP references
4. **Update CI/CD** — Workflows
5. **Update installer** — distribution.xml, postinstall, HTML resources
6. **Update README** — Documentation
7. **Update planning repo** — Rules, docs, memory
8. **Rename GitHub repo** — Last step, via `gh repo rename`
9. **Tag release** — v0.6.0 under new name
