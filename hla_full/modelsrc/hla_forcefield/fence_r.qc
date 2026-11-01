// Half-Life: Alyx combine_fence01b_128.vmdl_c (LOD 0, 22 456 triangles): the right force field emitter.
// Its inner edge (where the field starts) is at the origin.
$modelname "hla/forcefield/fence_r.mdl"
$cdmaterials "models/hla/forcefield/"
$staticprop
$surfaceprop "metal"
$model "post" "fence_r.smd"

// skins as in Half-Life: Alyx: 0 and 1 - combine_fence_hlvr (on), 2 - combine_fence_hlvr_off
$texturegroup "skinfamilies"
{
	{ "combine_fence_hlvr" }
	{ "combine_fence_hlvr" }
	{ "combine_fence_hlvr_off" }
}
$sequence "idle" "fence_r.smd" fps 30
