util.AddNetworkString("nwFabricatorOpen")
util.AddNetworkString("nwFabricatorClose")
util.AddNetworkString("nwFabricatorSync")
util.AddNetworkString("nwFabricatorAction")

local function Notice(client, key, ...)
	local text = select("#", ...) > 0 and L(key, ...) or key

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function TakeItems(state, id, amount)
	local left = amount

	for _, key in ipairs({"items", "storage"}) do
		for index, item in pairs(state[key] or {}) do
			if (left <= 0) then
				break
			end

			if (item.id != id) then
				continue
			end

			local taken = math.min(item.amount or 1, left)

			left = left - taken

			if ((item.amount or 1) > taken) then
				item.amount = item.amount - taken
			else
				state[key][index] = nil
			end
		end
	end

	return left <= 0
end

local poolPath = "network/fabricator.txt"

function NETWORK.fabricator.SavePool()
	file.CreateDir("network")
	file.Write(poolPath, util.TableToJSON({
		map = game.GetMap(),
		resin = NETWORK.fabricator.GetPool()
	}, true))
end

function NETWORK.fabricator.SetPool(amount)
	SetGlobalInt("nwFabResin",
		math.Clamp(math.floor(amount or 0), 0, NETWORK.fabricator.poolMax))
end

function NETWORK.fabricator.AddPool(amount)
	NETWORK.fabricator.SetPool(NETWORK.fabricator.GetPool() + (amount or 0))
	NETWORK.fabricator.SavePool()
end

function NETWORK.fabricator.LoadPool()
	local contents = file.Read(poolPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (!istable(data) or data.map != game.GetMap()) then
		NETWORK.fabricator.SetPool(0)

		return
	end

	NETWORK.fabricator.SetPool(tonumber(data.resin) or 0)
end

hook.Add("InitPostEntity", "nwFabricatorPool", function()
	NETWORK.fabricator.LoadPool()
end)

function NETWORK.fabricator.AbsorbResin(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local state = NETWORK.inventory.GetState(client)
	local id = NETWORK.fabricator.resource
	local have = NETWORK.fabricator.CountItems(state, id)

	if (have <= 0) then
		client.nwFabFullWarned = nil

		return false
	end

	local room = NETWORK.fabricator.poolMax - NETWORK.fabricator.GetPool()
	local amount = math.min(have, room)

	if (amount <= 0) then
		if (!client.nwFabFullWarned) then
			client.nwFabFullWarned = true

			NETWORK.notice.Send(client, "fabResinFull", "warn")
		end

		return false
	end

	TakeItems(state, id, amount)

	NETWORK.fabricator.AddPool(amount)

	NETWORK.notice.Send(client, "fabResinDeposited", "good", amount,
		NETWORK.fabricator.GetPool(), NETWORK.fabricator.poolMax)

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("item", string.format("%s сдал в фабрикатор смолу ×%d",
			NETWORK.log.Name(client), amount), client:GetPos())
	end

	hook.Run("NetworkFabricatorResinDeposited", client, amount)

	return true
end

hook.Add("ShutDown", "nwFabricatorPool", function()
	NETWORK.fabricator.SavePool()
end)

timer.Remove("nwFabricatorPool")

local F=NETWORK.fabricator
local function Allowed(p)
 return IsValid(p) and p:HasCharacter() and p:Alive() and (p:IsCombine() or p:IsCWUMember() or p:IsAdmin())
end
function F.Close(p)
 if (IsValid(p.nwFabricator)) then p.nwFabricator.users[p]=nil end
 p.nwFabricator=nil p:SetNWBool("nwBusy",false)
 net.Start("nwFabricatorClose") net.Send(p)
end
function F.Open(p,e)
 if (!Allowed(p) or !IsValid(e) or p:GetPos():DistToSqr(e:GetPos())>F.range*F.range) then return end
 F.Close(p) p.nwFabricator=e e.users[p]=true p:SetNWBool("nwBusy",true)
 e:SetNWFloat("nwFabOpenUntil",CurTime()+30)
 net.Start("nwFabricatorOpen") net.WriteEntity(e) net.Send(p)
end
function F.Tick(e)
 if (e:GetProduct()!="" and e:GetPhase()==1 and CurTime()>=e:GetCompleteAt()) then
  e:SetPhase(2) e:EmitSound("items/ammocrate_open.wav",65)
  NETWORK.entities.Save()
 end
end
local function FinishCollect(p,e)
 if (e:GetPhase()!=2 or e:GetProduct()=="") then return end
 if (e:GetBuyer()!=p:GetCharacterID() and !p:IsAdmin()) then return Notice(p,"Изделие ожидает заказавшего сотрудника.") end
 local item=util.JSONToTable(e:GetProductData())
 if (!istable(item) or !NETWORK.item.Get(item.id)) then return Notice(p,"Ошибка сохранённого изделия.") end
 local state=table.Copy(NETWORK.inventory.GetState(p))
 if (NETWORK.inventory.Insert(state,item)>0) then return Notice(p,"Освободите место в инвентаре.") end
 e:SetProduct("") e:SetProductData("") e:SetPhase(0) e:SetBuyer(0)
 NETWORK.city.Commit(p,state) NETWORK.entities.Save()
 e:EmitSound("items/ammo_pickup.wav",60)
 NETWORK.city.Log(p,"Фабрикатор: забрано",item.id)
end
net.Receive("nwFabricatorAction",function(_,p)
 local action,id=net.ReadString(),net.ReadString()
 if (action=="close") then return F.Close(p) end
 if (!Allowed(p) or (p.nwNextFabricator or 0)>CurTime()) then return end
 p.nwNextFabricator=CurTime()+0.35
 local e=p.nwFabricator
 if (!IsValid(e) or e:GetClass()!="nw_fabricator" or p:GetPos():DistToSqr(e:GetPos())>F.range*F.range) then return end
 e:SetNWFloat("nwFabOpenUntil",CurTime()+30)
 if (action=="collect") then return FinishCollect(p,e) end
 if (action=="deposit") then
  if (F.AbsorbResin(p)) then NETWORK.inventory.Sync(p) NETWORK.persistence.Save(p) end
  return
 end
 if (action!="craft" or e:GetPhase()!=0) then return end
 local recipe=F.Get(id)
 if (!recipe or !F.CanAfford(NETWORK.inventory.GetState(p),recipe)) then return Notice(p,"Недостаточно ресурсов.") end
 if (hook.Run("NetworkFabricatorCanCraft",p,e,recipe)==false) then return end
 if (recipe.allianceOnly and !p:IsCombine() and !p:IsAdmin()) then return Notice(p,"Вооружение выдаётся только Альянсу.") end
 local item=NETWORK.item.New(recipe.item,recipe.amount)
 if (!item) then return end
 NETWORK.item.OnCreated(item,p,p:GetCharacter())
 local costs=table.Copy(recipe.cost) local resin=costs.resin or 0 costs.resin=nil
 local ok,err=NETWORK.city.Transaction(p,costs)
 if (!ok) then return Notice(p,err) end
 F.AddPool(-resin)
 e:SetProduct(item.id) e:SetProductData(util.TableToJSON(item)) e:SetBuyer(p:GetCharacterID())
 e:SetPhase(1) e:SetCompleteAt(CurTime()+8) e:SetBeginAt(CurTime())
 e:EmitSound("ambient/machines/combine_terminal_idle3.wav",65)
 NETWORK.entities.Save()
 NETWORK.city.Log(p,"Фабрикатор: запущено",item.id)
 hook.Run("NetworkFabricatorCrafted",p,e,recipe)
end)
timer.Create("nwFabricatorWatch",0.5,0,function()
 for _,p in ipairs(player.GetAll()) do
  local e=p.nwFabricator
  if (IsValid(e) and (!Allowed(p) or p:GetPos():DistToSqr(e:GetPos())>F.range*F.range)) then F.Close(p) end
 end
end)
hook.Add("PlayerDisconnected","nwFabricatorClose",function(p)
 if (IsValid(p.nwFabricator)) then p.nwFabricator.users[p]=nil end
end)
NETWORK.command.Register("fabresin",{adminOnly=true,usage="/fabresin [количество]",OnRun=function(_,p,args)
 if (args[1]) then F.SetPool(tonumber(args[1]) or 0) F.SavePool() end
 Notice(p,"Смола фабрикатора: "..F.GetPool())
end})
concommand.Add("network_fabricator_spawn",function(p)
 if (!IsValid(p) or !p:IsAdmin()) then return end
 local e=ents.Create("nw_fabricator") e:SetPos(p:GetEyeTrace().HitPos) e:SetAngles(Angle(0,p:EyeAngles().y+180,0)) e:Spawn()
 NETWORK.entities.Save()
end)
