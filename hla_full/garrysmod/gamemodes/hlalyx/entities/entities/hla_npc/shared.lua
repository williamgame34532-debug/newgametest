-- Story NPC: a Combine unit that stands with changing idle animations, now and then talks on the radio,
-- and answers E with lines set in the editor: the first press — line 1, the second — line 2, … the last
-- one repeats. It talks like a player: in the chat (only those near hear) and over its head in <:: ::>;
-- lines that are voicelines are said aloud. Placed and edited by admins: hla_editor (tab NPC) or hold C
-- and click the NPC.
ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'NPC (сюжет)'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true
ENT.IsHLANPC = true

function ENT:SetupDataTables()
	self:NetworkVar('String', 0, 'Weapon')
end
