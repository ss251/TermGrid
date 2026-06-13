--- === TermGrid ===
---
--- Tidy every terminal window into a clean grid with one hotkey — and put the
--- terminals that are *actively working* first.
---
--- Works with any macOS terminal (iTerm2, Terminal.app, Ghostty, WezTerm, kitty,
--- Alacritty, Warp, Hyper, Tabby). Each window is set to a consistent size
--- (calibrate it once from a window you like), packed top-left, and spilled onto
--- your other displays only when one screen fills up.
---
--- Bonus for Claude Code users: sessions that are mid-task are detected from the
--- terminal's title (Claude stamps a Braille spinner while it works) and placed
--- first, side by side, so the ones doing something land where you look first.
---
--- Download: https://github.com/ss251/TermGrid

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "TermGrid"
obj.version = "1.0.0"
obj.author = "ss251"
obj.homepage = "https://github.com/ss251/TermGrid"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--------------------------------------------------------------------------------
-- Configuration (override after `hs.loadSpoon("TermGrid")`)
--------------------------------------------------------------------------------

--- TermGrid.gap
--- Variable
--- Pixels between tiles and around the screen edge. Default 8.
obj.gap = 8

--- TermGrid.app
--- Variable
--- Bundle id of the terminal to manage, e.g. "com.googlecode.iterm2".
--- `nil` (default) auto-detects: the frontmost terminal, or the running
--- terminal with the most windows.
obj.app = nil

--- TermGrid.tileMode
--- Variable
--- "calibrate" (default) sizes every window to a remembered size — set it with
--- the calibrate hotkey, or it falls back to your currently-focused window's
--- size. "fixed" always uses `TermGrid.tileSize`.
obj.tileMode = "calibrate"

--- TermGrid.tileSize
--- Variable
--- Fallback tile size in points, and the size used when tileMode == "fixed".
obj.tileSize = { w = 680, h = 460 }

--- TermGrid.anchor
--- Variable
--- "topleft" (default) packs from the top-left corner; "center" centers the grid.
obj.anchor = "topleft"

--- TermGrid.prioritizeActive
--- Variable
--- When true (default), actively-working Claude Code sessions are placed first
--- (top-left, side by side), then idle Claude sessions, then everything else.
--- Detection is by the terminal title's leading glyph; it safely no-ops for
--- non-Claude sessions.
obj.prioritizeActive = true

--- TermGrid.spill
--- Variable
--- When true (default), windows that don't fit on one screen spill onto your
--- other displays. When false, everything stays on the active screen.
obj.spill = true

--- TermGrid.showAlerts
--- Variable
--- Show a small confirmation alert after arranging/calibrating. Default true.
obj.showAlerts = true

--- TermGrid.menubar
--- Variable
--- Show a ▦ menu-bar button (left-click arranges). Default true.
obj.menubar = true

--- TermGrid.terminals
--- Variable
--- Known terminal bundle ids used for auto-detection when `app` is nil.
obj.terminals = {
  "com.googlecode.iterm2",    -- iTerm2
  "com.apple.Terminal",       -- Apple Terminal
  "com.mitchellh.ghostty",    -- Ghostty
  "com.github.wez.wezterm",   -- WezTerm
  "net.kovidgoyal.kitty",     -- kitty
  "org.alacritty",            -- Alacritty
  "dev.warp.Warp-Stable",     -- Warp
  "co.zeit.hyper",            -- Hyper
  "org.tabby",                -- Tabby
}

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------

-- Rank a window by its title's leading status glyph (set by Claude Code):
-- a Braille spinner (U+2800–U+28FF) means it's actively working; a dingbat
-- asterisk (✳ ✻ ✶ …, U+27xx) means an idle Claude prompt. Lower sorts first.
--   0 = active Claude, 1 = idle Claude, 2 = anything else.
local function windowRank(win)
  local t = (win:title() or ""):gsub("^%s+", "")  -- ignore any leading space
  local b1, b2 = t:byte(1), t:byte(2)
  if b1 == 0xE2 and b2 then
    if b2 >= 0xA0 and b2 <= 0xA3 then return 0 end  -- Braille spinner = working
    if b2 == 0x9C or b2 == 0x9D then return 1 end    -- ✳/✻/✶ = idle Claude prompt
  end
  return 2
end

-- How many tiles of size tileW×tileH fit on `screen`.
local function capacityFor(screen, tileW, tileH, gap)
  local f = screen:frame()
  local colsFit = math.max(1, math.floor((f.w - gap) / (tileW + gap)))
  local rowsFit = math.max(1, math.floor((f.h - gap) / (tileH + gap)))
  return colsFit * rowsFit
end

-- Lay `wins` out as a fixed-tile grid on one `screen`.
local function layoutOnScreen(screen, wins, tileW, tileH, gap, anchor)
  local f = screen:frame()  -- usable area (excludes menu bar + Dock)
  local n = #wins
  local colsFit = math.max(1, math.floor((f.w - gap) / (tileW + gap)))
  local cols = math.min(n, colsFit)
  local rows = math.ceil(n / cols)

  local originX, originY
  if anchor == "center" then
    local blockW = cols * tileW + (cols - 1) * gap
    local blockH = rows * tileH + (rows - 1) * gap
    originX = math.max(f.x + gap, f.x + (f.w - blockW) / 2)
    originY = math.max(f.y + gap, f.y + (f.h - blockH) / 2)
  else  -- "topleft"
    originX = f.x + gap
    originY = f.y + gap
  end

  for i, win in ipairs(wins) do
    local idx = i - 1
    local row = math.floor(idx / cols)
    local col = idx - row * cols
    win:setFrame({
      x = originX + col * (tileW + gap),
      y = originY + row * (tileH + gap),
      w = tileW,
      h = tileH,
    }, 0)
  end
end

function obj:_isTerminal(bundleID)
  if not bundleID then return false end
  for _, b in ipairs(self.terminals) do
    if b == bundleID then return true end
  end
  return false
end

-- Resolve which terminal app to manage.
function obj:_targetApp()
  if self.app then return hs.application.get(self.app) end
  local front = hs.application.frontmostApplication()
  if front and self:_isTerminal(front:bundleID()) then return front end
  -- Otherwise the running terminal with the most windows.
  local best, bestN = nil, -1
  for _, b in ipairs(self.terminals) do
    local a = hs.application.get(b)
    if a then
      local n = #a:allWindows()
      if n > bestN then best, bestN = a, n end
    end
  end
  return best
end

function obj:_settingsKey(app)
  return "TermGrid.tile." .. (app:bundleID() or app:name())
end

-- Resolve the tile size for an app: fixed → saved → focused window → default.
function obj:_tileSize(app)
  if self.tileMode == "fixed" then
    return self.tileSize.w, self.tileSize.h
  end
  local saved = hs.settings.get(self:_settingsKey(app))
  if saved and saved.w and saved.h then
    return saved.w, saved.h
  end
  local ws = app:allWindows()
  local w = app:focusedWindow() or ws[1]
  if w then
    local f = w:frame()
    return f.w, f.h
  end
  return self.tileSize.w, self.tileSize.h
end

local function alert(self, msg)
  if self.showAlerts then hs.alert.show(msg) end
end

--------------------------------------------------------------------------------
-- Public methods
--------------------------------------------------------------------------------

--- TermGrid:arrange()
--- Method
--- Arrange the target terminal's windows into a grid, active sessions first,
--- spilling onto other displays as needed.
function obj:arrange()
  if not hs.accessibilityState() then
    hs.alert.show("Grant Hammerspoon Accessibility access:\nSystem Settings → Privacy & Security → Accessibility")
    hs.accessibilityState(true)  -- prompts the user
    return self
  end

  local app = self:_targetApp()
  if not app then
    alert(self, "TermGrid: no terminal app found")
    return self
  end

  local wins = hs.fnutils.filter(app:allWindows(), function(w)
    return w:isStandard() and not w:isMinimized()
  end)
  table.sort(wins, function(a, b)
    if self.prioritizeActive then
      local ra, rb = windowRank(a), windowRank(b)
      if ra ~= rb then return ra < rb end
    end
    return a:id() < b:id()
  end)

  local n = #wins
  if n == 0 then
    alert(self, "TermGrid: no " .. app:name() .. " windows")
    return self
  end

  local tileW, tileH = self:_tileSize(app)
  local gap = self.gap

  -- Screen order: the one under the mouse first, then the rest left-to-right.
  local primary = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local screens = { primary }
  if self.spill then
    local others = hs.fnutils.filter(hs.screen.allScreens(), function(s) return s ~= primary end)
    table.sort(others, function(a, b) return a:frame().x < b:frame().x end)
    for _, s in ipairs(others) do screens[#screens + 1] = s end
  end

  -- Fill screens in order (primary first) up to capacity, spilling to the next.
  -- Because `wins` is sorted active-first, the busy sessions fill the primary
  -- screen's top row before any spill happens.
  local caps = {}
  for i, s in ipairs(screens) do caps[i] = capacityFor(s, tileW, tileH, gap) end

  local buckets = {}
  local si, room = 1, caps[1]
  for _, w in ipairs(wins) do
    while room <= 0 and si < #screens do si = si + 1; room = caps[si] end
    buckets[si] = buckets[si] or {}
    table.insert(buckets[si], w)
    room = room - 1
  end

  local used = 0
  for i = 1, #screens do
    if buckets[i] and #buckets[i] > 0 then
      layoutOnScreen(screens[i], buckets[i], tileW, tileH, gap, self.anchor)
      used = used + 1
    end
  end

  app:activate()  -- bring the terminal forward after arranging
  alert(self, string.format("TermGrid: %d %s window%s · %d screen%s",
    n, app:name(), n > 1 and "s" or "", used, used > 1 and "s" or ""))
  return self
end

--- TermGrid:calibrate()
--- Method
--- Remember the focused window's current size as the grid tile size for its app.
function obj:calibrate()
  local w = hs.window.focusedWindow()
  if not w then
    alert(self, "TermGrid: focus a terminal window first")
    return self
  end
  local app = w:application()
  local f = w:frame()
  hs.settings.set(self:_settingsKey(app), { w = f.w, h = f.h })
  alert(self, string.format("TermGrid: tile size %.0f×%.0f saved for %s", f.w, f.h, app:name()))
  return self
end

--- TermGrid:bindHotkeys(mapping)
--- Method
--- Bind hotkeys. Spec keys: `arrange`, `calibrate`.
--- Example:
---   spoon.TermGrid:bindHotkeys({
---     arrange   = {{"cmd","alt","ctrl"}, "g"},
---     calibrate = {{"cmd","alt","ctrl"}, "c"},
---   })
function obj:bindHotkeys(mapping)
  local spec = {
    arrange   = function() self:arrange() end,
    calibrate = function() self:calibrate() end,
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

--- TermGrid:start()
--- Method
--- Create the ▦ menu-bar button (if `menubar` is true). Clicking it opens a
--- small menu (Arrange / Set tile size). For instant arranging, use the hotkey.
function obj:start()
  if self.menubar and not self._menu then
    self._menu = hs.menubar.new()
    if self._menu then
      self._menu:setTitle("▦")
      self._menu:setTooltip("TermGrid — arrange terminal windows")
      self._menu:setMenu({
        { title = "Arrange terminal windows", fn = function() self:arrange() end },
        { title = "Set tile size from focused window", fn = function() self:calibrate() end },
        { title = "-" },
        { title = "TermGrid " .. self.version, disabled = true },
      })
    end
  end
  return self
end

--- TermGrid:stop()
--- Method
--- Remove the menu-bar button.
function obj:stop()
  if self._menu then self._menu:delete(); self._menu = nil end
  return self
end

return obj
