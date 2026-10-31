// health_vial.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/health_vial.mdl"
$cdmaterials "models/hla/health_station/"
$scale 1.25
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "glow_attachment" "vial_ROOT" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "vr_controller_held_right" "controller_hand_R1" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "vr_controller_held_left" "controller_hand_L" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "item_holder_l" "arm_lower_L" -1.7500 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "item_holder_r" "arm_lower_R" -1.7500 0.0000 0.0000 rotate -0.000 0.000 -180.000

$collisionmodel "phys.smd"
{
	$mass 3.0

}

$sequence "health_vial_crush_anim" "anims/health_vial_crush_anim.smd" fps 30
$sequence "health_vial_deploy_anim" "anims/health_vial_deploy_anim.smd" fps 30
$sequence "health_vial_larva_idle_1_anim" "anims/health_vial_larva_idle_1_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_2_anim" "anims/health_vial_larva_idle_2_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_3_anim" "anims/health_vial_larva_idle_3_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_4_anim" "anims/health_vial_larva_idle_4_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_5_anim" "anims/health_vial_larva_idle_5_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_6_anim" "anims/health_vial_larva_idle_6_anim.smd" fps 30 loop
$sequence "health_vial_larva_idle_7_anim" "anims/health_vial_larva_idle_7_anim.smd" fps 30 loop
$sequence "health_vial_larva_zeroer" "anims/health_vial_larva_zeroer.smd" fps 30
$sequence "health_vial_larva_flush_anim" "anims/health_vial_larva_flush_anim.smd" fps 30
$sequence "health_vial_larva_flush_finished_idle" "anims/health_vial_larva_flush_finished_idle.smd" fps 30 loop
