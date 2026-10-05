-- Player-request update. Keep the historic 'worker' faction ID for save compatibility.
NETWORK.classes.Register("cwu_employee", {
 name = "Сотрудник ГСР", faction = "worker", bCivilianHud = true
})
NETWORK.classes.Register("cwu_worker", {
 name = "Воркер ГСР", faction = "worker", bCivilianHud = true,
 model = "models/hlvr/characters/worker/npc/worker_citizen.mdl",
 callsign = "C24:WORKER-%03d", callsignMax = 999,
 toughness = {damage = 0.93, bleedSoften = 0.2, fracture = 0.8, pain = 0.75, wound = 0.9}
})
NETWORK.classes.Register("cwu_disinfector", {
 name = "Дезинфектор ГСР", faction = "worker", bCivilianHud = true,
 model = "models/hlvr/characters/hazmat_worker/npc/hazmat_worker_citizen.mdl",
 callsign = "C24:ICU-%03d", callsignMax = 999, weapons = {"weapon_applicator"},
 toughness = {damage = 0.88, bleedSoften = 0.3, fracture = 0.6, pain = 0.6, wound = 0.85, armour = 0.15}
})

if (SERVER) then
 -- Called before Spawn/NetworkCharacterLoaded, independent of hook iteration order.
 function NETWORK.classes.MigrateCWU(character)
  local id = tostring(character:GetID())
  local entry = NETWORK.classes.GetEntry(character)
  if (!entry and NETWORK.persistence) then
   local saved = NETWORK.persistence.Get(character)
   entry = saved and istable(saved.class) and saved.class or nil
  end
  local faction = character:GetFaction()
  local changed = false
  if (faction == "disinfector") then
   NETWORK.character.Update(character, {faction = "worker"})
   entry = {id = "cwu_disinfector"}
   changed = true
  elseif (faction == "citizen" and entry and
   (entry.id == "medic" or entry.id == "council" or entry.id == "worker_factory")) then
   NETWORK.character.Update(character, {faction = "worker"})
   changed = true
  elseif (faction == "worker" and !entry) then
   local workerModel = "models/hlvr/characters/worker/npc/worker_citizen.mdl"
   entry = {id = character:GetModel() == workerModel and "cwu_worker" or "cwu_employee"}
   changed = true
  end
  if (changed) then
   NETWORK.classes.assigned[id] = entry
   NETWORK.classes.SaveAll()
  end
 end
 util.AddNetworkString("nwUnitLostVisual")
 -- Additional MySQL mirrors; original SQLite/files remain the source of truth.
 local mirrorReady = false
 local function MirrorDocuments()
  if (!mirrorReady or !NETWORK.db.IsMySQL()) then return end
  local function Put(key, value)
   local data = util.TableToJSON(value)
   if (!data) then return end
   NETWORK.db.Query("REPLACE INTO network_server_documents (name, data) VALUES (" ..
    NETWORK.db.Escape(key) .. ", " .. NETWORK.db.Escape(data) .. ")")
  end
  Put("classes", NETWORK.classes.assigned or {})
  Put("permissions", NETWORK.permission.data or {})
  Put("characters", sql.Query("SELECT * FROM network_characters") or {})
 end
 hook.Add("NetworkDatabaseReady", "nwDocumentMirrors", function()
  NETWORK.db.Query("CREATE TABLE IF NOT EXISTS network_server_documents (name VARCHAR(64) PRIMARY KEY, data LONGTEXT NOT NULL)", function(_, err)
   mirrorReady = !err
   if (mirrorReady) then MirrorDocuments() end
  end)
 end)
 timer.Create("nwDocumentMirrors", 60, 0, MirrorDocuments)
 concommand.Add("network_admin_audit", function(client)
  if (IsValid(client) and !client:IsSuperAdmin()) then return end
  local lines = {"[Network] Online administration audit (no roles changed):"}
  for _, target in ipairs(player.GetAll()) do
   lines[#lines + 1] = target:SteamID64() .. " | " .. target:Nick() .. " | " .. target:GetUserGroup()
  end
  for _, line in ipairs(lines) do
   if (IsValid(client)) then client:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
  end
 end)
 return
end

CreateClientConVar("network_zone_label", "1", true, false)
CreateClientConVar("network_builtin_radio_tx", "1", true, true)
CreateClientConVar("network_builtin_radio_rx", "1", true, true)
CreateClientConVar("network_simple_inventory", "1", true, false)
for _, entry in ipairs({
 {"network_compact_hud", "Компактный HUD", "Основные показатели без имени, звания и постоянной полной выносливости."},
 {"network_zone_label", "Название зоны", "Показывать панель текущей зоны на экране."},
 {"network_simple_inventory", "Простой инвентарь", "Убрать декоративные эффекты редкости предметов."},
 {"network_builtin_radio_tx", "Рация ГО/ОТА: микрофон", "Передавать голос своей фракции. Локальную речь не отключает."},
 {"network_builtin_radio_rx", "Рация ГО/ОТА: динамик", "Принимать голос по рации. Локальную речь не отключает."}
}) do
 NETWORK.option.Register(entry[1], {name = entry[2], description = entry[3], category = "interface", default = true})
end

-- Compact mode uses the same essential indicators for every faction.
local originalKind = NETWORK.chud.GetKind
function NETWORK.chud.GetKind(client)
 if (GetConVar("network_compact_hud"):GetBool() and IsValid(client)) then return nil end
 return originalKind(client)
end

NETWORK.option.presets = NETWORK.option.presets or {}
local presets = NETWORK.option.presets
local path = "network/settings_presets.txt"
local function LoadPresets()
 local data = util.JSONToTable(file.Read(path, "DATA") or "{}")
 return istable(data) and data or {}
end
function presets.Save(name)
 name = string.Trim(tostring(name or ""))
 if (name == "" or #name > 96) then return false end
 local data = LoadPresets()
 if (!data[name] and table.Count(data) >= 30) then return false end
 local values = {}
 for id, entry in pairs(NETWORK.option.stored) do
  if (GetConVar(entry.convar)) then values[id] = NETWORK.option.Get(id) end
 end
 data[name] = values
 file.CreateDir("network")
 file.Write(path, util.TableToJSON(data, true))
 return true
end
function presets.Apply(name)
 local values = LoadPresets()[name]
 if (!istable(values)) then return false end
 for id, value in pairs(values) do
  local entry = NETWORK.option.stored[id]
  if (!entry or !GetConVar(entry.convar)) then continue end
  if (entry.type == "number") then
   value = tonumber(value)
   if (!value) then continue end
   value = math.Clamp(value, entry.min or -100000, entry.max or 100000)
  elseif (entry.type == "choice") then
   local valid = false
   for _, option in ipairs(entry.options or {}) do
    if (tostring(option.value) == tostring(value)) then valid = true break end
   end
   if (!valid) then continue end
  elseif (entry.type == "bool") then
   value = tobool(value)
  end
  NETWORK.option.Set(id, value)
 end
 return true
end
function presets.Open()
 local frame = vgui.Create("DFrame")
 frame:SetTitle("Предустановки настроек")
 frame:SetSize(420, 190)
 frame:Center()
 frame:MakePopup()
 local pick = frame:Add("DComboBox")
 pick:Dock(TOP)
 pick:SetTall(28)
 local data = LoadPresets()
 local names = table.GetKeys(data)
 table.sort(names)
 for _, name in ipairs(names) do pick:AddChoice(name) end
 local name = frame:Add("DTextEntry")
 name:Dock(TOP)
 name:SetTall(28)
 name:SetPlaceholderText("Название нового набора")
 local function Button(label, callback)
  local button = frame:Add("DButton")
  button:Dock(TOP)
  button:SetTall(28)
  button:SetText(label)
  button.DoClick = callback
 end
 Button("Сохранить текущие настройки", function()
  local value = string.Trim(name:GetValue())
  local function Save()
   if (presets.Save(value)) then frame:Close() presets.Open() end
  end
  if (data[value]) then Derma_Query("Заменить набор «" .. value .. "»?", "Предустановки", "Заменить", Save, "Отмена") else Save() end
 end)
 Button("Применить выбранный набор", function()
  local value = pick:GetSelected()
  if (presets.Apply(value)) then frame:Close() end
 end)
 Button("Удалить выбранный набор", function()
  local value = pick:GetSelected()
  if (!data[value]) then return end
  Derma_Query("Удалить набор «" .. value .. "»?", "Предустановки", "Удалить", function()
   local current = LoadPresets()
   current[value] = nil
   file.Write(path, util.TableToJSON(current, true))
   frame:Close()
   presets.Open()
  end, "Отмена")
 end)
end
concommand.Add("network_settings_presets", presets.Open)

local lost = {}
net.Receive("nwUnitLostVisual", function()
 lost[#lost + 1] = {position = net.ReadVector(), name = net.ReadString(), expires = CurTime() + 20}
 if (#lost > 12) then table.remove(lost, 1) end
end)
hook.Add("HUDPaint", "nwUnitLostVisual", function()
 local client = LocalPlayer()
 if (!IsValid(client) or !client:HasCharacter() or !client:IsCombine()) then lost = {} return end
 if (!client:Alive() or NETWORK.hud.IsHidden()) then return end
 for i = #lost, 1, -1 do
  local entry = lost[i]
  if (CurTime() > entry.expires) then table.remove(lost, i) continue end
  local screen = entry.position:ToScreen()
  if (!screen.visible) then continue end
  local x = math.Clamp(screen.x, 75, ScrW() - 75)
  local y = math.Clamp(screen.y, 70, ScrH() - 70)
  local alpha = math.min((entry.expires - CurTime()) * 80, 230)
  surface.SetDrawColor(235, 75, 65, alpha)
  surface.DrawOutlinedRect(x - 12, y - 12, 24, 24, 2)
  surface.DrawLine(x - 8, y - 8, x + 8, y + 8)
  surface.DrawLine(x + 8, y - 8, x - 8, y + 8)
  draw.SimpleTextOutlined(entry.name, "nwHudSmall", x, y + 18, Color(235, 90, 75, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
 end
end)
