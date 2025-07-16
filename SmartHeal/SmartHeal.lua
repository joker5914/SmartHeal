-- SmartHeal Addon
-- A dynamic, configurable healer helper for TurtleWoW Classic (1.12.1)

SmartHeal = SmartHeal or {}
local frame = CreateFrame("Frame")

local lastRenew = {}
local function trim(s) return string.gsub(s, "^%s*(.-)%s*$", "%1") end
local strmatch = string.match

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
    insets   = {4,4,4,4},
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(300); f:SetHeight(190)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("SmartHeal Settings")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetWidth(24); close:SetHeight(24)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  local cb = CreateFrame("CheckButton", "SmartHealRenewToggle", f, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -40)
  cb:SetChecked(self.useRenew)
  cb:SetScript("OnClick", function(self)
    SmartHeal.useRenew = self:GetChecked()
    SmartHealDB.useRenew = SmartHeal.useRenew
  end)
  local cbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cbLabel:SetText("Use Renew (Rank 1)")

  local spellLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  spellLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -80)
  spellLabel:SetText("Heal Spell:")

  local eb = CreateFrame("EditBox", "SmartHealSpellInput", f, "InputBoxTemplate")
  eb:SetWidth(180); eb:SetHeight(20)
  eb:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -100)
  eb:SetText(self.spell); eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed", function(self)
    local txt = trim(self:GetText())
    if txt ~= "" then
      SmartHeal.spell     = txt
      SmartHealDB.spell   = txt
    end
    self:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local sliderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -50, -16)
  sliderLabel:SetText("Heal Below HP %:")

  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", f, "OptionsSliderTemplate")
  slider:SetWidth(150); slider:SetHeight(20)
  slider:EnableMouse(true)
  slider:SetPoint("LEFT", sliderLabel, "RIGHT", 8, -2)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.05)
  slider:SetValue(self.threshold or 0.85)
  slider:SetScript("OnValueChanged", function(_, val)
    val = val or slider:GetValue()
    SmartHeal.threshold   = val
    SmartHealDB.threshold = val
    getglobal(slider:GetName().."Text"):SetText("Threshold ("..math.floor(val * 100).."%)")
  end)

  getglobal(slider:GetName().."Low"):SetText("0%")
  getglobal(slider:GetName().."High"):SetText("100%")
  getglobal(slider:GetName().."Text"):SetText("Threshold ("..math.floor(slider:GetValue() * 100).."%)")

  f:SetScript("OnHide", function()
    local sliderVal = SmartHealThresholdSlider:GetValue()
    SmartHeal.threshold     = sliderVal
    SmartHealDB.threshold   = sliderVal
  end)

  self.frame = f
end

function SmartHeal:HasRenew(unit)
  for i = 1, 16 do
    local buff = UnitBuff(unit, i)
    if buff and string.find(buff, "^Renew") then
      return true
    end
  end
  return false
end

function SmartHeal:HealLowest()
  local threshold = self.threshold or 0
  local units = { "player" }
  local raidCount  = (GetNumRaidMembers  and GetNumRaidMembers())  or 0
  local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0
  if raidCount > 0 then
    for i = 1, raidCount do table.insert(units, "raid"..i) end
  elseif partyCount > 0 then
    for i = 1, partyCount do table.insert(units, "party"..i) end
  end

  local lowest, lowestHP = "player", UnitHealth("player")/UnitHealthMax("player")
  for _, u in ipairs(units) do
    if UnitExists(u) and UnitIsFriend("player", u) and not UnitIsDead(u) then
      local hp = UnitHealth(u)/UnitHealthMax(u)
      if hp < lowestHP then
        lowest, lowestHP = u, hp
      end
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.format("SmartHeal Debug → lowestHP: %.2f  threshold: %.2f", lowestHP or 0, threshold))

  if lowestHP < threshold then
    local old = UnitName("target")
    TargetUnit(lowest)

    local now = GetTime()
    if self.useRenew and not self:HasRenew(lowest)
       and (not lastRenew[lowest] or now - lastRenew[lowest] >= self.renewCooldown)
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

    if old then TargetByName(old) end
  end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == "SmartHeal" then
    SmartHealDB = SmartHealDB or {}
    SmartHealDB.spell         = SmartHealDB.spell         or "Flash Heal(Rank 2)"
    SmartHealDB.useRenew      = (SmartHealDB.useRenew ~= false)
    SmartHealDB.threshold     = SmartHealDB.threshold     or 0.85
    SmartHealDB.renewCooldown = SmartHealDB.renewCooldown or 3

    SmartHeal.spell         = SmartHealDB.spell
    SmartHeal.useRenew      = SmartHealDB.useRenew
    SmartHeal.threshold     = SmartHealDB.threshold
    SmartHeal.renewCooldown = SmartHealDB.renewCooldown

    SLASH_SMARTHEAL1 = "/smartheal"
    SlashCmdList["SMARTHEAL"] = function(msg)
      msg = trim(msg or "")
      if msg == "ui" then
        SmartHeal:CreateUI()
        return
      end
      if msg ~= "" then
        SmartHeal.spell = msg
        SmartHealDB.spell = msg
      end
      SmartHealDB.useRenew = SmartHeal.useRenew
      SmartHeal:HealLowest()
    end

    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal loaded.")
  end
end)
