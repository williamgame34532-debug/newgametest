package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.sounds.SoundEvent;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public class ModSounds {
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, EchoesOfSleep.MODID);

    public static final RegistryObject<SoundEvent> WHISPER = reg("ambient.whisper");
    public static final RegistryObject<SoundEvent> HEARTBEAT = reg("ambient.heartbeat");
    public static final RegistryObject<SoundEvent> DRONE = reg("ambient.drone");
    public static final RegistryObject<SoundEvent> FOOTSTEPS = reg("ambient.footsteps");
    public static final RegistryObject<SoundEvent> WAKE_SCREAM = reg("event.wake_scream");
    public static final RegistryObject<SoundEvent> GLITCH = reg("event.glitch");
    public static final RegistryObject<SoundEvent> CREAK = reg("event.creak");

    public static final RegistryObject<SoundEvent> DOPPEL_AMBIENT = reg("entity.echo_doppelganger.ambient");
    public static final RegistryObject<SoundEvent> DOPPEL_HURT = reg("entity.echo_doppelganger.hurt");
    public static final RegistryObject<SoundEvent> DOPPEL_DEATH = reg("entity.echo_doppelganger.death");
    public static final RegistryObject<SoundEvent> DOPPEL_SCREAM = reg("entity.echo_doppelganger.scream");

    public static final RegistryObject<SoundEvent> STITCHER_AMBIENT = reg("entity.stitcher.ambient");
    public static final RegistryObject<SoundEvent> STITCHER_HURT = reg("entity.stitcher.hurt");
    public static final RegistryObject<SoundEvent> STITCHER_DEATH = reg("entity.stitcher.death");

    public static final RegistryObject<SoundEvent> SLEEPLESS_AMBIENT = reg("entity.sleepless.ambient");
    public static final RegistryObject<SoundEvent> SLEEPLESS_HURT = reg("entity.sleepless.hurt");
    public static final RegistryObject<SoundEvent> SLEEPLESS_DEATH = reg("entity.sleepless.death");
    public static final RegistryObject<SoundEvent> SLEEPLESS_STING = reg("entity.sleepless.sting");

    public static final RegistryObject<SoundEvent> HOLLOW_AMBIENT = reg("entity.hollow_villager.ambient");
    public static final RegistryObject<SoundEvent> HOLLOW_HURT = reg("entity.hollow_villager.hurt");
    public static final RegistryObject<SoundEvent> HOLLOW_DEATH = reg("entity.hollow_villager.death");

    public static final RegistryObject<SoundEvent> MOTHER_AMBIENT = reg("entity.deep_mother.ambient");
    public static final RegistryObject<SoundEvent> MOTHER_HURT = reg("entity.deep_mother.hurt");
    public static final RegistryObject<SoundEvent> MOTHER_DEATH = reg("entity.deep_mother.death");
    public static final RegistryObject<SoundEvent> MOTHER_EMERGE = reg("entity.deep_mother.emerge");

    public static final RegistryObject<SoundEvent> DREAMER_AMBIENT = reg("entity.the_dreamer.ambient");
    public static final RegistryObject<SoundEvent> DREAMER_HURT = reg("entity.the_dreamer.hurt");
    public static final RegistryObject<SoundEvent> DREAMER_DEATH = reg("entity.the_dreamer.death");
    public static final RegistryObject<SoundEvent> DREAMER_PULSE = reg("entity.the_dreamer.pulse");

    public static final RegistryObject<SoundEvent> LULLABY = reg("item.lullaby_staff.use");
    public static final RegistryObject<SoundEvent> GHOST_SLASH = reg("item.echo_scythe.ghost_slash");

    private static RegistryObject<SoundEvent> reg(String name) {
        return SOUNDS.register(name, () -> SoundEvent.createVariableRangeEvent(EchoesOfSleep.id(name)));
    }
}
