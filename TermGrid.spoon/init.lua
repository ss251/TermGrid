--- === TermGrid ===
---
--- Tidy every terminal window into a clean grid with one hotkey — and put the
--- terminals that are *actively working* first.
---
--- Works with any macOS terminal (iTerm2, Terminal.app, Ghostty, WezTerm, kitty,
--- Alacritty, Warp, Hyper, Tabby). Windows fill the screen in an even grid of
--- equal-size tiles (no wasted space), packed top-left, and spill onto another
--- display only when tiles would get too narrow to read.
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
obj.version = "1.1.0"
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
--- How the preferred tile shape is chosen — it guides the grid's proportions so
--- tiles look like terminals, but tiles always stretch to fill the screen.
--- "calibrate" (default) uses a remembered size — set it with the calibrate
--- hotkey, or it falls back to your currently-focused window's size. "fixed"
--- always uses `TermGrid.tileSize`.
obj.tileMode = "calibrate"

--- TermGrid.tileSize
--- Variable
--- Preferred tile shape/size in points, used to guide the grid layout (tiles then
--- fill the screen). Fallback when no calibrated size is stored, and used when
--- tileMode == "fixed".
obj.tileSize = { w = 680, h = 460 }

--- TermGrid.minTileWidth
--- Variable
--- Readability floor in points. TermGrid keeps every window on the current screen,
--- shrinking tiles to fit; it only spills onto another display once tiles would
--- have to get narrower than this. Default 420.
obj.minTileWidth = 420

--- TermGrid.heroActive
--- Variable
--- When true, actively-working (and recently-active) sessions get a larger tile —
--- proportionally bigger, not a giant band — so the emphasis stays balanced and
--- every tile keeps a reasonable, terminal-like shape. Windows are laid out as a
--- weighted treemap that always fills the screen. Default false.
obj.heroActive = false

--- TermGrid.heroWeight
--- Variable
--- How much bigger, in area, a fully-active tile is than an idle one. 2.0 means an
--- active window gets roughly twice the area of an idle window (with many windows
--- open that's a gentle nudge; with few it's more pronounced). Default 2.0.
obj.heroWeight = 2.0

--- TermGrid.recencyWindow
--- Variable
--- Seconds over which a just-finished session's emphasis fades from full back to
--- normal. Until it fades (or another session takes over), its tile stays big — so
--- a session that stops working shrinks gradually, not the instant it goes idle,
--- and a hand-off between two sessions looks balanced. Default 120.
obj.recencyWindow = 120

--- TermGrid.autoArrange
--- Variable
--- When true, TermGrid watches for session activity changes — a session starts or
--- finishes working, or a window opens/closes — and re-arranges automatically and
--- quietly (without stealing focus or showing an alert). The Braille spinner
--- animation does not count as a change, so continuous work doesn't thrash the
--- layout. Growing is real-time — a session starting to work, or a window opening
--- or closing, re-arranges at once. A window that goes idle keeps its size until
--- another session takes the spotlight, so a just-finished session's big tile
--- shrinks organically (when something else needs the space), not the instant it
--- goes idle. Default false.
obj.autoArrange = false

--- TermGrid.autoInterval
--- Variable
--- How often, in seconds, auto-arrange checks for activity changes. Default 1.5.
obj.autoInterval = 1.5

--- TermGrid.spill
--- Variable
--- When true (default), windows spill onto your other displays once they would
--- shrink below `minTileWidth` on one screen. When false, everything stays on the
--- active screen (shrinking to fit).
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

-- Pick the grid (cols×rows) whose cells fill the WxH screen at a shape closest to
-- the preferred aspect (defW:defH), so tiles fill every pixel with no letterboxing
-- while still looking like terminals. Returns the chosen cell size (tiles fill the
-- cell). `scale` (capped at 1) is used only to compare candidate grids.
local function fitGrid(n, W, H, gap, defW, defH)
  local best
  for cols = 1, n do
    local rows = math.ceil(n / cols)
    local cellW = (W - gap * (cols + 1)) / cols
    local cellH = (H - gap * (rows + 1)) / rows
    if cellW > 0 and cellH > 0 then
      local scale = math.min(cellW / defW, cellH / defH, 1)
      local cand = { cols = cols, rows = rows, cellW = cellW, cellH = cellH, scale = scale }
      if not best
         or cand.scale > best.scale
         or (cand.scale == best.scale and cols * rows < best.cols * best.rows)
         or (cand.scale == best.scale and cols * rows == best.cols * best.rows and cols > best.cols) then
        best = cand
      end
    end
  end
  return best or { cols = 1, rows = n, cellW = W - 2 * gap, cellH = H - 2 * gap, scale = 0.1 }
end

-- How many windows fit on `screen` while each tile stays at least `minW` wide.
-- Exceeding this is what triggers a spill onto another display.
local function capacityFor(screen, gap, defW, defH, minW)
  local f = screen:frame()
  local cap = 1
  for k = 1, 200 do
    if fitGrid(k, f.w, f.h, gap, defW, defH).cellW >= minW then cap = k else break end
  end
  return cap
end

-- Squarified treemap: lay `items` (each {win=, weight=}) into `rect` so a tile's
-- AREA is proportional to its weight, while keeping tiles close to square (never
-- thin strips) and filling the rect exactly.
local function squarify(items, rect, gap)
  local n = #items
  if n == 0 then return end

  local total = 0
  for _, it in ipairs(items) do total = total + it.weight end

  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local areaScale = (w * h) / total  -- px^2 per unit weight

  -- Worst (largest) aspect ratio in a strip of area `rowArea` laid along `side`.
  local function worst(rowArea, maxA, minA, side)
    local s2, ra2 = side * side, rowArea * rowArea
    return math.max((s2 * maxA) / ra2, ra2 / (s2 * minA))
  end

  local i = 1
  while i <= n do
    local side = math.min(w, h)          -- lay the strip along the shorter side
    local rowArea = items[i].weight * areaScale
    local maxA, minA, count = rowArea, rowArea, 1
    local j = i + 1
    while j <= n do
      local a = items[j].weight * areaScale
      local nMax, nMin = math.max(maxA, a), math.min(minA, a)
      if worst(rowArea + a, nMax, nMin, side) <= worst(rowArea, maxA, minA, side) then
        rowArea, maxA, minA, count = rowArea + a, nMax, nMin, count + 1
        j = j + 1
      else
        break
      end
    end

    local thickness = rowArea / side     -- extent into the longer side
    if w <= h then                       -- horizontal strip across the width
      local cx = x
      for k = i, i + count - 1 do
        local cw = (items[k].weight * areaScale) / thickness
        items[k].win:setFrame({ x = cx + gap / 2, y = y + gap / 2, w = cw - gap, h = thickness - gap }, 0)
        cx = cx + cw
      end
      y, h = y + thickness, h - thickness
    else                                 -- vertical strip down the height
      local cy = y
      for k = i, i + count - 1 do
        local ch = (items[k].weight * areaScale) / thickness
        items[k].win:setFrame({ x = x + gap / 2, y = cy + gap / 2, w = thickness - gap, h = ch - gap }, 0)
        cy = cy + ch
      end
      x, w = x + thickness, w - thickness
    end

    i = i + count
  end
end

-- Lay `wins` out on one `screen` as a weighted treemap (bigger weight → bigger
-- tile). `weightOf(win)` returns each window's weight.
local function layoutOnScreen(screen, wins, gap, weightOf)
  local items = {}
  for _, w in ipairs(wins) do
    items[#items + 1] = { win = w, weight = math.max(0.01, weightOf(w)) }
  end
  squarify(items, screen:frame(), gap)
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

-- A window's layout weight (tile area is proportional to it). A working session
-- gets `heroWeight`; a just-finished one keeps most of that and fades linearly to
-- 1 over `recencyWindow` seconds; everything else is 1.
function obj:_weight(win, now)
  if not self.heroActive then return 1 end
  if windowRank(win) == 0 then return self.heroWeight end  -- currently working
  local la = (self._lastActiveAt or {})[win:id()]
  if la and self.recencyWindow > 0 then
    local age = now - la
    if age < self.recencyWindow then
      return 1 + (self.heroWeight - 1) * (1 - age / self.recencyWindow)
    end
  end
  return 1
end

-- Snapshot the current activity: a signature string (each window's id + rank),
-- the set of active (working) window ids, and the set of all window ids. The
-- signature changes when a session starts/stops working or a window opens/closes,
-- but NOT while a session merely keeps working (the Braille spinner animates the
-- title, yet the rank stays 0), so continuous work doesn't thrash the layout.
function obj:_activityState()
  local app = self:_targetApp()
  local parts, active, ids = {}, {}, {}
  if app then
    for _, w in ipairs(app:allWindows()) do
      if w:isStandard() and not w:isMinimized() then
        local id, r = w:id(), windowRank(w)
        ids[id] = true
        if r == 0 then active[id] = true end
        parts[#parts + 1] = id .. ":" .. r
      end
    end
  end
  table.sort(parts)
  return table.concat(parts, ","), active, ids
end

-- Re-arrange now and remember the applied state.
function obj:_applyAuto()
  self._appliedSig, self._appliedActive, self._appliedIds = self:_activityState()
  self:arrange(true)  -- quiet: no focus steal, no alert
end

-- One poll. Re-arrange only on an "upsizing" change — a session started working,
-- or a window opened/closed. A session merely going idle does NOT re-arrange, so
-- its (possibly big) tile keeps its size until the next upsize needs the space;
-- the shrink then happens organically, as a side effect of something else growing.
function obj:_autoTick()
  local sig, active, ids = self:_activityState()

  -- Record recency for currently-working windows every tick, so a window's tile
  -- can keep some of its size for a while after it goes idle.
  local now = os.time()
  self._lastActiveAt = self._lastActiveAt or {}
  for id in pairs(active) do self._lastActiveAt[id] = now end

  if sig == self._appliedSig then return end  -- nothing changed since last applied

  local aApplied, iApplied = self._appliedActive or {}, self._appliedIds or {}
  local upsize = false
  for id in pairs(active) do if not aApplied[id] then upsize = true break end end   -- a session started working
  if not upsize then
    for id in pairs(ids) do if not iApplied[id] then upsize = true break end end     -- a window opened
  end
  if not upsize then
    for id in pairs(iApplied) do if not ids[id] then upsize = true break end end     -- a window closed
  end

  if upsize then self:_applyAuto() end
  -- else: a session just went idle — leave the layout alone. It re-flows (and this
  -- window shrinks) the next time something upsizes and needs the room.
end

function obj:_startAuto()
  if self._autoTimer then return end
  self._appliedSig, self._appliedActive, self._appliedIds = nil, {}, {}
  self._autoTimer = hs.timer.new(self.autoInterval, function() self:_autoTick() end)
  self._autoTimer:start()
end

function obj:_stopAuto()
  if self._autoTimer then self._autoTimer:stop(); self._autoTimer = nil end
end

local function alert(self, msg)
  if self.showAlerts then hs.alert.show(msg) end
end

--------------------------------------------------------------------------------
-- Public methods
--------------------------------------------------------------------------------

--- TermGrid:arrange()
--- Method
--- Arranges the target terminal's windows into a screen-filling weighted grid (active and recently-active sessions get proportionally larger tiles), spilling onto other displays as needed.
---
--- Parameters:
---  * quiet - Optional boolean; when true, arranges without stealing focus or showing an alert (used by auto-arrange)
---
--- Returns:
---  * The TermGrid object
function obj:arrange(quiet)
  if not hs.accessibilityState() then
    if not quiet then
      hs.alert.show("Grant Hammerspoon Accessibility access:\nSystem Settings → Privacy & Security → Accessibility")
      hs.accessibilityState(true)  -- prompts the user
    end
    return self
  end

  local app = self:_targetApp()
  if not app then
    if not quiet then alert(self, "TermGrid: no terminal app found") end
    return self
  end

  local wins = hs.fnutils.filter(app:allWindows(), function(w)
    return w:isStandard() and not w:isMinimized()
  end)
  -- Stable order (by id) so windows keep their positions as activity changes —
  -- only their sizes shift. Emphasis comes from weight, not from re-ordering.
  table.sort(wins, function(a, b) return a:id() < b:id() end)

  local n = #wins
  if n == 0 then
    if not quiet then alert(self, "TermGrid: no " .. app:name() .. " windows") end
    return self
  end

  -- Record recency for currently-working windows (feeds tile weights).
  local now = os.time()
  self._lastActiveAt = self._lastActiveAt or {}
  for _, w in ipairs(wins) do
    if windowRank(w) == 0 then self._lastActiveAt[w:id()] = now end
  end

  local defW, defH = self:_tileSize(app)
  local gap, minW = self.gap, self.minTileWidth

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
  for i, s in ipairs(screens) do caps[i] = capacityFor(s, gap, defW, defH, minW) end

  local buckets = {}
  local si, room = 1, caps[1]
  for _, w in ipairs(wins) do
    while room <= 0 and si < #screens do si = si + 1; room = caps[si] end
    buckets[si] = buckets[si] or {}
    table.insert(buckets[si], w)
    room = room - 1
  end

  local weightOf = function(w) return self:_weight(w, now) end
  local used = 0
  for i = 1, #screens do
    if buckets[i] and #buckets[i] > 0 then
      layoutOnScreen(screens[i], buckets[i], gap, weightOf)
      used = used + 1
    end
  end

  if not quiet then
    app:activate()  -- bring the terminal forward after arranging
    alert(self, string.format("TermGrid: %d %s window%s · %d screen%s",
      n, app:name(), n > 1 and "s" or "", used, used > 1 and "s" or ""))
  end
  return self
end

--- TermGrid:calibrate()
--- Method
--- Remembers the focused window's current size as the grid tile size for its application.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TermGrid object
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

--- TermGrid:toggleAuto()
--- Method
--- Turns automatic re-arranging (on session activity changes) on or off.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TermGrid object
function obj:toggleAuto()
  self.autoArrange = not self.autoArrange
  if self.autoArrange then self:_startAuto() else self:_stopAuto() end
  hs.alert.show("TermGrid auto-arrange: " .. (self.autoArrange and "ON" or "OFF"))
  return self
end

--- TermGrid:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for TermGrid.
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---    * arrange - Arrange the terminal's windows into a grid
---    * calibrate - Remember the focused window's current size as the tile size
---    * toggleAuto - Turn automatic re-arranging on or off
---
--- Returns:
---  * The TermGrid object
function obj:bindHotkeys(mapping)
  local spec = {
    arrange    = function() self:arrange() end,
    calibrate  = function() self:calibrate() end,
    toggleAuto = function() self:toggleAuto() end,
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

--- TermGrid:start()
--- Method
--- Starts TermGrid, adding the menu-bar button (if TermGrid.menubar is true). The button opens a small menu (Arrange / Set tile size); for instant arranging, use the hotkey.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TermGrid object
function obj:start()
  if self.menubar and not self._menu then
    self._menu = hs.menubar.new()
    if self._menu then
      self._menu:setTitle("▦")
      self._menu:setTooltip("TermGrid — arrange terminal windows")
      self._menu:setMenu(function()
        return {
          { title = "Arrange terminal windows", fn = function() self:arrange() end },
          { title = "Set tile size from focused window", fn = function() self:calibrate() end },
          { title = (self.autoArrange and "✓ " or "") .. "Auto-arrange on activity", fn = function() self:toggleAuto() end },
          { title = "-" },
          { title = "TermGrid " .. self.version, disabled = true },
        }
      end)
    end
  end
  if self.autoArrange then self:_startAuto() end
  return self
end

--- TermGrid:stop()
--- Method
--- Stops TermGrid, removing the menu-bar button.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TermGrid object
function obj:stop()
  self:_stopAuto()
  if self._menu then self._menu:delete(); self._menu = nil end
  return self
end

return obj
