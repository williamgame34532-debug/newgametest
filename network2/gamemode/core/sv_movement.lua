-- Normal walking pace instead of sandbox's sprinting (200 / 400): walk 100, run (Shift) 200,
-- slow walk (Alt) 70, crouch at half speed, a short jump. Server convars change the values for
-- the next spawn.

local walk = CreateConVar("nw_walkspeed", "100", FCVAR_ARCHIVE, "Скорость шага")
local run = CreateConVar("nw_runspeed", "200", FCVAR_ARCHIVE, "Скорость бега (Shift)")
local slow = CreateConVar("nw_slowwalkspeed", "70", FCVAR_ARCHIVE, "Медленный шаг (Alt)")
local jump = CreateConVar("nw_jumppower", "170", FCVAR_ARCHIVE, "Сила прыжка")

-- the class of the character may have its own speeds (sh_classes.lua)
local function Apply(client)
	local class = NW.classes and NW.classes.Of(client)

	client.nwRunSpeed = class and class.run or nil
	client:SetWalkSpeed(class and class.walk or walk:GetFloat())
	client:SetRunSpeed(class and class.run or run:GetFloat())
	client:SetSlowWalkSpeed(slow:GetFloat())
	client:SetCrouchedWalkSpeed(0.5)
	client:SetDuckSpeed(0.35)
	client:SetUnDuckSpeed(0.35)
	client:SetJumpPower(jump:GetFloat())
	client:SetLadderClimbSpeed(120)
end

NW.movement = {Apply = Apply}

-- the sandbox player class sets its own speeds while spawning: ours go on top afterwards
function GM:PlayerSpawn(client, transition)
	self.BaseClass.PlayerSpawn(self, client, transition)

	Apply(client)
end

for _, name in ipairs({"nw_walkspeed", "nw_runspeed", "nw_slowwalkspeed", "nw_jumppower"}) do
	cvars.AddChangeCallback(name, function()
		for _, client in ipairs(player.GetAll()) do
			Apply(client)
		end
	end, "nwMovement")
end
