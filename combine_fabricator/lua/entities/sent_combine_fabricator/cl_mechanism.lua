local C=CFRework local S=C.State
local metal=Material('models/cf_rework/socket')
local beam=Material('cable/blue_elec')
local glow=Material('sprites/light_glow02_add')
-- Shared immutable geometry: never bake meshes separately for each station/frame.
local cache,worker,failed
local pivot=Vector(0,0,38.5)
local function prepareShell()
 if cache or worker or failed then return end
 worker=coroutine.create(function()
  local src=util.GetModelMeshes(C.Model,0,0)
  if not istable(src) or #src==0 then failed=true return end
  local built={body={},lid={}}
  for _,part in ipairs(src) do
   local groups={body={},lid={}}
   local function flush(key)
    local verts=groups[key] if #verts==0 then return end
    local m=Mesh() m:BuildFromTriangles(verts)
    built[key][#built[key]+1]={mesh=m,material=Material(part.material)} groups[key]={}
   end
   local function emit(key,poly)
    for k=2,#poly-1 do
     local list=groups[key]
     for _,v in ipairs({poly[1],poly[k],poly[k+1]}) do
      local p=Vector(-v.pos.y,v.pos.x,v.pos.z)
      if key=='lid' then p=p-pivot end
      list[#list+1]={pos=p,normal=Vector(-v.normal.y,v.normal.x,v.normal.z),u=v.u,v=v.v}
     end
     if #list>=30000 then flush(key) end
    end
   end
   local planes={function(p)return p.x+16 end,function(p)return 16-p.x end,function(p)return -p.y end,function(p)return p.z-38.5 end}
   local function split(poly,distance)
    local inside,outside={},{}
    for k,a in ipairs(poly) do
     local b=poly[k%#poly+1] local da,db=distance(a.pos),distance(b.pos)
     local dest=da>=0 and inside or outside dest[#dest+1]=a
     if (da>=0)~=(db>=0) then
      local f=da/(da-db)
      local v={pos=a.pos+(b.pos-a.pos)*f,normal=(a.normal+(b.normal-a.normal)*f):GetNormalized(),u=a.u+(b.u-a.u)*f,v=a.v+(b.v-a.v)*f}
      inside[#inside+1]=v outside[#outside+1]=v
     end
    end
    return inside,outside
   end
   for i=1,#part.triangles,3 do
    local poly={part.triangles[i],part.triangles[i+1],part.triangles[i+2]}
    for _,plane in ipairs(planes) do
     if #poly<3 then break end
     local outside
     poly,outside=split(poly,plane) emit('body',outside)
    end
    emit('lid',poly)
    if i%6000==1 then coroutine.yield() end
   end
   flush('body') flush('lid') coroutine.yield()
  end
  cache=built
 end)
end
hook.Add('Think','CFReworkBuildGeometry',function()
 if not worker then return end
 local deadline=SysTime()+.002
 repeat
  local ok,err=coroutine.resume(worker)
  if not ok then failed=true worker=nil ErrorNoHalt('[Combine Fabricator] Mesh preparation: '..tostring(err)..'\n') return end
  if coroutine.status(worker)=='dead' then worker=nil return end
 until SysTime()>deadline
end)
local function drawGroup(parts,pos,ang)
 local matrix=Matrix() matrix:SetTranslation(pos) matrix:SetAngles(ang)
 cam.PushModelMatrix(matrix)
 for _,p in ipairs(parts) do render.SetMaterial(p.material) p.mesh:Draw() end
 cam.PopModelMatrix()
end
function ENT:DrawAnimatedShell(open)
 prepareShell()
 if not cache or open<.001 then self:DrawModel() return end
 render.SetLightingOrigin(self:WorldSpaceCenter())
 drawGroup(cache.body,self:GetPos(),self:GetAngles())
 local lift=C.Ease((open-.18)/.82)
 drawGroup(cache.lid,self:LocalToWorld(pivot),self:LocalToWorldAngles(Angle(-88*lift,0,0)))
end
local rod
local function rodMesh()
 if rod then return rod end
 local t={}
 local function vert(p,n,u,v) return {pos=p,normal=n,u=u,v=v} end
 for i=0,15 do
  local a=i*math.pi/8 local b=(i+1)*math.pi/8
  local p=Vector(math.cos(a),math.sin(a),0) local q=Vector(math.cos(b),math.sin(b),0)
  local n=(p+q):GetNormalized() local z=Vector(0,0,1)
  for _,v in ipairs({vert(p,n,0,0),vert(q,n,1,0),vert(q+z,n,1,1),vert(p,n,0,0),vert(q+z,n,1,1),vert(p+z,n,0,1),vert(vector_origin,-z,0,0),vert(q,-z,0,0),vert(p,-z,0,0),vert(z,z,0,0),vert(p+z,z,0,0),vert(q+z,z,0,0)}) do t[#t+1]=v end
 end
 rod=Mesh() rod:BuildFromTriangles(t) return rod
end
local function link(e,a,b,r)
 local p=e:LocalToWorld(a) local q=e:LocalToWorld(b) local dir=q-p
 local matrix=Matrix() matrix:SetTranslation(p) local ang=dir:Angle() ang:RotateAroundAxis(ang:Right(),-90) matrix:SetAngles(ang) matrix:SetScale(Vector(r,r,dir:Length()))
 render.SetMaterial(metal) cam.PushModelMatrix(matrix) rodMesh():Draw() cam.PopModelMatrix()
end
function ENT:DrawMechanism(open)
 local eye=C.Ease(open/.35)
 if eye<.005 then return end
 local shoulder=Vector(5,0,43)
 local elbow=shoulder+Vector(0,0,25*eye)
 local head=elbow+Vector(5,0,14*eye)
 link(self,shoulder,elbow,.9) link(self,elbow,head,.6)
 local scanner=self:ClientModel('scanner','models/combine_scanner.mdl')
 if IsValid(scanner) then
  local wp=self:LocalToWorld(head)
  local target=IsValid(self:GetOperator()) and self:GetOperator():EyePos() or self:LocalToWorld(Vector(150,0,65))
  local desired=self:WorldToLocalAngles((target-wp):Angle())
  desired.p=math.Clamp(desired.p,-25,25) desired.y=math.Clamp(math.AngleDifference(desired.y,0),-30,30) desired.r=0
  self.CFScannerAngle=LerpAngle(math.min(FrameTime()*5,1),self.CFScannerAngle or desired,desired)
  scanner:SetModelScale(.095,0) scanner:SetPos(wp) scanner:SetAngles(self:LocalToWorldAngles(self.CFScannerAngle)) scanner:SetupBones() scanner:DrawModel()
 end
 local panel=C.Panel(self)
 -- Flush screen frame belongs to the machine; no separate console model.
 local fp=C.FramePosition(self)
 render.SetMaterial(metal)
 local function box(offset,lo,hi)
  render.DrawBox(self:LocalToWorld(fp+offset),self:GetAngles(),lo,hi,Color(255,255,255))
 end
 box(vector_origin,Vector(-2,-16,-10.5),Vector(1,16,10.5))
 box(vector_origin,Vector(1,-16,-10.5),Vector(1.6,-14.5,10.5))
 box(vector_origin,Vector(1,14.5,-10.5),Vector(1.6,16,10.5))
 box(vector_origin,Vector(1,-14.5,9.1),Vector(1.6,14.5,10.5))
 box(vector_origin,Vector(1,-14.5,-10.5),Vector(1.6,14.5,-9.1))
 if panel>.01 then
  local bottom=Vector(10,0,51) local top=bottom+Vector(0,0,27*panel)
  link(self,bottom+Vector(0,-10,0),top+Vector(0,-10,0),.65)
  link(self,bottom+Vector(0,10,0),top+Vector(0,10,0),.65)
  link(self,top+Vector(0,-11,0),top+Vector(0,11,0),1.25)
  for i=0,18 do
   local y=-9+i
   link(self,bottom+Vector(0,y,0),top+Vector(0,y,0),.16)
  end
 end
 local tray=C.Tray(self)
 local trayPos=Vector(27-8*(1-tray),0,26)
 render.SetMaterial(metal)
 render.DrawBox(self:LocalToWorld(trayPos),self:GetAngles(),Vector(-3,-11,-3),Vector(0,11,3),Color(255,255,255))
 link(self,Vector(19,-10,24),trayPos+Vector(-1,-10,-2),.45)
 link(self,Vector(19,10,24),trayPos+Vector(-1,10,-2),.45)
 local state=self:GetStage()
 if state==S.DEPOSIT or state==S.PRINT then
  local t=CurTime()-self:GetStageStarted()
  local intensity=state==S.PRINT and (.45+.15*math.sin(t*8)) or .3
  local phase=state==S.PRINT and C.Ease(t/.65) or C.Tray(self)
  local matrix=Matrix() matrix:SetTranslation(self:LocalToWorld(Vector(18,0,55))) matrix:SetAngles(self:LocalToWorldAngles(Angle(0,90,0))) matrix:SetScale(Vector(phase,1,phase))
  render.SetMaterial(beam) render.SetBlend(intensity)
  cam.PushModelMatrix(matrix) C.GetResinCoilMesh():Draw() cam.PopModelMatrix()
  render.SetBlend(1)
 end
end
local coil
function C.GetResinCoilMesh()
 if coil then return coil end
 local tris={}
 for ring=1,8 do
  local radius=2+ring*.65 local y=ring*1.2
  for j=0,31 do
   local a=j*math.pi/16 local b=(j+1)*math.pi/16
   local function v(t,r,u) return {pos=Vector(math.cos(t)*r,y,math.sin(t)*r),normal=Vector(0,-1,0),u=u,v=0,color=Color(52,177,171)} end
   for _,p in ipairs({v(a,radius-.08,0),v(b,radius-.08,1),v(b,radius+.08,1),v(a,radius-.08,0),v(b,radius+.08,1),v(a,radius+.08,0)}) do tris[#tris+1]=p end
  end
 end
 coil=Mesh() coil:BuildFromTriangles(tris) return coil
end
hook.Add('ShutDown','CFReworkFreeGeometry',function()
 if cache then for _,group in pairs(cache) do for _,p in ipairs(group) do p.mesh:Destroy() end end end
 if rod then rod:Destroy() end
 if coil then coil:Destroy() end
end)
