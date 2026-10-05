-- Client downloads for the compiled models and materials that ship in gamemode/content.
-- resource.AddFile on a .mdl also sends its .vvd/.vtx/.phy, on a .vmt its $basetexture .vtf.
NETWORK.content = NETWORK.content or {}

NETWORK.content.roots = {
	{"models/network", {"mdl"}},
	{"models/hla_prop", {"mdl"}},
	{"materials/models/network", {"vmt", "vtf"}}
}

local function Walk(directory, extensions, out)
	local files, folders = file.Find(directory .. "/*", "GAME")

	for _, name in ipairs(files or {}) do
		local extension = string.GetExtensionFromFilename(name)

		if (extension and table.HasValue(extensions, extension:lower())) then
			out[#out + 1] = directory .. "/" .. name
		end
	end

	for _, folder in ipairs(folders or {}) do
		Walk(directory .. "/" .. folder, extensions, out)
	end

	return out
end

function NETWORK.content.Register()
	local list = {}

	for _, root in ipairs(NETWORK.content.roots) do
		Walk(root[1], root[2], list)
	end

	for _, path in ipairs(list) do
		resource.AddFile(path)
	end

	NETWORK.content.files = list

	return list
end

NETWORK.content.Register()
