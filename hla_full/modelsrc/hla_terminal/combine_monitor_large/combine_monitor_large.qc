// combine_monitor_large.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/terminal/combine_monitor_large.mdl"
$cdmaterials "models/hla/terminal/"
$surfaceprop "metal"

$model "part00" "ref_00.smd"


// the corners of the screen plane (the terminal draws its screen between them)
$attachment "screen_tl" "lrg_slider" 6.4619 7.5880 9.9255
$attachment "screen_tr" "lrg_rotator" 13.5985 7.5880 -2.9878
$attachment "screen_bl" "lrg_slider" 6.4619 -9.0350 9.9254

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "open_idle" "anims/open_idle.smd" fps 30
$sequence "open" "anims/open.smd" fps 30
$sequence "close" "anims/close.smd" fps 30
$sequence "close_idle" "anims/close_idle.smd" fps 30
