SmartHeal = {}
SmartHeal.spell = "Flash Heal(Rank 2)" -- default fallback

function SmartHeal:SetSpell(spellName)
  if type(spellName) == "string" and spellName ~= "" then
    self.spell = spellName
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SmartHeal]:|r Spell set to '" .. spellName .. "'")
  end
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
          lowest = unit
          lowestHP = hp
        end
      end
    end
  else
    for i = 1, 4 do
      local unit = "party"..i
      if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDead(unit) then
        local hp = UnitHealth(unit) / UnitHealthMax(unit)
        if hp < lowestHP then
          lowest = unit
          lowestHP = hp
        end
      end
    end
  end

  TargetUnit(lowest)
  CastSpellByName(self.spell)
end

SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = msg:trim()
  if msg ~= "" then
    SmartHeal:SetSpell(msg)
  end
  SmartHeal:HealLowest()
end
