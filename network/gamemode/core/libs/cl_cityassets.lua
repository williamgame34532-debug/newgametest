NETWORK.cityModels = NETWORK.cityModels or {}
local M=NETWORK.cityModels
local solid=CreateMaterial("nwCityEquipment","VertexLitGeneric",{["$basetexture"]="models/debug/debugwhite",["$vertexcolor"]="1",["$vertexalpha"]="1"})
local glow=CreateMaterial("nwCityEquipmentGlow","UnlitGeneric",{["$basetexture"]="models/debug/debugwhite",["$vertexcolor"]="1"})
M.cache=M.cache or {}
function M.Draw(prefix,pos,ang,scale,open)
 local root=Matrix() root:Translate(pos) root:Rotate(ang) root:Scale(Vector(scale or 1,scale or 1,scale or 1))
 for name,data in pairs(NETWORK.cityMeshes or {}) do
  if (string.StartWith(name,prefix)) then
   local mesh=M.cache[name]
   if (!mesh) then
    local triangles={}
    for _,v in ipairs(data.vertices) do triangles[#triangles+1]={pos=Vector(v[1],v[2],v[3]),normal=Vector(v[4],v[5],v[6]),u=0,v=0,color=Color(unpack(data.color))} end
    mesh=Mesh() mesh:BuildFromTriangles(triangles) M.cache[name]=mesh
   end
   local at=LerpVector(math.Clamp(open or 0,0,1),Vector(unpack(data.closed)),Vector(unpack(data.open)))
   local offset=Matrix() offset:Translate(at)
   local matrix=root*offset
   cam.PushModelMatrix(matrix)
    render.SetMaterial(data.emissive and glow or solid) mesh:Draw()
   cam.PopModelMatrix()
  end
 end
end
hook.Add("ShutDown","nwCityMeshes",function() for _,mesh in pairs(M.cache) do mesh:Destroy() end end)
