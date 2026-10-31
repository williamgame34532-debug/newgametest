local C=CFRework
function C.Ease(x) x=math.Clamp(x,0,1) return x*x*(3-2*x) end
function C.Motion(e,t)
 local from=e:GetMotionFrom() local target=e:GetMotionTo()
 return from+(target-from)*C.Ease(((t or CurTime())-e:GetMotionStarted())/2.8)
end
function C.Tray(e,t)
 local from=e:GetTrayFrom() local target=e:GetTrayTo()
 return from+(target-from)*C.Ease(((t or CurTime())-e:GetTrayStarted())/.85)
end
function C.Panel(e) return C.Ease((C.Motion(e)-.24)/.76) end
function C.FramePosition(e)
 return C.FramePos+Vector(0,0,-6*(1-C.Panel(e)))
end
function C.ScreenTransform(e)
 local p=C.ScreenPos+Vector(0,0,-6*(1-C.Panel(e)))
 return e:LocalToWorld(p),e:LocalToWorldAngles(C.ScreenAng)
end
function C.SlotPosition(e,i)
 return C.Slots[i]+Vector(-8*(1-C.Tray(e)),0,0)
end
