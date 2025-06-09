SmartHeal = {}
SmartHeal.spell = "Flash Heal(Rank 2)" -- default spell

local function safe_trim(str)
  return string.gsub(str, "^%s*(.-)%s*$", "%1")
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

function SmartHeal:HealLowest()
  local lowest = "player"
  local lowestHP = UnitHealth("player") / UnitHealthMax("player")

  if GetNumRaidMembers and GetNumRaidMembers() > 0 then
    for i = 1, 40 do
      local unit = "raid"..i
      if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDead(unit) then
        local hp = UnitHealth(unit) / UnitHealthMax(unit)
        if hp < lowestHP then
          lowestHP = hp
          lowest = unit
        end
      end
    end
  else
    for i = 1, 4 do
      local unit = "party"..i
      if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDead(unit) then
        local hp = UnitHealth(unit) / UnitHealthMax(unit)
        if hp < lowestHP then
          lowestHP = hp
          lowest = unit
        end
      end
    end
  end

  if lowestHP < 0.90 then
    TargetUnit(lowest)
    if not self:HasRenew(lowest) then
      CastSpellByName("Renew(Rank 1)")
    else
      CastSpellByName(self.spell)
    end
  end
end

SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = safe_trim(msg or "")
  if msg ~= "" then
    SmartHeal:SetSpell(msg)
  end
  SmartHeal:HealLowest()
end
