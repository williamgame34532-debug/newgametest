// combine_monitor_small.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/terminal/combine_monitor_small.mdl"
$cdmaterials "models/hla/terminal/"
$surfaceprop "metal"

$model "part00" "ref_00.smd"


// the corners of the screen plane (the terminal draws its screen between them)
$attachment "screen_tl" "root" 7.7250 16.1390 5.2550
$attachment "screen_tr" "root" -5.7030 19.4490 5.2550
$attachment "screen_bl" "root" 7.7250 16.1390 -7.6290

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "idle" "ref_00.smd" fps 30
