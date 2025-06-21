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

  -- Main Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("SmartHeal Settings")

  -- Close
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(24,24)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Renew toggle
  local cb = CreateFrame("CheckButton", "SmartHealRenewToggle", f, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -40)
  cb:SetChecked(self.useRenew)
  cb:SetScript("OnClick", function(btn) SmartHeal.useRenew = btn:GetChecked() end)
  local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  lbl:SetText("Use Renew (Rank 1)")

  -- HP threshold slider
  local slider = CreateFrame("Slider", "SmartHealThresholdSlider", f, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -100)
  slider:SetMinMaxValues(0,1); slider:SetValueStep(0.05)
  slider:SetValue(self.threshold)
  slider:SetScript("OnValueChanged", function(_, val) SmartHeal.threshold = val end)
  getglobal(slider:GetName().."Low"):SetText("0%")
  getglobal(slider:GetName().."High"):SetText("100%")
  getglobal(slider:GetName().."Text"):SetText("Heal Below HP %")

  -- **New Label for Spell Input**
  local spellLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- positioned 20px above your editbox
  spellLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -130)
  spellLabel:SetText("Heal Spell:")

  -- Spell input box
  local eb = CreateFrame("EditBox", "SmartHealSpellInput", f, "InputBoxTemplate")
  eb:SetWidth(180); eb:SetHeight(20)
  eb:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -150)
  eb:SetText(self.spell); eb:SetAutoFocus(false)
  eb:SetScript("OnEnterPressed", function(box)
    local txt = trim(box:GetText())
    if txt~="" then SmartHeal.spell = txt end
    box:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

  self.frame = f
end
