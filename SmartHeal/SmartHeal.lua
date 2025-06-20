-- SmartHeal Addon
-- A dynamic, configurable healer helper for TurtleWoW Classic (1.12.1)

-- Initialize namespace and saved variables
SmartHeal = SmartHeal or {}
SmartHealDB = SmartHealDB or {
  spell         = "Flash Heal(Rank 2)",  -- default heal
  useRenew      = true,                  -- toggle Renew(Rank 1)
  threshold     = 0.85,                  -- heal units below 85% HP
  renewCooldown = 3,                     -- seconds between Renews per unit
}

-- Pull settings into runtime fields
SmartHeal.spell         = SmartHealDB.spell
SmartHeal.useRenew      = SmartHealDB.useRenew
SmartHeal.threshold     = SmartHealDB.threshold
SmartHeal.renewCooldown = SmartHealDB.renewCooldown

-- Track last Renew times per unit
local lastRenew = {}

-- Utility: trim whitespace
local function trim(s)
  return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

----------------------------------------
-- UI Creation
----------------------------------------
function SmartHeal:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  local f = CreateFrame("Frame", "SmartHealFrame", UIParent)
  f:SetBackdrop{
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(260)
  f:SetHeight(140)
  f:SetPoint("CENTER")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -8)
  title:SetText("SmartHeal Settings")

  -- Close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetWidth(24); close:SetHeight(24)
  close:SetPoint("TOPRIGHT",-4,-4)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Renew toggle
  local cb = CreateFrame("CheckButton", "SmartHealRenewToggle", f, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 10, -40)
  cb:SetChecked(self.useRenew)
  cb:SetScript("OnClick", function(btn)
    SmartHeal.useRenew = btn:GetChecked()
  end)
  local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  lbl:SetText("Use Renew (Rank 1)")

  -- HP threshold slider
  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", f, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", 10, -70)
  slider:SetMinMaxValues(0,1)
  slider:SetValueStep(0.05)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(self.threshold)
  slider:SetScript("OnValueChanged", function(_, val)
    SmartHeal.threshold = val
  end)
  _G[slider:GetName().."Low"]:SetText("0%")
  _G[slider:GetName().."High"]:SetText("100%")
  _G[slider:GetName().."Text"]:SetText("Heal Below")

  -- Spell input box
  local eb = CreateFrame("EditBox", "SmartHealSpellInput", f, "InputBoxTemplate")
  eb:SetWidth(180); eb:SetHeight(20)
  eb:SetPoint("TOPLEFT", 120, -40)
  eb:SetText(self.spell)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed", function(box)
    local txt = trim(box:GetText())
    if txt ~= "" then SmartHeal.spell = txt end
    box:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

  self.frame = f
end

----------------------------------------
-- Core Logic
----------------------------------------

-- Check for Renew buff on unit
function SmartHeal:HasRenew(unit)
  for i = 1, 16 do
    local buffName = UnitBuff(unit, i)
    if buffName and string.match(buffName, "^Renew") then
      return true
    end
  end
  return false
end

-- Heal the lowest HP friendly unit
function SmartHeal:HealLowest()
  -- gather units: player + dynamic party/raid
  local units = { "player" }
  local raidCount  = (GetNumRaidMembers  and GetNumRaidMembers() ) or 0
  local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0

  if raidCount > 0 then
    for i = 1, raidCount do table.insert(units, "raid"..i) end
  elseif partyCount > 0 then
    for i = 1, partyCount do table.insert(units, "party"..i) end
  end

  -- find lowest HP
  local lowest, lowestHP = "player", UnitHealth("player")/UnitHealthMax("player")
  for _, unit in ipairs(units) do
    if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDead(unit) then
      local hp = UnitHealth(unit)/UnitHealthMax(unit)
      if hp < lowestHP then
        lowest, lowestHP = unit, hp
      end
    end
  end

  -- cast if below threshold
  if lowestHP < self.threshold then
    local oldTarget = UnitName("target")
    TargetUnit(lowest)

    local now = GetTime()
    if self.useRenew
       and not self:HasRenew(lowest)
       and (not lastRenew[lowest] or now - lastRenew[lowest] >= SmartHeal.renewCooldown)
    then
      if IsUsableSpell("Renew") then
        CastSpellByName("Renew(Rank 1)")
        lastRenew[lowest] = now
      else
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast Renew")
      end
    else
      if IsUsableSpell(self.spell) then
        CastSpellByName(self.spell)
      else
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast "..self.spell)
      end
    end

    if oldTarget then TargetByName(oldTarget) end
  end
end

----------------------------------------
-- Slash Command
----------------------------------------
SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = trim(msg or "")
  if msg == "ui" then
    SmartHeal:CreateUI()
  elseif msg ~= "" then
    SmartHeal.spell = msg
  end

  -- persist settings
  SmartHealDB.spell         = SmartHeal.spell
  SmartHealDB.useRenew      = SmartHeal.useRenew
  SmartHealDB.threshold     = SmartHeal.threshold
  SmartHealDB.renewCooldown = SmartHeal.renewCooldown

  SmartHeal:HealLowest()
end
