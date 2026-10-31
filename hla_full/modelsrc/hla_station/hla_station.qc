// Combine fabricator from Half-Life: Alyx, converted for Garry's Mod (skeleton and animations kept).
$modelname "cf_rework/hla_station.mdl"
$cdmaterials "models/cf_rework/hla/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 30

$model "part00" "ref_00.smd"
$model "part01" "ref_01.smd"
$model "part02" "ref_02.smd"
$model "part03" "ref_03.smd"
$model "part04" "ref_04.smd"
$model "part05" "ref_05.smd"
$model "part06" "ref_06.smd"

$attachment "eyes" "joint28" 0.0000 0.0000 0.0000 rotate -0.000 180.000 90.000
$attachment "hacking_point_attach" "hacking_point" 0.0000 0.0000 0.0000 rotate -89.972 0.000 0.000
$attachment "resin_trigger_attach" "station_root" -12.0000 -25.0000 48.0000 rotate -0.000 0.000 0.000
$attachment "resin_attach_00" "trough4" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_01" "trough2" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_02" "trough9" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_03" "trough11" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_04" "trough13" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_05" "trough6" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_06" "trough14" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_07" "trough10" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_08" "trough12" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "resin_attach_09" "trough7" 0.0000 0.0000 5.0000 rotate -0.000 180.000 180.000
$attachment "item_attach" "print_rooter" -14.0000 8.0000 0.0000 rotate 0.000 0.000 -90.000
$attachment "main_panel" "panoramam_bone1" 0.8600 0.0000 0.0000 rotate -0.000 90.000 90.000
$attachment "main_panel_bg" "panoramam_bone1" 0.7000 0.0000 0.0000 rotate -0.000 90.000 90.000
$attachment "movie_panel" "panoramam_bone1" 0.5000 0.0000 0.0000 rotate -0.000 90.000 90.000
$attachment "main_panel_fill" "panoramam_bone1" 0.4500 0.0000 0.0000 rotate -0.000 90.000 90.000
$attachment "snd_interface" "mon_drawer5" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_chamber_door" "print_bed_door" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_print_door" "print_hatcher" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "snd_resin_tray" "trough_carosel" 0.0000 0.0000 0.0000 rotate -0.000 0.000 0.000
$attachment "cable_spot" "station_root" 11.6770 24.3650 -0.3987 rotate -0.000 0.000 0.000
$attachment "cable_spot1" "station_root" 11.6770 19.8930 -3.0710 rotate -0.000 0.000 0.000
$attachment "cable_spot2" "station_root" 9.4599 18.6011 -27.4163 rotate -0.000 0.000 0.000
$attachment "cable_spot3" "station_root" 9.4599 23.9844 -31.0314 rotate -0.000 0.000 0.000
$attachment "cable_spot4" "station_root" 10.3228 29.7868 4.2337 rotate -0.000 0.000 0.000
$attachment "cable_spot5" "station_root" 10.0486 30.3656 7.2995 rotate -0.000 0.000 0.000
$attachment "cable_spot6" "station_root" 10.0486 34.6977 13.8197 rotate -0.000 0.000 0.000
$attachment "cable_spot7" "station_root" 10.0486 34.6977 23.7903 rotate -0.000 0.000 0.000
$attachment "cable_spot8" "station_root" 9.1773 25.0148 18.6129 rotate -0.000 0.000 0.000
$attachment "cable_spot9" "station_root" 10.0486 25.1773 12.3857 rotate -0.000 0.000 0.000
$attachment "cable_spot10" "station_root" 9.1773 25.0148 21.8757 rotate -0.000 0.000 0.000
$attachment "cable_spot11" "station_root" 9.1773 21.8630 20.5047 rotate -0.000 0.000 0.000
$attachment "cable_spot12" "station_root" 9.1773 21.8630 14.1601 rotate -0.000 0.000 0.000
$attachment "cable_spot13" "station_root" 9.1773 24.5630 -0.3540 rotate -0.000 0.000 0.000
$attachment "cable_spot14" "station_root" 9.1773 11.2345 10.1803 rotate -0.000 0.000 0.000
$attachment "holo_model_attach_point" "base_attach_bone" -6.7968 57.1170 -7.0755 rotate 89.972 0.000 0.000
$attachment "glow0" "print_rooter" -15.0000 6.0000 5.0000 rotate -0.000 0.000 0.000
$attachment "glow1" "print_rooter" -15.0000 6.0000 -5.0000 rotate -0.000 0.000 0.000
$attachment "glow2" "panoramam_bone1" 0.0000 10.0000 5.0000 rotate -0.000 0.000 0.000

$collisionmodel "phys.smd"
{
	$mass 400
}

$sequence "dormant" "anims/dormant.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "eye_deploy" "anims/eye_deploy.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "interface_deploy" "anims/interface_deploy.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "menu_idle" "anims/menu_idle.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "interface_retract" "anims/interface_retract.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "eye_retract" "anims/eye_retract.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "hatch_open" "anims/hatch_open.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "hatch_close" "anims/hatch_close.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "hatch_idle" "anims/hatch_idle.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_deploy" "anims/tray_deploy.smd" fps 30 fadein 0.35 fadeout 0.35
$sequence "tray_retract" "anims/tray_retract.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "tray_idle_00" "anims/tray_idle_00.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_01" "anims/tray_idle_01.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_02" "anims/tray_idle_02.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_03" "anims/tray_idle_03.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_04" "anims/tray_idle_04.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_05" "anims/tray_idle_05.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_06" "anims/tray_idle_06.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_07" "anims/tray_idle_07.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_08" "anims/tray_idle_08.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_idle_09" "anims/tray_idle_09.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "tray_cycle_01" "anims/tray_cycle_01.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_02" "anims/tray_cycle_02.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_03" "anims/tray_cycle_03.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_04" "anims/tray_cycle_04.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_05" "anims/tray_cycle_05.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_06" "anims/tray_cycle_06.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_07" "anims/tray_cycle_07.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_08" "anims/tray_cycle_08.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_09" "anims/tray_cycle_09.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "tray_cycle_00" "anims/tray_cycle_00.smd" fps 30 fadein 0.10 fadeout 0.10
$sequence "bay_open" "anims/bay_open.smd" fps 30 fadein 0.35 fadeout 0.35
$sequence "bay_close" "anims/bay_close.smd" fps 30 fadein 0.20 fadeout 0.20
$sequence "bay_idle" "anims/bay_idle.smd" fps 30 loop fadein 0.20 fadeout 0.20
$sequence "print" "anims/print.smd" fps 60 fadein 0.20 fadeout 0.20
$sequence "print_done" "anims/print_done.smd" fps 30 loop fadein 0.20 fadeout 0.20
