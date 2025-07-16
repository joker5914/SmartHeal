-- SmartHeal Addon
-- A dynamic, configurable healer helper for TurtleWoW Classic (1.12.1)

-- namespace + saved-vars defaults
SmartHeal = SmartHeal or {}
SmartHealDB = SmartHealDB or {}
SmartHealDB.spell         = SmartHealDB.spell         or "Flash Heal(Rank 2)"
SmartHealDB.useRenew      = (SmartHealDB.useRenew ~= false)  -- default true
SmartHealDB.threshold     = SmartHealDB.threshold     or 0.85
SmartHealDB.renewCooldown = SmartHealDB.renewCooldown or 3

-- runtime settings
SmartHeal.spell         = SmartHealDB.spell
SmartHeal.useRenew      = SmartHealDB.useRenew
SmartHeal.threshold     = SmartHealDB.threshold
SmartHeal.renewCooldown = SmartHealDB.renewCooldown

-- locals
local lastRenew = {}
local function trim(s) return string.gsub(s, "^%s*(.-)%s*$", "%1") end
local strmatch = string.match

-- Healing estimates per rank
SmartHeal.healRanks = {
  ["Flash Heal"] = {
    { rank = 1, amount = 450 },
    { rank = 2, amount = 600 },
    { rank = 3, amount = 725 },
    { rank = 4, amount = 825 },
    { rank = 5, amount = 925 },
    { rank = 6, amount = 1025 },
    { rank = 7, amount = 1100 },
  }
}

function SmartHeal:GetBestHealRank(spellBaseName, hpMissing)
  local ranks = SmartHeal.healRanks[spellBaseName]
  if not ranks then return nil end
  for _, data in ipairs(ranks) do
    if data.amount >= hpMissing then
      return spellBaseName .. "(Rank " .. data.rank .. ")"
    end
  end
  return spellBaseName .. "(Rank " .. ranks[#ranks].rank .. ")"
end

function SmartHeal:GetHighestRankedSpell(spellBaseName)
  local i = 1
  local maxRank = 0
  while true do
    local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    if name == spellBaseName then
      local num = tonumber(string.match(rank or "", "(%d+)")) or 1
      if num > maxRank then maxRank = num end
    end
    i = i + 1
  end
  if maxRank > 0 then
    return spellBaseName .. "(Rank " .. maxRank .. ")"
  else
    return nil
  end
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
  cb:SetScript("OnClick", function()
    SmartHeal.useRenew = this:GetChecked()
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
  eb:SetScript("OnEnterPressed", function()
    local txt = trim(this:GetText())
    if txt ~= "" then
      SmartHeal.spell     = txt
      SmartHealDB.spell   = txt
    end
    this:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)

  local sliderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -50, -16)
  sliderLabel:SetText("Heal Below HP %:")

  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", f, "OptionsSliderTemplate")
  slider:SetWidth(150); slider:SetHeight(20)
  slider:EnableMouse(true)
  slider:SetPoint("LEFT", sliderLabel, "RIGHT", 8, -2)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.05)
  slider:SetValue(self.threshold or SmartHealDB.threshold or 0.85)
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

----------------------------------------
-- Slash Command
----------------------------------------
SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = trim(msg or "")

  if msg == "ui" then
    SmartHeal:CreateUI()
    return
  end

  if msg ~= "" then
    local fullSpell = SmartHeal:GetHighestRankedSpell(msg)
    if fullSpell then
      SmartHeal.spell = fullSpell
      SmartHealDB.spell = fullSpell
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Using " .. fullSpell)
    else
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Spell not found in spellbook.")
    end
  end

  SmartHealDB.useRenew = SmartHeal.useRenew
  SmartHeal:HealLowest()
end
