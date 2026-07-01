# Changelog

All notable changes to TermGrid are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
