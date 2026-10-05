NETWORK.city = NETWORK.city or {}
local C = NETWORK.city
C.cameraCost = {scrap = 10, wire = 2, resin = 1}
C.cameraHP = 20
C.cameraLimit = 24
C.cameraPerChar = 4
C.cpRange = 300
C.hackTime = 8
C.jobRecipes = {
 factory_operator = {name = "Сборка промышленной партии", cost = {scrap = 2, wire = 1}, result = "factory_batch", duration = 8},
 factory_qc = {name = "Контроль качества партии", cost = {factory_batch = 1}, result = "factory_certified", duration = 6},
 factory_logistics = {name = "Отгрузка проверенной партии", cost = {factory_certified = 1}, reward = 6, duration = 6}
}
for _, entry in ipairs({
 {"factory_electrician", "Электрик завода"}, {"factory_operator", "Оператор производства"},
 {"factory_qc", "Контролёр ОТК"}, {"factory_logistics", "Логист завода"}
}) do
 NETWORK.classes.Register(entry[1], {name = entry[2], faction = "worker", bCivilianHud = true,
  items = entry[1] == "factory_electrician" and {"mechanic_toolkit"} or nil})
end
function C.IsCWU(p) return IsValid(p) and p:HasCharacter() and p:IsCWUMember() end
function C.IsAlliance(p) return IsValid(p) and p:HasCharacter() and p:IsCombine() end
function C.HasItem(p, id)
 local state = SERVER and NETWORK.inventory.GetState(p) or NETWORK.inventory.state
 for _, key in ipairs({"items", "storage", "equipped"}) do
  for _, item in pairs(state and state[key] or {}) do if (item.id == id) then return true end end
 end
 return false
end
function C.HasPDA(p)
 return C.IsAlliance(p) and C.HasItem(p, "pda_alliance") or C.IsCWU(p) and C.HasItem(p, "pda_cwu")
end
NETWORK.deploy.Register("remote_charge", {
 item = "remote_charge", class = "nw_remote_charge", model = "models/props_lab/reciever01b.mdl",
 mount = "floor", hullSize = 14, hullHeight = 12, spacing = 40, time = 5, offset = 2,
 name = "Радиозаряд", bHidden = true, bNoMenu = true, bLimited = true,
 CanUse = function(p) return NETWORK.trap.IsRebel(p) end,
 CanPlace = function(p,data) return NETWORK.trap.CanPlace(p,data) end
})
NETWORK.trap.classes.nw_remote_charge = true
NETWORK.trap.rebelClasses.nw_remote_charge = true
NETWORK.deploy.Register("c24_camera", {
 item = "c24_camera_kit", class = "nw_c24_camera", model = "models/dav0r/camera.mdl",
 mount = "wall", hullSize = 8, hullHeight = 12, spacing = 45, time = 5, offset = 4,
 name = "Камера С24", bHidden = true, bNoMenu = true,
 CanUse = C.IsCWU,
 CanPlace = function(p)
  if (SERVER) then return C.CanPlaceCamera(p) end
  return true
 end,
 OnDeployed = function(entity,p)
  entity:SetOwnerCharacter(p:GetCharacterID())
  entity:SetCamName("C24 / " .. p:GetCharacterID() .. "-" .. entity:EntIndex())
  C.Log(p, "Установлена камера", entity:GetCamName())
  NETWORK.entities.Save()
 end
})
