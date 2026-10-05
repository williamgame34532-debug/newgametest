NETWORK.gui.windows = {
	"menu",
	"terminal",
	"commandHelp",
	"turret",
	"tabMenu",
	"container",
	"fabricator",
	"jail",
	"trade",
	"dialogue",
	"escape",
	"zoneEditor",
	"dialogueEditor",
	"questEditor",
	"npcConfig",
	"traderConfig",
	"traderOffers",
	"containerConfig",
	"containerLoot",
	"itemMenu",
	"dragPreview",
	"tutorial",
	"help",
	"recognise",
	"playerMenu",
	"medPanel",
	"documentView",
	"documentForm",
	"bodygroups",
	"questLog",
	"welcome",
	"iconEditor",
	"shopPanel"
}

function NETWORK.gui.CloseWindows(...)
	local keep = {}

	for _, key in ipairs({...}) do
		keep[key] = true
	end

	for _, key in ipairs(NETWORK.gui.windows) do
		if (keep[key]) then
			continue
		end

		local panel = NETWORK.gui[key]

		if (!IsValid(panel)) then
			continue
		end

		if (panel.Close) then
			panel:Close()
		else
			panel:Remove()
		end

		NETWORK.gui[key] = nil
	end

	NETWORK.gui.drag = nil
end

NETWORK.gui.passiveWindows = {welcome = true}

function NETWORK.gui.IsWindowOpen()
	for _, key in ipairs(NETWORK.gui.windows) do
		if (!NETWORK.gui.passiveWindows[key] and IsValid(NETWORK.gui[key])) then
			return true, key
		end
	end

	return false
end
