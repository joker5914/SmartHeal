-- SmartHeal Addon
-- A dynamic, configurable healer helper for TurtleWoW Classic (1.12.1)

local ADDON_NAME = ...
SmartHeal = SmartHeal or {}

local eventFrame = CreateFrame("Frame")
local lastRenew = {}

local defaults = {
  spell = "Flash Heal(Rank 2)",
  useRenew = true,
  threshold = 0.85,
  renewCooldown = 3,
}

local function trim(text)
  if not text then
    return ""
  end
  return (text:gsub("^%s*(.-)%s*$", "%1"))
end

local function roundToPercent(value)
  return math.floor(((value or 0) * 100) + 0.5)
end

local function applyDefaults()
  SmartHealDB = SmartHealDB or {}
  for key, value in pairs(defaults) do
    if SmartHealDB[key] == nil then
      SmartHealDB[key] = value
    end
    SmartHeal[key] = SmartHealDB[key]
  end
end

local function saveSetting(key, value)
  SmartHeal[key] = value
  SmartHealDB[key] = value
end

local function unitIsHealable(unit)
  if not UnitExists(unit) then
    return false
  end
  if UnitIsFriend("player", unit) ~= 1 then
    return false
  end
  if UnitIsDead(unit) then
    return false
  end
  if UnitIsGhost and UnitIsGhost(unit) then
    return false
  end
  if UnitIsConnected and not UnitIsConnected(unit) then
    return false
  end
  return true
end

local function canCastRenewOn(unit)
  if not SmartHeal.useRenew then
    return false
  end

  if SmartHeal.renewCooldown and SmartHeal.renewCooldown > 0 then
    local previous = lastRenew[unit]
    if previous and (GetTime() - previous) < SmartHeal.renewCooldown then
      return false
    end
  end

  for i = 1, 16 do
    local buff = UnitBuff(unit, i)
    if not buff then
      break
    end
    if type(buff) == "string" and string.find(buff, "Renew") then
      return false
    end
  end

  return true
end

local function setSliderText(slider, value)
  local label = _G[slider:GetName() .. "Text"]
  if label then
    label:SetText(string.format("Threshold (%d%%)", roundToPercent(value)))
  end
end

local function createCheckbox(parent, name, labelText, onClick)
  local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  checkbox:SetScript("OnClick", onClick)
  local text = _G[name .. "Text"]
  if text then
    text:SetText(labelText)
  end
  return checkbox
end

local function createInputBox(parent, name, width)
  local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  box:SetSize(width, 20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(64)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  return box
end

function SmartHeal:RefreshUI()
  if not self.frame then
    return
  end

  if self.frame.spellBox then
    self.frame.spellBox:SetText(self.spell or defaults.spell)
  end
  if self.frame.renewCheckbox then
    self.frame.renewCheckbox:SetChecked(self.useRenew)
  end
  if self.frame.cooldownBox then
    self.frame.cooldownBox:SetText(tostring(self.renewCooldown or defaults.renewCooldown))
  end
  if self.frame.thresholdSlider then
    self.frame.thresholdSlider:SetValue(self.threshold or defaults.threshold)
    setSliderText(self.frame.thresholdSlider, self.threshold or defaults.threshold)
  end
end

function SmartHeal:CreateUI()
  if self.frame then
    self:RefreshUI()
    self.frame:Show()
    return
  end

  local frame = CreateFrame("Frame", "SmartHealFrame", UIParent)
  frame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 16,
    insets   = { 4, 4, 4, 4 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.9)
  frame:SetSize(320, 210)
  frame:SetPoint("CENTER")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("SmartHeal Settings")

  local spellLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  spellLabel:SetPoint("TOPLEFT", 16, -44)
  spellLabel:SetText("Heal Spell:")

  local spellBox = createInputBox(frame, "SmartHealSpellInput", 200)
  spellBox:SetPoint("LEFT", spellLabel, "RIGHT", 8, 0)
  spellBox:SetScript("OnEditFocusLost", function(box)
    local value = trim(box:GetText())
    if value ~= "" then
      saveSetting("spell", value)
    else
      box:SetText(SmartHeal.spell)
    end
  end)
  frame.spellBox = spellBox

  local renewCheckbox = createCheckbox(frame, "SmartHealRenewCheckbox", "Cast Renew when missing", function(box)
    saveSetting("useRenew", box:GetChecked() and true or false)
  end)
  renewCheckbox:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -16)
  frame.renewCheckbox = renewCheckbox

  local cooldownLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cooldownLabel:SetPoint("TOPLEFT", renewCheckbox, "BOTTOMLEFT", 24, -12)
  cooldownLabel:SetText("Renew Cooldown (s):")

  local cooldownBox = createInputBox(frame, "SmartHealCooldownInput", 50)
  cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 8, 0)
  cooldownBox:SetScript("OnEditFocusLost", function(box)
    local value = tonumber(trim(box:GetText()))
    if not value then
      value = SmartHeal.renewCooldown or defaults.renewCooldown
    end
    saveSetting("renewCooldown", math.max(0, value))
    box:SetText(tostring(SmartHeal.renewCooldown))
  end)
  frame.cooldownBox = cooldownBox

  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", frame, "OptionsSliderTemplate")
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", cooldownLabel, "BOTTOMLEFT", -24, -36)
  slider:SetWidth(240)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.05)
  slider:EnableMouseWheel(true)
  slider:SetScript("OnValueChanged", function(selfSlider, value)
    value = math.floor((value * 100) + 0.5) / 100
    saveSetting("threshold", value)
    setSliderText(selfSlider, value)
  end)
  slider:SetScript("OnMouseWheel", function(selfSlider, delta)
    local step = selfSlider:GetValueStep() or 0.05
    local minValue, maxValue = selfSlider:GetMinMaxValues()
    local value = selfSlider:GetValue() + (delta > 0 and step or -step)
    value = math.min(math.max(value, minValue), maxValue)
    selfSlider:SetValue(value)
  end)
  frame.thresholdSlider = slider

  _G[slider:GetName() .. "Low"]:SetText("0%")
  _G[slider:GetName() .. "High"]:SetText("100%")

  frame:SetScript("OnHide", function()
    SmartHeal:RefreshUI()
  end)

  self.frame = frame
  self:RefreshUI()
  frame:Show()
end

local function collectUnits()
  local units = { "player" }
  local raidCount = (GetNumRaidMembers and GetNumRaidMembers()) or 0
  local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0

  if raidCount > 0 then
    for i = 1, raidCount do
      table.insert(units, "raid" .. i)
    end
  elseif partyCount > 0 then
    for i = 1, partyCount do
      table.insert(units, "party" .. i)
    end
  end

  return units
end

local function findLowestUnit()
  local lowestUnit
  local lowestPercent = math.huge

  for _, unit in ipairs(collectUnits()) do
    if unitIsHealable(unit) then
      local maxHealth = UnitHealthMax(unit)
      if maxHealth and maxHealth > 0 then
        local percent = UnitHealth(unit) / maxHealth
        if percent < lowestPercent then
          lowestPercent = percent
          lowestUnit = unit
        end
      end
    end
  end

  return lowestUnit, lowestPercent ~= math.huge and lowestPercent or nil
end

local function castRenew(unit)
  if not canCastRenewOn(unit) then
    return false
  end

  if IsUsableSpell and not IsUsableSpell("Renew") then
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Renew is not usable.")
    return false
  end

  CastSpellByName("Renew(Rank 1)")
  lastRenew[unit] = GetTime()
  return true
end

local function castHeal(spell)
  if spell == nil or spell == "" then
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: No heal spell configured.")
    return false
  end

  if IsUsableSpell and not IsUsableSpell(spell) then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("SmartHeal: %s is not usable.", spell))
    return false
  end

  CastSpellByName(spell)
  return true
end

function SmartHeal:HealLowest()
  local lowestUnit, lowestPercent = findLowestUnit()
  local threshold = self.threshold or defaults.threshold

  if not lowestUnit or not lowestPercent then
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: No healable units found.")
    return
  end

  if lowestPercent >= threshold then
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
      "SmartHeal: Lowest unit is above threshold (%d%% ≥ %d%%).",
      roundToPercent(lowestPercent),
      roundToPercent(threshold)
    ))
    return
  end

  local hadTarget = UnitExists("target")
  TargetUnit(lowestUnit)

  local casted = castRenew(lowestUnit)
  if not casted then
    castHeal(self.spell)
  end

  if hadTarget then
    TargetLastTarget()
  else
    ClearTarget()
  end
end

local function handleSlash(msg)
  msg = trim(msg or "")
  if msg == "" then
    SmartHeal:HealLowest()
    return
  end

  local command, rest = msg:match("^(%S+)%s*(.*)$")
  command = command and command:lower() or ""
  rest = trim(rest)

  if command == "ui" or command == "config" then
    SmartHeal:CreateUI()
    return
  end

  if command == "cast" then
    SmartHeal:HealLowest()
    return
  end

  if command == "spell" and rest ~= "" then
    saveSetting("spell", rest)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("SmartHeal: Heal spell set to %s.", rest))
    SmartHeal:RefreshUI()
    return
  end

  if command == "threshold" and rest ~= "" then
    local value = tonumber(rest)
    if value then
      value = math.min(math.max(value / 100, 0), 1)
      saveSetting("threshold", value)
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "SmartHeal: Threshold set to %d%%.",
        roundToPercent(value)
      ))
      SmartHeal:RefreshUI()
    else
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Threshold expects a number (e.g. 75).");
    end
    return
  end

  if command == "renew" and rest ~= "" then
    rest = rest:lower()
    if rest == "on" or rest == "off" then
      saveSetting("useRenew", rest == "on")
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "SmartHeal: Renew %s.",
        rest == "on" and "enabled" or "disabled"
      ))
      SmartHeal:RefreshUI()
    else
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Use 'renew on' or 'renew off'.")
    end
    return
  end

  if command == "cooldown" and rest ~= "" then
    local value = tonumber(rest)
    if value then
      saveSetting("renewCooldown", math.max(0, value))
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "SmartHeal: Renew cooldown set to %.1f seconds.",
        SmartHeal.renewCooldown
      ))
      SmartHeal:RefreshUI()
    else
      DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cooldown expects a number (e.g. 3).");
    end
    return
  end

  saveSetting("spell", msg)
  DEFAULT_CHAT_FRAME:AddMessage(string.format("SmartHeal: Heal spell set to %s.", msg))
  SmartHeal:RefreshUI()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
  if event ~= "ADDON_LOADED" or addonName ~= ADDON_NAME then
    return
  end

  applyDefaults()
  SmartHeal:RefreshUI()

  SLASH_SMARTHEAL1 = "/smartheal"
  SlashCmdList.SMARTHEAL = handleSlash

  DEFAULT_CHAT_FRAME:AddMessage("SmartHeal loaded. Type /smartheal ui for options.")
end)
