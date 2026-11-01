// combine_monitor_medium.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/terminal/combine_monitor_medium.mdl"
$cdmaterials "models/hla/terminal/"
$surfaceprop "metal"

$model "part00" "ref_00.smd"


// the corners of the screen plane (the terminal draws its screen between them)
$attachment "screen_tl" "sml_slider" 6.5119 5.0890 9.9270
$attachment "screen_tr" "sml_rotator" 13.6085 5.0890 -2.9777
$attachment "screen_bl" "sml_slider" 6.5119 -6.0530 9.9270

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "open_idle" "anims/open_idle.smd" fps 30
$sequence "open" "anims/open.smd" fps 30
$sequence "close" "anims/close.smd" fps 30
$sequence "close_idle" "anims/close_idle.smd" fps 30
