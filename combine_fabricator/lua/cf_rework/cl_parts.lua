-- Client: splits station.mdl into the static hull and its moving pieces (cl_partmap.lua), builds
-- IMeshes for them and for the built parts (sh_geometry.lua), and draws the whole posed machine.
local C = CFRework
local M = C.M
local P = {}
C.Parts = P

---------------------------------------------------------------------------------------------------
-- materials for the built parts
local function lit(name, base, color2, phong)
	return CreateMaterial('cfr_' .. name, 'VertexLitGeneric', {
		['$basetexture'] = base, ['$model'] = 1, ['$color2'] = color2,
		['$phong'] = phong and 1 or 0, ['$phongboost'] = phong or 0, ['$phongexponent'] = 18,
		['$phongfresnelranges'] = '[0.3 0.6 1]',
	})
end
local function unlit(name, color, additive)
	return CreateMaterial('cfr_' .. name, 'UnlitGeneric', {
		['$basetexture'] = 'vgui/white', ['$color'] = color, ['$additive'] = additive and 1 or 0,
	})
end
P.MAT = {
	metal = lit('metal3', 'models/cf_rework/socket', '[0.35 0.38 0.42]', 0.15),
	steel = lit('steel3', 'models/cf_rework/socket', '[0.9 0.95 1.0]', 0.5),
	brass = lit('brass3', 'models/cf_rework/socket', '[1.55 1.4 1.15]', 0.6),
	silver = lit('silver3', 'models/cf_rework/socket', '[1.9 1.95 2.0]', 0.6),
	dark = unlit('dark3', '[0.02 0.025 0.03]'),
	screen = unlit('screen3', '[0.02 0.11 0.15]'),
	glow = unlit('glow3', '[0.25 0.85 1.0]'),
	white = unlit('white3', '[1 1 1]'),
	red = unlit('red3', '[1 0.12 0.08]'),
}
P.GLOWMATS = {glow = true, white = true, red = true}

---------------------------------------------------------------------------------------------------
-- model split (done once per map/model, spread over frames)
local state = 'idle'   -- idle / building / ready / failed
local hull = {}        -- part name ('hull' or a model part) -> list of {mesh, material}
local built = {}       -- built part name -> list of {mesh, matname}

function P.Ready() return state == 'ready' end

local function buildBuilt()
	for name, mats in pairs(C.Geo.build()) do
		built[name] = {}
		for matname, list in pairs(mats) do
			local tris = {}
			for i = 1, #list, 8 do
				tris[#tris + 1] = {pos = Vector(list[i], list[i + 1], list[i + 2]),
					normal = Vector(list[i + 3], list[i + 4], list[i + 5]), u = list[i + 6], v = list[i + 7]}
			end
			local m = Mesh()
			m:BuildFromTriangles(tris)
			built[name][#built[name] + 1] = {mesh = m, mat = matname}
		end
	end
end

local CHUNK = 20000 * 3

local function splitModel()
	local src = util.GetModelMeshes(C.Model, 0, 0)
	if not istable(src) or #src == 0 then error('no meshes for ' .. C.Model) end
	-- 1) union-find over vertex positions quantized to 1/100 unit (same rule as the offline tool)
	local parent = {}
	local floor = math.floor
	local function key(p) return floor(p.x * 100 + 0.5) .. ' ' .. floor(p.y * 100 + 0.5) .. ' ' .. floor(p.z * 100 + 0.5) end
	local function find(a)
		local r = a
		while parent[r] ~= r do r = parent[r] end
		while parent[a] ~= r do local n = parent[a] parent[a] = r a = n end
		return r
	end
	local first = {}
	local count = 0
	for mi, part in ipairs(src) do
		local t = part.triangles
		first[mi] = {}
		for i = 1, #t, 3 do
			local k1, k2, k3 = key(t[i].pos), key(t[i + 1].pos), key(t[i + 2].pos)
			if not parent[k1] then parent[k1] = k1 end
			if not parent[k2] then parent[k2] = k2 end
			if not parent[k3] then parent[k3] = k3 end
			local r1 = find(k1)
			local r2 = find(k2) if r2 ~= r1 then parent[r2] = r1 end
			local r3 = find(k3) if r3 ~= r1 then parent[r3] = r1 end
			first[mi][(i + 2) / 3] = k1
			count = count + 1
			if count % 4000 == 0 then coroutine.yield() end
		end
	end
	-- 2) per component: triangle count and centroid of all corners
	local comp = {}
	for mi, part in ipairs(src) do
		local t = part.triangles
		for i = 1, #t, 3 do
			local r = find(first[mi][(i + 2) / 3])
			local c = comp[r]
			if not c then c = {n = 0, x = 0, y = 0, z = 0} comp[r] = c end
			c.n = c.n + 1
			for j = 0, 2 do local p = t[i + j].pos c.x = c.x + p.x c.y = c.y + p.y c.z = c.z + p.z end
		end
		coroutine.yield()
	end
	-- 3) match against the part map; GetModelMeshes may return raw MDL space or the root-rotated
	--    space, so both readings are tried and the better one wins
	local lookup = {}
	for name, list in pairs(C.PartMap) do
		for _, e in ipairs(list) do
			lookup[e[1]] = lookup[e[1]] or {}
			table.insert(lookup[e[1]], {e[2], e[3], e[4], name})
		end
	end
	local function match(rotated)
		local res, hits = {}, 0
		for r, c in pairs(comp) do
			local x, y, z = c.x / (3 * c.n), c.y / (3 * c.n), c.z / (3 * c.n)
			if rotated then x, y = y, -x end -- entity space back to raw: raw = (y, -x)
			for _, e in ipairs(lookup[c.n] or {}) do
				if math.abs(e[1] - x) < 0.03 and math.abs(e[2] - y) < 0.03 and math.abs(e[3] - z) < 0.03 then
					res[r] = e[4] hits = hits + 1 break
				end
			end
		end
		return res, hits
	end
	local resA, hitsA = match(false)
	local resB, hitsB = match(true)
	local rotated = hitsB > hitsA
	local partOf = rotated and resB or resA
	P.Matched = math.max(hitsA, hitsB)
	-- 4) buckets of triangles in entity space: (part, material) -> vertex list
	local buckets = {}
	for mi, part in ipairs(src) do
		local t = part.triangles
		local mat = part.material
		for i = 1, #t, 3 do
			local name = partOf[find(first[mi][(i + 2) / 3])] or 'hull'
			local b = buckets[name .. '|' .. mat]
			if not b then b = {name = name, mat = mat, verts = {}} buckets[name .. '|' .. mat] = b end
			for j = 0, 2 do
				local v = t[i + j]
				local p, n = v.pos, v.normal or vector_up
				if not rotated then
					p = Vector(-p.y, p.x, p.z)
					n = Vector(-n.y, n.x, n.z)
				end
				b.verts[#b.verts + 1] = {pos = p, normal = n, u = v.u, v = v.v}
			end
		end
		coroutine.yield()
	end
	for _, b in pairs(buckets) do
		hull[b.name] = hull[b.name] or {}
		local mat = Material(b.mat)
		for s = 1, #b.verts, CHUNK do
			local m = Mesh(mat)
			local slice = {}
			for i = s, math.min(s + CHUNK - 1, #b.verts) do slice[#slice + 1] = b.verts[i] end
			m:BuildFromTriangles(slice)
			table.insert(hull[b.name], {mesh = m, mat = mat})
			coroutine.yield()
		end
	end
end

local worker
function P.Prepare()
	if state ~= 'idle' then return end
	state = 'building'
	buildBuilt()
	worker = coroutine.create(splitModel)
end

hook.Add('Think', 'CFReworkBuildMeshes', function()
	if not worker then return end
	local deadline = SysTime() + 0.004
	repeat
		local ok, err = coroutine.resume(worker)
		if not ok then
			state = 'failed' worker = nil
			ErrorNoHalt('[Combine Fabricator] model split failed: ' .. tostring(err) .. '\n')
			return
		end
		if coroutine.status(worker) == 'dead' then
			worker = nil
			state = (P.Matched or 0) > 0 and 'ready' or 'failed'
			if state == 'failed' then ErrorNoHalt('[Combine Fabricator] moving parts not found in the model\n') end
			return
		end
	until SysTime() > deadline
end)

hook.Add('ShutDown', 'CFReworkFreeMeshes', function()
	for _, list in pairs(hull) do for _, e in ipairs(list) do e.mesh:Destroy() end end
	for _, list in pairs(built) do for _, e in ipairs(list) do e.mesh:Destroy() end end
end)

---------------------------------------------------------------------------------------------------
-- drawing
local function toMatrix(m)
	return Matrix({{m[1], m[2], m[3], m[4]}, {m[5], m[6], m[7], m[8]}, {m[9], m[10], m[11], m[12]}, {0, 0, 0, 1}})
end
P.ToMatrix = toMatrix

local DIRS = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1)}

-- model lighting (ambient cube) sampled at the station, so meshes are lit like the map around them
local function beginLighting(pos)
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(0.05, 0.05, 0.05)
	for i, d in ipairs(DIRS) do
		local c = render.ComputeLighting(pos, d)
		render.SetModelLighting(i - 1, c.x, c.y, c.z)
	end
end

local function drawList(list, world)
	cam.PushModelMatrix(world)
	for _, e in ipairs(list) do
		render.SetMaterial(e.mat)
		e.mesh:Draw()
	end
	cam.PopModelMatrix()
end

-- glow: brightness of the light strips, a number or {all = k, partname = k}; returns false when the split is not ready yet
function P.Draw(ent, pose, glow)
	if state ~= 'ready' then return false end
	local base = ent:GetWorldTransformMatrix()
	beginLighting(ent:WorldSpaceCenter() + ent:GetUp() * 12)
	drawList(hull.hull or {}, base)
	for name, list in pairs(hull) do
		if name ~= 'hull' and pose[name] then drawList(list, base * toMatrix(pose[name])) end
	end
	for name, list in pairs(built) do
		local m = pose[name]
		if m then
			cam.PushModelMatrix(base * toMatrix(m))
			for _, e in ipairs(list) do
				if not P.GLOWMATS[e.mat] then render.SetMaterial(P.MAT[e.mat]) e.mesh:Draw() end
			end
			cam.PopModelMatrix()
		end
	end
	render.SuppressEngineLighting(false)
	-- light strips unlit, brightness by state
	for name, list in pairs(built) do
		local m = pose[name]
		if m then
			cam.PushModelMatrix(base * toMatrix(m))
			for _, e in ipairs(list) do
				if P.GLOWMATS[e.mat] then
					local k = (e.mat == 'red') and 1 or (istable(glow) and (glow[name] or glow.all or 1) or glow)
					render.SetColorModulation(k, k, k)
					render.SetMaterial(P.MAT[e.mat])
					e.mesh:Draw()
				end
			end
			cam.PopModelMatrix()
		end
	end
	render.SetColorModulation(1, 1, 1)
	return true
end
