// combine_health_charger_guage.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/health_station/charger_gauge.mdl"
$cdmaterials "models/hla/health_station/"
$surfaceprop "metal"

$model "part00" "ref_00.smd"

$attachment "health_vial_attach" "explod_barrel2" 0.4000 0.0000 4.0000 rotate -89.972 0.000 -90.000
$attachment "ghost_vial_attach" "explod_barrel2" 0.0000 0.0000 9.0000 rotate -89.972 0.000 -90.000

$collisionmodel "phys.smd"
{
	$mass 20.0

}

$sequence "combine_health_charger_guage_anim" "anims/combine_health_charger_guage_anim.smd" fps 30
$sequence "idle_full" "anims/idle_full.smd" fps 30
$sequence "empty" "anims/empty.smd" fps 30
$sequence "idle" "anims/idle.smd" fps 30
$sequence "combine_health_charger_guage_explode" "anims/combine_health_charger_guage_explode.smd" fps 30
$sequence "unlocking_anim" "anims/unlocking_anim.smd" fps 30
$sequence "panel_open_anim" "anims/panel_open_anim.smd" fps 30
$sequence "explode_pull" "anims/explode_pull.smd" fps 30
$sequence "explode_tickle" "anims/explode_tickle.smd" fps 30
$sequence "explode_expand" "anims/explode_expand.smd" fps 30
$sequence "idle_hacking" "anims/idle_hacking.smd" fps 30 loop
