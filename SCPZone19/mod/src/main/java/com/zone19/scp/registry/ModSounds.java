package com.zone19.scp.registry;

import com.zone19.scp.Zone19Mod;
import net.minecraft.sounds.SoundEvent;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModSounds {
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, Zone19Mod.MODID);

    public static final RegistryObject<SoundEvent> AMBIENT = reg("ambient.zone");
    public static final RegistryObject<SoundEvent> ALARM = reg("alarm");
    public static final RegistryObject<SoundEvent> ALARM_LONG = reg("alarm.long");
    public static final RegistryObject<SoundEvent> DOOR_OPEN = reg("door.open");
    public static final RegistryObject<SoundEvent> DOOR_CLOSE = reg("door.close");
    public static final RegistryObject<SoundEvent> DOOR_BIG_OPEN = reg("door.big_open");
    public static final RegistryObject<SoundEvent> DOOR_ERROR = reg("door.error");
    public static final RegistryObject<SoundEvent> KEYCARD = reg("keycard");
    public static final RegistryObject<SoundEvent> BUTTON = reg("button");
    public static final RegistryObject<SoundEvent> PICKUP = reg("pickup");
    public static final RegistryObject<SoundEvent> GUN_PISTOL = reg("gun.pistol");
    public static final RegistryObject<SoundEvent> GUN_RIFLE = reg("gun.rifle");
    public static final RegistryObject<SoundEvent> SCP173_SNAP = reg("scp173.snap");
    public static final RegistryObject<SoundEvent> SCP173_DRAG = reg("scp173.drag");
    public static final RegistryObject<SoundEvent> SCP173_RATTLE = reg("scp173.rattle");
    public static final RegistryObject<SoundEvent> SCP096_SCREAM = reg("scp096.scream");
    public static final RegistryObject<SoundEvent> SCP096_TRIGGERED = reg("scp096.triggered");
    public static final RegistryObject<SoundEvent> SCP106_LAUGH = reg("scp106.laugh");
    public static final RegistryObject<SoundEvent> SCP106_BREATHING = reg("scp106.breathing");
    public static final RegistryObject<SoundEvent> SCP106_DECAY = reg("scp106.decay");
    public static final RegistryObject<SoundEvent> RADIO_CHATTER = reg("radio.chatter");
    public static final RegistryObject<SoundEvent> RADIO_BEEP = reg("radio.beep");
    public static final RegistryObject<SoundEvent> ANNOUNCEMENT = reg("radio.announcement");
    public static final RegistryObject<SoundEvent> MUSIC_INTRO = reg("music.intro");
    public static final RegistryObject<SoundEvent> MUSIC_HCZ = reg("music.hcz");
    public static final RegistryObject<SoundEvent> MUSIC_CHASE096 = reg("music.chase096");
    public static final RegistryObject<SoundEvent> MUSIC_106 = reg("music.scp106");
    public static final RegistryObject<SoundEvent> MUSIC_GATEB = reg("music.gateb");
    public static final RegistryObject<SoundEvent> MUSIC_MENU = reg("music.menu");

    private static RegistryObject<SoundEvent> reg(String name) {
        return SOUNDS.register(name, () -> SoundEvent.createVariableRangeEvent(Zone19Mod.id(name)));
    }

    private ModSounds() {
    }
}
