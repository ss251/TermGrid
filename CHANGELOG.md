# Changelog

All notable changes to TermGrid are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Hero mode** (`heroActive`, default off) — actively-working Claude sessions get
  a larger tile in a taller band across the top of the screen, and everything else
  fills a denser grid below. `heroRatio` (default 1.7) tunes how much bigger the
  hero tiles are. Falls back to an equal grid when nothing is working (or when all
  sessions are).
- **Auto-arrange** (`autoArrange`, default off) — watches for session activity
  changes (a session starts/finishes working, or a window opens/closes) and
  re-arranges automatically and quietly, without stealing focus. Keys off each
  window's activity *rank*, so Claude's Braille spinner animation doesn't thrash
  the layout. `autoInterval` (default 1.5s) sets the check frequency; `toggleAuto`
  is bindable to a hotkey and available from the menu-bar item.
  - **Organic resizing:** growing is real-time (a session starts working, or a
    window opens/closes, re-arranges at once). A window that goes idle keeps its
    size — it only shrinks when something else upsizes and needs the room. So a
    just-finished session's big tile lingers until another session takes over,
    instead of collapsing the moment it goes idle. (This also keeps the *most
    recently active* session the big one.)

### Changed
- **Tiles now fill the screen edge-to-edge.** Windows stretch to fill their grid
  cell — equal sizes, no letterboxing or leftover whitespace — instead of keeping
  the terminal's exact aspect ratio. The grid's shape still follows your
  calibrated proportions so tiles look like terminals. `tileSize`/calibrate now
  guide the grid's shape rather than capping the tile size.

## [1.1.0] — 2026-07-02

### Changed
- **Windows now scale to fit the screen.** Tiles shrink — keeping the terminal's
  aspect ratio, and never larger than your calibrated size — so every row stays
  fully on-screen. Previously tiles were a fixed size, and with many windows open
  the bottom rows ran off the screen and became unreadable.
- **Spills far less eagerly.** A display now holds many more windows before
  spilling (roughly 2× in typical setups). It only spills onto another screen
  once tiles would have to shrink below a readable width — not merely when they'd
  exceed the default size.

### Added
- `minTileWidth` config variable (default `420`) — the readability floor that
  controls when spill kicks in. Lower it to pack more windows onto one screen;
  raise it to spill sooner in exchange for bigger tiles.

### Notes
- The calibrated/`tileSize` value is now the **preferred (maximum)** tile size
  rather than a fixed size; windows never exceed it but shrink to fit.

## [1.0.0] — 2026-07-02

### Added
- Initial release — a Hammerspoon Spoon that tidies terminal windows into a grid
  with one hotkey.
- Auto-detects your terminal: iTerm2, Terminal.app, Ghostty, WezTerm, kitty,
  Alacritty, Warp, Hyper, Tabby (or pin one via `app`).
- Prioritizes actively-working [Claude Code](https://www.anthropic.com/claude-code)
  sessions, detected from the terminal title's status glyph, placing them first.
- Multi-monitor spill, top-left or centered packing, and a calibrate hotkey that
  remembers a per-app tile size.
- API: `:arrange()`, `:calibrate()`, `:bindHotkeys()`, `:start()`, `:stop()`, plus
  a menu-bar button and documented config variables.
