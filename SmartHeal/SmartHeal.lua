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

-- Estimated healing power per rank of Flash Heal
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
    if self.useRenew
       and not self:HasRenew(lowest)
       and (not lastRenew[lowest] or now - lastRenew[lowest] >= self.renewCooldown)
    then
      local canCastRenew = (not IsUsableSpell) or IsUsableSpell("Renew")
      if canCastRenew then
        CastSpellByName("Renew(Rank 1)")
        lastRenew[lowest] = now
      else
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast Renew")
      end
    else
      local baseSpell = string.match(self.spell, "^(.-)%s*%(") or self.spell
      local missingHP = UnitHealthMax(lowest) - UnitHealth(lowest)
      local bestSpell = SmartHeal:GetBestHealRank(baseSpell, missingHP)

      if bestSpell and IsUsableSpell(bestSpell) then
        CastSpellByName(bestSpell)
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Using " .. bestSpell .. " for " .. missingHP .. " missing HP.")
      else
        DEFAULT_CHAT_FRAME:AddMessage("SmartHeal: Cannot cast appropriate heal for " .. missingHP .. " HP missing.")
      end
    end

    if old then TargetByName(old) end
  end
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

SLASH_SMARTHEAL1 = "/smartheal"
SlashCmdList["SMARTHEAL"] = function(msg)
  msg = trim(msg or "")
  if msg == "ui" then SmartHeal:CreateUI(); return end
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
