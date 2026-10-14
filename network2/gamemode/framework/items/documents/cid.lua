-- The CID card: every new character gets one (sv_social.lua), never again. The card keeps who it
-- was issued to (cell data); "Посмотреть" shows it, the wheel over a player can show it to them.
ITEM.name = "CID-карта"
ITEM.description = "Удостоверение гражданина: имя, номер CID, приметы и снимок. Выдаётся один раз — " ..
	"потеряете, новую не дадут."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.icon = "cid"
ITEM.useVerb = "посмотреть"

-- looking at it does not use it up
function ITEM.OnUse(client, cell)
	NW.social.ShowCard(client, cell.data)

	return false
end
