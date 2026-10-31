// combine_health_charger_vr.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/charger.mdl"
$cdmaterials "models/hla/health_station/"
$scale 1.25
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "screen_attach" "test_screen02" 0.0000 0.0000 0.0000 rotate -89.972 0.000 -90.000
$attachment "drain_attach" "test_HEALTH_CHARGER001" 0.0000 0.0000 -12.0000 rotate -0.000 0.000 0.000
$attachment "glow_attach" "test_HEALTH_CHARGER001" 12.0000 -5.0000 3.5000 rotate -0.000 0.000 0.000

$collisionmodel "phys.smd"
{
	$mass 200.0

}

$sequence "deploy" "anims/deploy.smd" fps 30
$sequence "prepare_inject" "anims/prepare_inject.smd" fps 30
$sequence "idle" "anims/idle.smd" fps 30
$sequence "inject" "anims/inject.smd" fps 30
$sequence "inject_loop" "anims/inject_loop.smd" fps 30 loop
$sequence "retract" "anims/retract.smd" fps 30
// stop poses: one frame of an animation, so prop_dynamic holds it instead of replaying the animation
$sequence "deployed" "anims/deploy.smd" frame 100 100 fps 30 loop
