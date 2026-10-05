NETWORK.notice = NETWORK.notice or {}

NETWORK.notice.tones = {"info", "good", "bad", "warn"}

if (SERVER) then
	util.AddNetworkString("nwNoticeTone")

	function NETWORK.notice.Send(client, key, tone, ...)
		if (!IsValid(client) or !client:IsPlayer()) then
			return
		end

		local arguments = {...}

		for index, value in ipairs(arguments) do
			arguments[index] = tostring(value)
		end

		local toneIndex = 1

		for index, id in ipairs(NETWORK.notice.tones) do
			if (id == tone) then
				toneIndex = index

				break
			end
		end

		net.Start("nwNoticeTone")
			net.WriteString(key or "")
			net.WriteUInt(toneIndex, 3)
			net.WriteUInt(#arguments, 4)

			for _, value in ipairs(arguments) do
				net.WriteString(value)
			end
		net.Send(client)
	end

	return
end

function NETWORK.notice.GetColor(tone)
	local theme = NETWORK.theme

	if (tone == "good") then
		return theme.positive
	end

	if (tone == "bad") then
		return theme.danger
	end

	if (tone == "warn") then
		return theme.warning
	end

	return theme.text
end

net.Receive("nwNoticeTone", function()
	local key = net.ReadString()
	local tone = NETWORK.notice.tones[net.ReadUInt(3)] or "info"
	local count = net.ReadUInt(4)
	local arguments = {}

	for index = 1, count do
		arguments[index] = net.ReadString()
	end

	for index, value in ipairs(arguments) do
		if (NETWORK.lang.Exists(value)) then
			arguments[index] = L(value)
		end
	end

	if (NETWORK.gui and NETWORK.gui.Notify) then
		NETWORK.gui.Notify(L(key, unpack(arguments)), NETWORK.notice.GetColor(tone))
	end
end)
