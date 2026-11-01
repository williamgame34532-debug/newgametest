-- Squads (formations) of units: made and joined at a Combine terminal (hla_terminal). The squad of a
-- player is shown top right, squad mates are outlined in blue with their name over the head.
HLA = HLA or {}
HLA.Squads = HLA.Squads or {list = {}}
local SQ = HLA.Squads

SQ.Max = 5          -- squads at once
SQ.MaxMembers = 6
SQ.Kinds = {'ОТРЯД ЗАЩИТЫ', 'ПАТРУЛЬ', 'ОТРЯД ПОДАВЛЕНИЯ', 'РАЗВЕДКА'}

-- the squad of a player: table {id, name, leader, members} or nil
function SQ.Of(p)
	if not IsValid(p) then return end
	local id = p:GetNWInt('hla_squad', 0)
	if id > 0 then return SQ.list[id] end
end

function SQ.Count()
	local n = 0
	for _ in pairs(SQ.list) do n = n + 1 end
	return n
end
