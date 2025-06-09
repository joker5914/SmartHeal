SmartHeal = {}
SmartHeal.spell = "Flash Heal(Rank 2)" -- default fallback
SmartHeal.useRenew = true

local function safe_trim(str)
  return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

function SmartHeal:CreateUI()
  if self.frame then return end

  local f = CreateFrame("Frame", "SmartHealFrame", UIParent)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0, 0, 0, 0.9)
  f:SetWidth(250)
  f:SetHeight(100)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("SmartHeal Settings")

  -- Close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetWidth(24)
  close:SetHeight(24)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Checkbox for Renew toggle
  local checkbox = CreateFrame("CheckButton", "SmartHealRenewToggle", f, "UICheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -35)
  checkbox:SetChecked(SmartHeal.useRenew)
  checkbox:SetScript("OnClick", function(self)
    SmartHeal.useRenew = self:GetChecked()
  end)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
  label:SetText("Use Renew(Rank 1) if not active")

  self.frame = f
end

function SmartHeal:SetSpell(spellName)
  if type(spellName) == "string" and spellName ~= "" and spellName ~= self.spell then
    self.spell = spellName
  end
end

function SmartHeal:HasRenew(unit)
  for i = 1, 16 do
    local buff = UnitBuff(unit, i)
    if buff and string.find(buff, "Renew") then
      return true
    end
  end
  return false
end

function SmartHeal:IsTank(name)
  name = string.lower(name or "")
  return string.find(name, "tank") or string.find(name, "war") or string.find(name, "mt") or string.find(name, "prot")
end

function SmartHeal:HealLowest()
  local units = {}
  local lowest, lowestHP = "player", UnitHealth("player") / UnitHealthMax("player")

  table.insert(units, "player")
  for i = 1, 4 do table.insert(units, "party"..i) end
  for i = 1, 40 do table.insert(units, "raid"..i) end

  for _, unit in ipairs(units) do
    if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDead(unit) then
      local hp = UnitHealth(unit) / UnitHealthMax(unit)
      if hp < lowestHP then
        lowest = unit
        lowestHP = hp
      elseif math.abs(hp - lowestHP) < 0.01 then
        local unitName = UnitName(unit)
        local lowestName = UnitName(lowest)
        if self:IsTank(unitName) and not self:IsTank(lowestName) then
          lowest = unit
        elseif unit == "player" and lowest ~= "player" then
          lowest = unit
        end
      end
    end
  end

  if lowestHP < 0.85 then
    TargetUnit(lowest)
    if SmartHeal.useRenew and not self:HasRenew(lowest) then
      CastSpellByName("Renew(Rank 1)")
    else
      CastSpellByName(self.spell)
    end
  end
end

SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = safe_trim(msg or "")
  if msg == "ui" then
    SmartHeal:CreateUI()
  elseif msg ~= "" then
    SmartHeal:SetSpell(msg)
  end
  SmartHeal:HealLowest()
end
