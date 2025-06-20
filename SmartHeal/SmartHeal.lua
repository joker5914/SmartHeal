-- SmartHeal Addon
-- A dynamic, configurable healer helper for TurtleWoW Classic (1.12.1)

SmartHeal = SmartHeal or {}
SmartHealDB = SmartHealDB or {
  spell         = "Flash Heal(Rank 2)",
  useRenew      = true,
  threshold     = 0.85,
  renewCooldown = 3,
}

SmartHeal.spell         = SmartHealDB.spell
SmartHeal.useRenew      = SmartHealDB.useRenew
SmartHeal.threshold     = SmartHealDB.threshold
SmartHeal.renewCooldown = SmartHealDB.renewCooldown

local lastRenew = {}
local function trim(s) return string.gsub(s, "^%s*(.-)%s*$", "%1") end

----------------------------------------
-- UI Creation
----------------------------------------
----------------------------------------
-- UI Creation (reverted + improved layout)
----------------------------------------
function SmartHeal:CreateUI()
  if self.frame then
    self.frame:Show()
    return
  end

  -- Main window
  local f = CreateFrame("Frame", "SmartHealFrame", UIParent)
  f:SetBackdrop{
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = {4,4,4,4},
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(300)
  f:SetHeight(160)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("SmartHeal Settings")

  -- Close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(24,24)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Row 1: Renew checkbox
  local cb = CreateFrame("CheckButton", "SmartHealRenewToggle", f, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
  cb:SetChecked(self.useRenew)
  cb:SetScript("OnClick", function(btn)
    SmartHeal.useRenew = btn:GetChecked()
  end)
  local cbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cbLabel:SetText("Use Renew (Rank 1)")

  -- Row 2: Spell input label + editbox
  local spellLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  spellLabel:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -16)
  spellLabel:SetText("Heal Spell:")
  local eb = CreateFrame("EditBox", "SmartHealSpellInput", f, "InputBoxTemplate")
  eb:SetSize(180, 20)
  eb:SetPoint("LEFT", spellLabel, "RIGHT", 8, 0)
  eb:SetText(self.spell)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed", function(box)
    local txt = trim(box:GetText())
    if txt ~= "" then SmartHeal.spell = txt end
    box:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

  -- Row 3: Slider label
  local sliderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -24)
  sliderLabel:SetText("Heal Below (HP %):")

  -- Row 4: Slider
  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", f, "OptionsSliderTemplate")
  slider:SetPoint("LEFT", sliderLabel, "RIGHT", 8, -2)
  slider:SetMinMaxValues(0,1)
  slider:SetValueStep(0.05)
  slider:SetValue(self.threshold)
  slider:SetScript("OnValueChanged", function(_, val)
    SmartHeal.threshold = val
  end)
  -- use getglobal for classic
  getglobal(slider:GetName().."Low"):SetText("0%")
  getglobal(slider:GetName().."High"):SetText("100%")
  getglobal(slider:GetName().."Text"):SetText("Percent")

  self.frame = f
end

----------------------------------------
-- Core Logic
----------------------------------------
function SmartHeal:HasRenew(unit)
  for i=1,16 do
    local buffName = UnitBuff(unit,i)
    if buffName and string.match(buffName,"^Renew") then return true end
  end
  return false
end

function SmartHeal:HealLowest()
  local units = {"player"}
  local raidCount  = (GetNumRaidMembers  and GetNumRaidMembers())  or 0
  local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0
  if raidCount>0 then for i=1,raidCount do table.insert(units,"raid"..i) end
  elseif partyCount>0 then for i=1,partyCount do table.insert(units,"party"..i) end end

  local lowest,lowestHP="player",UnitHealth("player")/UnitHealthMax("player")
  for _,u in ipairs(units) do
    if UnitExists(u) and UnitIsFriend("player",u) and not UnitIsDead(u) then
      local hp=UnitHealth(u)/UnitHealthMax(u)
      if hp<lowestHP then lowest,lowestHP=u,hp end
    end
  end

  if lowestHP<self.threshold then
    local old=UnitName("target")
    TargetUnit(lowest)
    local now=GetTime()
    if self.useRenew and not self:HasRenew(lowest)
       and (not lastRenew[lowest] or now-lastRenew[lowest]>=SmartHeal.renewCooldown)
    then
      if IsUsableSpell("Renew") then CastSpellByName("Renew(Rank 1)"); lastRenew[lowest]=now
      else DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast Renew") end
    else
      if IsUsableSpell(self.spell) then CastSpellByName(self.spell)
      else DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast "..self.spell) end
    end
    if old then TargetByName(old) end
  end
end

----------------------------------------
-- Slash Command
----------------------------------------
SLASH_SMARTHEAL1="/smartheal"
SlashCmdList["SMARTHEAL"]=function(msg)
  msg=trim(msg or"")
  if msg=="ui" then SmartHeal:CreateUI()
  elseif msg~="" then SmartHeal.spell=msg end
  SmartHealDB.spell=SmartHeal.spell
  SmartHealDB.useRenew=SmartHeal.useRenew
  SmartHealDB.threshold=SmartHeal.threshold
  SmartHealDB.renewCooldown=SmartHeal.renewCooldown
  SmartHeal:HealLowest()
end
