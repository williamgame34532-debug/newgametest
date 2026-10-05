NETWORK.trash = NETWORK.trash or {}

local T = NETWORK.trash

T.binMax = 40
T.tokensPerUnit = 0.5
T.rewardMax = 40

if (SERVER) then
	util.AddNetworkString("nwTrashOpen")
	util.AddNetworkString("nwTrashAction")

	local function HasItem(client, id)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == id) then
					return true
				end
			end
		end

		return false
	end

	function T.Open(client, bin)
		client.nwTrashBin = bin

		net.Start("nwTrashOpen")
			net.WriteEntity(bin)
			net.WriteUInt(bin:GetTrash(), 8)
			net.WriteBool(HasItem(client, "trash_bag"))
		net.Send(client)
	end

	function T.Dump(client, bin)
		local state = NETWORK.inventory.GetState(client)
		local moved = 0
		local space = T.binMax - bin:GetTrash()

		for _, list in ipairs({"items", "storage"}) do
			for index, item in pairs(state[list] or {}) do
				if (space <= 0) then
					break
				end

				local base = istable(item) and NETWORK.item.Get(item.id)

				if (base and base.category == "junk" and item.id != "trash_bag" and
					item.id != "trash_full") then
					local amount = math.min(item.amount or 1, space)

					moved = moved + amount
					space = space - amount

					if ((item.amount or 1) > amount) then
						item.amount = item.amount - amount
					else
						state[list][index] = nil
					end
				end
			end
		end

		if (moved == 0) then
			return NETWORK.notice.Send(client, "trashNothing", "warn")
		end

		bin:SetTrash(bin:GetTrash() + moved)
		bin:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "trashDumped", "good", moved)
	end

	function T.Collect(client, bin)
		local count = bin:GetTrash()

		if (count <= 0) then
			return NETWORK.notice.Send(client, "trashEmpty", "warn")
		end

		if (!HasItem(client, "trash_bag")) then
			return NETWORK.notice.Send(client, "trashNeedBag", "warn")
		end

		local state = NETWORK.inventory.GetState(client)
		local full

		for _, list in ipairs({"items", "storage"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == "trash_full") then
					full = item

					break
				end
			end
		end

		if (full) then
			full.data = full.data or {}
			full.data.amount = (full.data.amount or 0) + count
		else
			if (!NETWORK.inventory.Take(client, "trash_bag", 1)) then
				return NETWORK.notice.Send(client, "trashNeedBag", "warn")
			end

			if (!NETWORK.inventory.Give(client, "trash_full", 1, {amount = count})) then
				NETWORK.inventory.Give(client, "trash_bag", 1)

				return NETWORK.notice.Send(client, "deployNoRoom", "bad")
			end
		end

		bin:SetTrash(0)
		bin:EmitSound("physics/plastic/plastic_barrel_impact_soft" .. math.random(1, 3) .. ".wav", 60)

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "trashCollected", "good", count)
	end

	net.Receive("nwTrashAction", function(_, client)
		local action = net.ReadString()
		local bin = client.nwTrashBin

		if (!IsValid(bin) or bin:GetClass() != "nw_trashbin" or !client:HasCharacter() or
			client:GetPos():Distance(bin:GetPos()) > 140) then
			return
		end

		if ((client.nwNextTrash or 0) > CurTime()) then
			return
		end

		client.nwNextTrash = CurTime() + 0.5

		if (action == "dump") then
			T.Dump(client, bin)
		elseif (action == "collect") then
			T.Collect(client, bin)
		end

		T.Open(client, bin)
	end)

	function T.Recycle(client, dump)
		local state = NETWORK.inventory.GetState(client)
		local total = 0

		for _, list in ipairs({"items", "storage"}) do
			for index, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == "trash_full") then
					total = total + math.max(item.data and item.data.amount or 1, 1)
					state[list][index] = nil
				end
			end
		end

		if (total == 0) then
			return NETWORK.notice.Send(client, "trashNoBags", "warn")
		end

		local reward = math.min(math.ceil(total * T.tokensPerUnit), T.rewardMax)

		NETWORK.currency.Add(client, reward)
		NETWORK.inventory.Sync(client)

		dump:EmitSound("ambient/machines/thumper_dust.wav", 65, 110)
		NETWORK.notice.Send(client, "trashRecycled", "good", total, reward)

		if (NETWORK.journal and NETWORK.journal.AddTo) then
			NETWORK.journal.AddTo(client, "note", L("trashJournal", total, reward))
		end
	end

	return
end

net.Receive("nwTrashOpen", function()
	local bin = net.ReadEntity()
	local count = net.ReadUInt(8)
	local bHasBag = net.ReadBool()

	if (IsValid(NETWORK.gui.trashMenu)) then
		NETWORK.gui.trashMenu:Remove()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local panel = vgui.Create("EditablePanel")

	NETWORK.gui.trashMenu = panel
	panel:SetSize(Sc(380), Sc(230))
	panel:Center()
	panel:MakePopup()
	panel.alpha = 0

	panel.Think = function(this)
		this.alpha = util.Approach(this.alpha, 1, 8)
		this:SetAlpha(math.Round(this.alpha * 255))

		if (!IsValid(bin) or LocalPlayer():GetPos():DistToSqr(bin:GetPos()) > 200 * 200) then
			this:Remove()
		end
	end

	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			this:Remove()
		end
	end

	panel.Paint = function(this, width, height)
		local radius = math.max(Sc(10), 6)

		util.DrawBlurRounded(this, 0, 0, width, height, radius, 4)
		draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 236))
		util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			Color(255, 255, 255, 26))

		draw.SimpleText(util.Upper(L("trashTitle")), "nwInvKey", Sc(22), Sc(22),
			ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("trashCount", count, NETWORK.trash.binMax), "nwInvTitle", Sc(22), Sc(46),
			theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(Sc(22), Sc(68), width - Sc(44), 1)

		draw.SimpleText(bHasBag and L("trashHintBag") or L("trashHintNoBag"), "nwHudSmall",
			Sc(22), height - Sc(20), theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local function Row(y, label, glyph, bPrimary, action)
		local button = panel:Add("nwInvButton")

		button:SetPos(Sc(22), y)
		button:SetSize(Sc(380) - Sc(44), Sc(38))
		button:Setup(label, glyph, bPrimary)
		button.DoClick = function()
			net.Start("nwTrashAction")
				net.WriteString(action)
			net.SendToServer()
		end
	end

	Row(Sc(84), L("trashDump"), "down", true, "dump")
	Row(Sc(132), L("trashCollect"), "up", bHasBag, "collect")

	local close = panel:Add("DButton")

	close:SetText("")
	close:SetCursor("hand")
	close:SetSize(Sc(30), Sc(30))
	close:SetPos(Sc(380) - Sc(40), Sc(12))
	close.DoClick = function()
		panel:Remove()
	end
	close.Paint = function(this, width, height)
		local color = this:IsHovered() and theme.danger or theme.textDim
		local inset = Sc(10)

		util.DrawThickLine(inset, inset, width - inset, height - inset, math.max(Sc(1), 1), color)
		util.DrawThickLine(width - inset, inset, inset, height - inset, math.max(Sc(1), 1), color)
	end
end)
