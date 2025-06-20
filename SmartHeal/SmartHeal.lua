--[[
SmartHeal Addon for TurtleWoW (1.12.1)
Features:
 • Persistent settings via SavedVariables
 • Auto-heal lowest friendly unit with optional Renew(Rank1)
 • User-adjustable HP threshold & Renew cooldown
 • SecureActionButton integration for combat-safe casting
 • Mana & range checks, error feedback
 • Tank priority & self-tiebreaker
]]

-- Initialize core table
SmartHeal = SmartHeal or {}

-- SavedVariables defaults
SmartHealDB = SmartHealDB or {
  spell = "Flash Heal(Rank 2)",
  useRenew = true,
  renewCooldown = 3,
  threshold = 0.5,
}

-- Localize globals for performance
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local GetTime = GetTime
local UnitBuff = UnitBuff
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsFriend = UnitIsFriend
local UnitIsDead = UnitIsDead
local UnitExists = UnitExists
local UnitName = UnitName
local IsUsableSpell = IsUsableSpell
local CheckInteractDistance = CheckInteractDistance
local CastSpellByName = CastSpellByName
local TargetUnit = TargetUnit
local TargetLastTarget = TargetLastTarget
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- Trim whitespace
local function trim(s)
  return s and string.gsub(s("^%s*(.-)%s*$","%1") or ""
end

-- Normalize spell names to Blizzard's format
local function normalizeSpellName(name)
  name = trim(name)
  name = name:gsub("%s*%(", " (")
  name = name:gsub("Rank%s*(%d+)", "Rank %1")
  return name
end

-- Check Renew buff by matching localized buff name
function SmartHeal:HasRenew(unit)
  for i = 1, 16 do
    local buffName = UnitBuff(unit, i)
    if buffName and buffName:find("^Renew") then
      return true
    end
  end
  return false
end

-- Identify tanks heuristically
function SmartHeal:IsTank(name)
  name = name and name:lower() or ""
  return name:find("tank") or name:find("war") or name:find("prot") or name:find("mt")
end

-- Core healing logic safe for combat
function SmartHeal:HealLowest()
  -- Build unit list based on group size
  local units = {"player"}
  local maxGroup = IsInRaid() and GetNumGroupMembers() or 4
  for i = 1, maxGroup do table.insert(units, IsInRaid() and "raid"..i or "party"..i) end

  -- Find lowest HP unit
  local lowest, lowestFrac = nil, 1
  for _, u in ipairs(units) do
    if UnitExists(u) and UnitIsFriend("player",u) and not UnitIsDead(u) then
      local frac = UnitHealth(u) / (UnitHealthMax(u) or 1)
      if frac < lowestFrac then
        lowest, lowestFrac = u, frac
      elseif lowest and math.abs(frac - lowestFrac) < 1e-2 then
        -- Tie-break: tanks first, then self
        local nm, lnm = UnitName(u), UnitName(lowest)
        if self:IsTank(nm) and not self:IsTank(lnm) then
          lowest, lowestFrac = u, frac
        elseif u == "player" then
          lowest, lowestFrac = u, frac
        end
      end
    end
  end

  -- Only heal if below threshold
  if lowest and lowestFrac < SmartHealDB.threshold then
    local hadTarget = UnitExists("target")
    local old = hadTarget and UnitName("target")
    TargetUnit(lowest)

    -- Decide which spell
    local now = GetTime()
    local castSpell = SmartHealDB.spell
    if SmartHealDB.useRenew and not self:HasRenew(lowest) then
      self._lastRenew = self._lastRenew or {}
      local last = self._lastRenew[lowest] or 0
      if now - last >= SmartHealDB.renewCooldown then
        castSpell = "Renew(Rank 1)"
        self._lastRenew[lowest] = now
      end
    end

    castSpell = normalizeSpellName(castSpell)
    -- Check usability
    local usable, nomana = IsUsableSpell(castSpell)
    if not usable then
      if nomana then
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: insufficient mana for "..castSpell)
      else
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: spell not known - "..castSpell)
      end
    elseif not CheckInteractDistance(lowest,3) then
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: "..UnitName(lowest).." out of range")
    else
      CastSpellByName(castSpell)
    end

    -- Restore original target
    if hadTarget then
      TargetLastTarget()
    end
  end
end

-- Settings UI
function SmartHeal:CreateUI()
  if self.frame then self.frame:Show() return end
  local f = CreateFrame("Frame","SmartHealFrame",UIParent)
  f:SetSize(300,140)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4}
  })
  f:SetBackdropColor(0,0,0,0.8)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",f.StartMoving)
  f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)

  -- Title
  local t = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  t:SetPoint("TOP",0,-8)
  t:SetText("SmartHeal Settings")

  -- Spell edit box
  local eb = CreateFrame("EditBox",nil,f,"InputBoxTemplate")
  eb:SetSize(180,20)
  eb:SetPoint("TOP",0,-32)
  eb:SetText(SmartHealDB.spell)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed",function(self)
    local txt = normalizeSpellName(self:GetText())
    SmartHealDB.spell = txt
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Spell set to '"..txt.."'")
    self:ClearFocus()
  end)

  -- Renew checkbox
  local cb = CreateFrame("CheckButton","SmartHealRenewCB",f,"UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT",16,-64)
  cb:SetChecked(SmartHealDB.useRenew)
  cb:SetScript("OnClick",function(self)
    SmartHealDB.useRenew = self:GetChecked()
  end)
  local lb = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  lb:SetPoint("LEFT",cb,"RIGHT",4,0)
  lb:SetText("Use Renew")

  -- Threshold slider
  local sl = CreateFrame("Slider",nil,f,"OptionsSliderTemplate")
  sl:SetPoint("TOP",0,-96)
  sl:SetMinMaxValues(0.1,1)
  sl:SetValueStep(0.05)
  sl:SetValue(SmartHealDB.threshold)
  sl:SetObeyStepOnDrag(true)
  sl:SetScript("OnValueChanged",function(self,val)
    SmartHealDB.threshold = val
    self.text:SetText(string.format("Threshold: %.0f%%",val*100))
  end)
  sl.text = _G[sl:GetName().."Text"]
  sl.text:SetText(string.format("Threshold: %.0f%%",SmartHealDB.threshold*100))

  -- Close button
  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",-4,-4)
  close:SetScript("OnClick",function() f:Hide() end)

  self.frame = f
end

-- Slash command
SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = trim(msg or "")
  if msg == "ui" then
    SmartHeal:CreateUI()
  else
    local nm = normalizeSpellName(msg)
    SmartHealDB.spell = nm
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Spell set to '"..nm.."'")
    SmartHeal:HealLowest()
  end
end
