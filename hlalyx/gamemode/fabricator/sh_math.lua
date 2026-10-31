-- Pure-Lua affine math shared by the geometry builder, the animation rig and the server hit tests.
-- No GMod types here on purpose: the same file runs in the offline Blender preview (LuaJIT via lupa).
-- A matrix is a flat 12-number table, row-major 3x4: {xx,xy,xz,tx, yx,yy,yz,ty, zx,zy,zz,tz}.
-- Angles follow Source: Angle(pitch,yaw,roll) = Rz(yaw) * Ry(pitch) * Rx(roll), positive pitch = nose down.
CFRework = CFRework or {}
local M = {}
CFRework.M = M

local sin, cos, rad, sqrt = math.sin, math.cos, math.rad, math.sqrt

function M.ident() return {1,0,0,0, 0,1,0,0, 0,0,1,0} end

function M.mul(a, b)
	return {
		a[1]*b[1]+a[2]*b[5]+a[3]*b[9],  a[1]*b[2]+a[2]*b[6]+a[3]*b[10],  a[1]*b[3]+a[2]*b[7]+a[3]*b[11],  a[1]*b[4]+a[2]*b[8]+a[3]*b[12]+a[4],
		a[5]*b[1]+a[6]*b[5]+a[7]*b[9],  a[5]*b[2]+a[6]*b[6]+a[7]*b[10],  a[5]*b[3]+a[6]*b[7]+a[7]*b[11],  a[5]*b[4]+a[6]*b[8]+a[7]*b[12]+a[8],
		a[9]*b[1]+a[10]*b[5]+a[11]*b[9], a[9]*b[2]+a[10]*b[6]+a[11]*b[10], a[9]*b[3]+a[10]*b[7]+a[11]*b[11], a[9]*b[4]+a[10]*b[8]+a[11]*b[12]+a[12],
	}
end

function M.T(x, y, z) return {1,0,0,x, 0,1,0,y, 0,0,1,z} end

function M.RX(d) local c, s = cos(rad(d)), sin(rad(d)) return {1,0,0,0, 0,c,-s,0, 0,s,c,0} end
function M.RY(d) local c, s = cos(rad(d)), sin(rad(d)) return {c,0,s,0, 0,1,0,0, -s,0,c,0} end
function M.RZ(d) local c, s = cos(rad(d)), sin(rad(d)) return {c,-s,0,0, s,c,0,0, 0,0,1,0} end

-- Source angle -> rotation matrix
function M.A(p, y, r) return M.mul(M.RZ(y or 0), M.mul(M.RY(p or 0), M.RX(r or 0))) end

-- translate * angle, the usual "place a part" transform
function M.TA(x, y, z, p, yw, r) return M.mul(M.T(x, y, z), M.A(p, yw, r)) end

-- rotate by angle about a pivot point
function M.pivot(px, py, pz, rotm) return M.mul(M.T(px, py, pz), M.mul(rotm, M.T(-px, -py, -pz))) end

function M.point(m, x, y, z)
	return m[1]*x+m[2]*y+m[3]*z+m[4], m[5]*x+m[6]*y+m[7]*z+m[8], m[9]*x+m[10]*y+m[11]*z+m[12]
end

function M.dir(m, x, y, z)
	return m[1]*x+m[2]*y+m[3]*z, m[5]*x+m[6]*y+m[7]*z, m[9]*x+m[10]*y+m[11]*z
end

-- matrix -> Source angles (pitch, yaw, roll) of its rotation part
function M.angles(m)
	local fx, fy, fz = m[1], m[5], m[9]
	local lx, ly, lz = m[2], m[6], m[10]
	local uz = m[11]
	local xy = sqrt(fx*fx + fy*fy)
	local p, y, r
	if xy > 0.001 then
		y = math.deg(math.atan2(fy, fx))
		p = math.deg(math.atan2(-fz, xy))
		r = math.deg(math.atan2(lz, uz))
	else
		y = math.deg(math.atan2(-lx, ly))
		p = math.deg(math.atan2(-fz, xy))
		r = 0
	end
	return p, y, r
end

function M.lerp(a, b, t) return a + (b - a) * t end
function M.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function M.smooth(x) x = M.clamp(x, 0, 1) return x*x*(3 - 2*x) end
-- normalized 0..1 slice of a timeline: rises over [a,b]
function M.span(t, a, b) return M.smooth((t - a) / (b - a)) end
-- ease with a small mechanical overshoot that settles back to exactly 1
function M.back(x)
	x = M.clamp(x, 0, 1)
	local s = 1.4
	x = x - 1
	return 1 + x*x*((s + 1)*x + s)
end
function M.overshoot(t, a, b) return M.back((t - a) / (b - a)) end
