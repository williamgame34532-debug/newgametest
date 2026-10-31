// combine_health_charger_vr_pad.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/charger_pad.mdl"
$cdmaterials "models/hla/health_station/"
$scale 1.25
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "hand_attach" "test_screen_ext" 4.3952 5.8800 0.6353 rotate -0.000 -180.000 90.000

$collisionmodel "phys.smd"
{
	$mass 20.0

}

$sequence "combine_health_charger_vr_pad_anim" "anims/combine_health_charger_vr_pad_anim.smd" fps 30
$sequence "step01" "anims/step01.smd" fps 30
$sequence "step02" "anims/step02.smd" fps 30
$sequence "retract" "anims/retract.smd" fps 30
// stop poses: one frame of an animation, so prop_dynamic holds it instead of replaying the animation
$sequence "rest" "anims/retract.smd" frame 50 50 fps 30 loop
$sequence "extended" "anims/step02.smd" frame 20 20 fps 30 loop
