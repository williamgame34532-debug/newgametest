-- Background sounds of the city, sent by the server to everyone at the same moment (sv_ambient.lua).
-- hla_ambient_volume 0..1 — how loud they are for you.
local vol = CreateClientConVar('hla_ambient_volume', '0.8', true, false, 'Volume of the city background sounds (0..1)')
net.Receive('hla_amb', function()
	local path, v = net.ReadString(), net.ReadFloat()
	local p = LocalPlayer()
	if not IsValid(p) or vol:GetFloat() <= 0 then return end
	-- everywhere (no position), on its own channel so it does not cut other sounds
	p:EmitSound(path, 0, 100, math.Clamp(v * vol:GetFloat(), 0, 1), CHAN_STATIC)
end)
