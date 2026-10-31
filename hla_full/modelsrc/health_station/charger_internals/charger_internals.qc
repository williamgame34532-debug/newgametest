// combine_health_charger_internals.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/charger_internals.mdl"
$cdmaterials "models/hla/health_station/"
$scale 1.25
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "snd_needle_01" "pin_tip1" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_02" "pin_tip" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_03" "pin_tip2" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_04" "pin_tip3" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_05" "pin_tip4" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_06" "pin_tip5" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_needle_07" "pin_tip6" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "combine_health_charger_internal_anims" "anims/combine_health_charger_internal_anims.smd" fps 30
$sequence "inject_loop" "anims/inject_loop.smd" fps 40 loop
$sequence "retract" "anims/retract.smd" fps 30
$sequence "prepare_inject" "anims/prepare_inject.smd" fps 35
$sequence "hand_pin" "anims/hand_pin.smd" fps 30
$sequence "idle_retracted" "anims/idle_retracted.smd" fps 30
$sequence "idle_deployed_base" "anims/idle_deployed_base.smd" fps 30
$sequence "idle_deployed" "anims/idle_deployed.smd" fps 30 loop
$sequence "idle_retracted_noblend" "anims/idle_retracted_noblend.smd" fps 30
// stop poses: one frame of an animation, so prop_dynamic holds it instead of replaying the animation
$sequence "rest" "anims/retract.smd" frame 25 25 fps 30 loop
$sequence "armed" "anims/prepare_inject.smd" frame 30 30 fps 30 loop
