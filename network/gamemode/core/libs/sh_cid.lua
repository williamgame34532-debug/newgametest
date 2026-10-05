NETWORK.cid = NETWORK.cid or {}
NETWORK.cid.overrides = NETWORK.cid.overrides or {}
NETWORK.cid.length = 5

function NETWORK.cid.Default(id)
	return string.format("%05d", (tonumber(id) or 0) % 100000)
end

function NETWORK.cid.Get(id)
	return NETWORK.cid.overrides[tonumber(id) or 0] or NETWORK.cid.Default(id)
end

function NETWORK.cid.Normalise(text)
	text = string.gsub(tostring(text or ""), "[^%d]", "")

	if (#text != NETWORK.cid.length) then
		return nil
	end

	return text
end

function NETWORK.cid.FormatSerial(serial)
	return serial and serial != "" and serial or "—"
end

if (CLIENT) then
	net.Receive("nwCIDSync", function()
		local list = NETWORK.util.ReadTable()

		NETWORK.cid.overrides = {}

		for _, entry in ipairs(list) do
			NETWORK.cid.overrides[tonumber(entry[1]) or 0] = entry[2]
		end
	end)
end
