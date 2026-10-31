// health_vial_hologram.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/vial_hologram.mdl"
$cdmaterials "models/hla/health_station/"
$staticprop
$scale 1.25
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "attach_fx" "root" 0.0000 0.0000 -0.4000 rotate 89.985 0.000 -0.000

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "idle" "ref_00.smd" fps 30
