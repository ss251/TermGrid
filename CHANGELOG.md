# Changelog

All notable changes to TermGrid are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Emphasis for active sessions** (`heroActive`, default off) — actively-working
  and recently-active sessions get a proportionally larger tile. Windows are laid
  out as a **weighted squarified treemap**: an active window is ~`heroWeight`
  (default 2.0) times the *area* of an idle one, kept roughly square (never a wide
  strip) and always filling the screen. A just-finished session's tile stays big
  and fades back to normal over `recencyWindow` (default 120s), so a hand-off
  between two sessions looks balanced rather than one window snapping small. With
  nothing active, it's a uniform grid.
- **Auto-arrange** (`autoArrange`, default off) — watches for session activity and
  re-arranges automatically and quietly (no focus-steal, no alert). Keys off each
  window's activity *rank*, so Claude's Braille spinner animation doesn't thrash
  the layout. `autoInterval` (default 1.5s) sets the check frequency; `toggleAuto`
  is bindable to a hotkey and available from the menu-bar item.
  - **Organic resizing:** growing is real-time (a session starts working, or a
    window opens/closes). A window going idle does not re-arrange on its own — it
    only shrinks when something else upsizes and needs the room, and even then only
    in proportion to how recently it was active. Nothing snaps small the instant a
    session finishes.

### Changed
- **Tiles fill the screen with no wasted space.** The layout fills the whole
  display (via the treemap above), replacing the earlier fixed-size tiles that
  could run off the bottom of the screen. Spill onto another display happens only
  when tiles would drop below `minTileWidth` (default 420).

### Removed
- The intermediate "hero band" layout and its `heroRatio`, plus the `anchor` and
  `prioritizeActive` options — all superseded by the weighted treemap (emphasis is
  now expressed as tile area, and windows keep a stable position as activity
  changes so only their sizes shift).

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
