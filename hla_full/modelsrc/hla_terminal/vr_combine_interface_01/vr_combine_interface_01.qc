// vr_combine_interface_01.vmdl_c, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)
$modelname "hla/terminal/vr_combine_interface_01.mdl"
$cdmaterials "models/hla/terminal/"
$surfaceprop "metal"

$model "part00" "ref_00.smd"
$model "part01" "ref_01.smd"

$attachment "player_button_attach" "button_attacher_bone" 0.0000 0.0000 0.0000 rotate -0.000 180.000 180.000
$attachment "hacking_point_attach" "interact_bone1" -1.0000 0.0000 0.0000 rotate -28.000 90.000 180.000
$attachment "fingers" "vr_combine_interface" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_main_panel" "joint48" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_goal_arm" "goal_arm04" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
// the screen at the top of the panel in closed_idle: corners for the interface (hlalyx terminal)
$attachment "screen_tl" "vr_combine_interface" 11.9100 -8.3700 47.6000 rotate 0 0 0
$attachment "screen_tr" "vr_combine_interface" 11.9200 10.2800 47.6100 rotate 0 0 0
$attachment "screen_bl" "vr_combine_interface" 17.4200 -8.3700 42.5600 rotate 0 0 0
$attachment "_key_attach" "part_spinner" 1.3532 0.0000 0.0000 rotate 0.000 0.000 -0.000

$collisionmodel "phys.smd"
{
	$mass 50.0

}

$sequence "closed_idle" "anims/closed_idle.smd" fps 30
$sequence "open_anim" "anims/open_anim.smd" fps 30
$sequence "close_anim" "anims/close_anim.smd" fps 30
$sequence "extend_panel" "anims/extend_panel.smd" fps 30
$sequence "retract_panel1" "anims/retract_panel1.smd" fps 30
