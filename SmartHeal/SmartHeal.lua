SLASH_SMARTHEAL1 = "/smartheal"

function SmartHeal_Heal()
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
  CastSpellByName("Flash Heal(Rank 2)")
end

SlashCmdList["SMARTHEAL"] = SmartHeal_Heal