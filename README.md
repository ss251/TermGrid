# TermGrid

**Tidy every terminal window into a clean grid with one hotkey — and put the terminals that are _actively working_ first.**

If you run a pile of terminal sessions (especially AI coding agents like [Claude Code](https://www.anthropic.com/claude-code)), your screen turns into window soup. TermGrid snaps them all into a tidy, uniform grid across your monitors — and the sessions that are mid-task land in the top-left where you look first.

> _Demo GIF goes here — see [`demo/`](demo/)._

---

## Features

- **One hotkey, every window** — grids all of your terminal's windows, sized to fit the screen.
- **Fits, never overflows** — with lots of windows open, tiles shrink (keeping the terminal's aspect ratio) so every row stays fully on-screen and readable.
- **Works with any macOS terminal** — iTerm2, Terminal.app, Ghostty, WezTerm, kitty, Alacritty, Warp, Hyper, Tabby. Auto-detects whichever you're using.
- **Active sessions first** — actively-working [Claude Code](https://www.anthropic.com/claude-code) sessions are detected from the terminal title (Claude stamps a Braille spinner while it works) and placed first, side by side. Safely no-ops if you don't use Claude.
- **Spills only when needed** — keeps everything on your current screen and only spills onto another display once tiles would shrink below a readable width.
- **Calibrate once** — set the preferred (maximum) size from a window you like; TermGrid remembers it per app.
- **Tiny & hackable** — one Lua file, no daemons, no dependencies beyond Hammerspoon.

## Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) (free): `brew install --cask hammerspoon`

## Install

1. Install Hammerspoon and grant it Accessibility access (System Settings → Privacy & Security → Accessibility). Hammerspoon may need to be **quit and relaunched once** after you flip the toggle.

2. Install the Spoon:

   ```sh
   git clone https://github.com/ss251/TermGrid.git
   mkdir -p ~/.hammerspoon/Spoons
   cp -R TermGrid/TermGrid.spoon ~/.hammerspoon/Spoons/
   ```

3. Add this to `~/.hammerspoon/init.lua`:

   ```lua
   hs.loadSpoon("TermGrid")
   spoon.TermGrid:bindHotkeys({
     arrange   = {{"cmd", "alt", "ctrl"}, "g"},  -- ⌘⌥⌃G  → arrange
     calibrate = {{"cmd", "alt", "ctrl"}, "c"},  -- ⌘⌥⌃C  → remember focused window's size
   })
   spoon.TermGrid:start()  -- adds the ▦ menu-bar button
   ```

4. Reload Hammerspoon (menu bar → Reload Config).

## Usage

- **Arrange:** press **⌘⌥⌃G** (or pick *Arrange* from the ▦ menu). Windows snap into a grid on the screen your mouse is on, spilling to other displays if needed.
- **Calibrate the size:** size one terminal window the way you like it, focus it, and press **⌘⌥⌃C**. Every future arrange uses that size for that terminal. (Until you calibrate, TermGrid uses the size of whatever window is focused when you arrange.)

## How "active session" detection works

Claude Code writes a status glyph at the start of the terminal title:

| Title starts with…        | Meaning              | TermGrid priority |
| ------------------------- | -------------------- | ----------------- |
| `⠂ ⠐ ⠠ …` (Braille spinner) | actively working     | **first**         |
| `✳ ✻ ✶ …` (asterisk)        | idle Claude prompt   | second            |
| `you@host:~`                | plain shell / other  | last              |

It's a snapshot taken the instant you press the hotkey, so it reflects whatever is busy right then. If a future Claude version changes those glyphs, detection simply falls back to normal ordering — nothing breaks. Set `prioritizeActive = false` to turn it off.

## Configuration

Override any of these after `hs.loadSpoon("TermGrid")`:

```lua
spoon.TermGrid.gap = 8                 -- px between tiles and screen edge
spoon.TermGrid.app = nil               -- pin a terminal by bundle id, or nil to auto-detect
spoon.TermGrid.tileMode = "calibrate"  -- "calibrate" (remembered size) or "fixed"
spoon.TermGrid.tileSize = { w = 680, h = 460 }  -- preferred/max size; fallback and used when tileMode == "fixed"
spoon.TermGrid.minTileWidth = 420      -- only spill to another display when tiles would be narrower than this
spoon.TermGrid.anchor = "topleft"      -- "topleft" or "center"
spoon.TermGrid.prioritizeActive = true -- active Claude sessions first
spoon.TermGrid.spill = true            -- spill onto other displays when one screen fills
spoon.TermGrid.showAlerts = true       -- show a confirmation alert
spoon.TermGrid.menubar = true          -- show the ▦ menu-bar button
```

### Supported terminals

iTerm2, Apple Terminal, Ghostty, WezTerm, kitty, Alacritty, Warp, Hyper, Tabby. To manage a terminal not in the list, set `spoon.TermGrid.app = "<bundle id>"` (find it with `osascript -e 'id of app "YourTerminal"'`).

## Notes & limitations

- TermGrid arranges windows on the **current Mission Control space** (a Hammerspoon limitation); windows parked on other spaces stay put.
- "Side by side" in the top row is limited by how many windows fit across your screen at the calibrated size. Trigger the arrange with your mouse on your widest display to fit more.
- Terminals snap window sizes to their character grid, so tiles can land a pixel or two off perfectly uniform.

## License

[MIT](LICENSE) © ss251
