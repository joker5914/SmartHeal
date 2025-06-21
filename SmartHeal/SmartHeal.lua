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

----------------------------------------
-- UI Creation
----------------------------------------
function SmartHeal:CreateUI()
  if self.frame then self.frame:Show(); return end

  local f = CreateFrame("Frame","SmartHealFrame",UIParent)
  f:SetBackdrop{
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true, tileSize=16, edgeSize=16,
    insets   = {4,4,4,4},
  }
  f:SetBackdropColor(0,0,0,0.9)
  f:SetWidth(300); f:SetHeight(190)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  -- Title
  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP",f,"TOP",0,-8)
  title:SetText("SmartHeal Settings")

  -- Close
  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetWidth(24); close:SetHeight(24)
  close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)
  close:SetScript("OnClick",function() f:Hide() end)

  -- Renew checkbox
  local cb = CreateFrame("CheckButton","SmartHealRenewToggle",f,"UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT",f,"TOPLEFT",70,-40)
  cb:SetChecked(self.useRenew)
  cb:SetScript("OnClick",function() 
    -- 'this' is the clicked checkbox in Classic
    SmartHeal.useRenew = this:GetChecked() 
  end)
  local cbLabel = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  cbLabel:SetPoint("LEFT",cb,"RIGHT",4,0)
  cbLabel:SetText("Use Renew (Rank 1)")

  -- Heal Spell label
  local spellLabel = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  spellLabel:SetPoint("TOPLEFT",f,"TOPLEFT",70,-80)
  spellLabel:SetText("Heal Spell:")

  -- Spell input
  local eb = CreateFrame("EditBox","SmartHealSpellInput",f,"InputBoxTemplate")
  eb:SetWidth(180); eb:SetHeight(20)
  eb:SetPoint("TOPLEFT",f,"TOPLEFT",70,-100)
  eb:SetText(self.spell); eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed",function(box)
    local txt = trim(box:GetText())
    if txt~="" then SmartHeal.spell = txt end
    box:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)

  -- Slider label (shifted left)
  local sliderLabel = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT",eb,"BOTTOMLEFT", -50, -16)
  sliderLabel:SetText("Heal Below HP %:")

  -- Slider
  local slider = CreateFrame("Slider","SmartHealThresholdSlider",f,"OptionsSliderTemplate")
  slider:SetPoint("LEFT",sliderLabel,"RIGHT",8,-2)
  slider:SetMinMaxValues(0,1); slider:SetValueStep(0.05)
  slider:SetValue(self.threshold)
  slider:SetScript("OnValueChanged",function(_,val)
    SmartHeal.threshold = val
  end)
  getglobal(slider:GetName().."Low"):SetText("0%")
  getglobal(slider:GetName().."High"):SetText("100%")
  getglobal(slider:GetName().."Text"):SetText("Threshold")

  self.frame = f
end

----------------------------------------
-- Core Logic
----------------------------------------
function SmartHeal:HasRenew(unit)
  for i=1,16 do
    local buffName = UnitBuff(unit,i)
    if buffName and strmatch(buffName,"^Renew") then return true end
  end
  return false
end

function SmartHeal:HealLowest()
  -- gather units…
  local units = {"player"}
  local raidCount  = (GetNumRaidMembers  and GetNumRaidMembers())  or 0
  local partyCount = (GetNumPartyMembers and GetNumPartyMembers()) or 0
  if raidCount>0 then
    for i=1,raidCount do table.insert(units,"raid"..i) end
  elseif partyCount>0 then
    for i=1,partyCount do table.insert(units,"party"..i) end
  end

  -- find the lowest‐HP unit
  local lowest, lowestHP = "player", UnitHealth("player")/UnitHealthMax("player")
  for _,u in ipairs(units) do
    if UnitExists(u) and UnitIsFriend("player",u) and not UnitIsDead(u) then
      local hp = UnitHealth(u)/UnitHealthMax(u)
      if hp < lowestHP then lowest, lowestHP = u, hp end
    end
  end

  -- DEBUG: report what it found
  DEFAULT_CHAT_FRAME:AddMessage(
    ("SmartHeal Debug: lowest=%s (%d%%) threshold=%.0f%%"):format(
      lowest, lowestHP*100, (self.threshold or 0)*100
    )
  )

  -- only heal if below threshold
  if not lowestHP or not self.threshold then
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal Debug: missing data, aborting.")
    return
  end
  if lowestHP >= self.threshold then
    DEFAULT_CHAT_FRAME:AddMessage("SmartHeal Debug: above threshold, no cast.")
    return
  end

  -- DEBUG: we’re about to cast
  DEFAULT_CHAT_FRAME:AddMessage(("SmartHeal Debug: casting on %s"):format(lowest))

  -- save target, cast, restore target…
  local old = UnitName("target")
  TargetUnit(lowest)
  if self.useRenew and not self:HasRenew(lowest) then
    CastSpellByName("Renew(Rank 1)")
  else
    CastSpellByName(self.spell)
  end
  if old then TargetByName(old) end
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

  -- persist
  SmartHealDB.spell         = SmartHeal.spell
  SmartHealDB.useRenew      = SmartHeal.useRenew
  SmartHealDB.threshold     = SmartHeal.threshold
  SmartHealDB.renewCooldown = SmartHeal.renewCooldown

  SmartHeal:HealLowest()
end
