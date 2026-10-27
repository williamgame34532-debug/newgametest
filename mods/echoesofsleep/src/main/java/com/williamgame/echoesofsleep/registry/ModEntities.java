package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.*;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, EchoesOfSleep.MODID);

    public static final RegistryObject<EntityType<EchoDoppelganger>> ECHO_DOPPELGANGER = ENTITIES.register("echo_doppelganger",
            () -> EntityType.Builder.of(EchoDoppelganger::new, MobCategory.MONSTER).sized(0.6F, 2.3F).eyeHeight(2.05F)
                    .clientTrackingRange(10).build(EchoesOfSleep.id("echo_doppelganger").toString()));
    public static final RegistryObject<EntityType<Stitcher>> STITCHER = ENTITIES.register("stitcher",
            () -> EntityType.Builder.of(Stitcher::new, MobCategory.MONSTER).sized(1.1F, 2.9F).eyeHeight(2.55F)
                    .clientTrackingRange(10).build(EchoesOfSleep.id("stitcher").toString()));
    public static final RegistryObject<EntityType<Sleepless>> SLEEPLESS = ENTITIES.register("sleepless",
            () -> EntityType.Builder.of(Sleepless::new, MobCategory.MONSTER).sized(0.7F, 3.9F).eyeHeight(3.6F)
                    .clientTrackingRange(12).build(EchoesOfSleep.id("sleepless").toString()));
    public static final RegistryObject<EntityType<HollowVillager>> HOLLOW_VILLAGER = ENTITIES.register("hollow_villager",
            () -> EntityType.Builder.of(HollowVillager::new, MobCategory.MONSTER).sized(0.6F, 1.95F).eyeHeight(1.62F)
                    .clientTrackingRange(10).build(EchoesOfSleep.id("hollow_villager").toString()));
    public static final RegistryObject<EntityType<DeepMother>> DEEP_MOTHER = ENTITIES.register("deep_mother",
            () -> EntityType.Builder.of(DeepMother::new, MobCategory.MONSTER).sized(2.2F, 5.2F).eyeHeight(4.6F)
                    .fireImmune().clientTrackingRange(12).build(EchoesOfSleep.id("deep_mother").toString()));
    public static final RegistryObject<EntityType<MotherHand>> MOTHER_HAND = ENTITIES.register("mother_hand",
            () -> EntityType.Builder.of(MotherHand::new, MobCategory.MONSTER).sized(1.3F, 3.2F).eyeHeight(2.8F)
                    .fireImmune().noSave().clientTrackingRange(10).build(EchoesOfSleep.id("mother_hand").toString()));
    public static final RegistryObject<EntityType<TheDreamer>> THE_DREAMER = ENTITIES.register("the_dreamer",
            () -> EntityType.Builder.of(TheDreamer::new, MobCategory.MONSTER).sized(2.1F, 5.7F).eyeHeight(4.95F)
                    .fireImmune().clientTrackingRange(16).build(EchoesOfSleep.id("the_dreamer").toString()));
    public static final RegistryObject<EntityType<RealityFragment>> REALITY_FRAGMENT = ENTITIES.register("reality_fragment",
            () -> EntityType.Builder.<RealityFragment>of(RealityFragment::new, MobCategory.MISC).sized(0.98F, 0.98F)
                    .noSave().clientTrackingRange(8).updateInterval(2).build(EchoesOfSleep.id("reality_fragment").toString()));

    public static void attributes(EntityAttributeCreationEvent event) {
        event.put(ECHO_DOPPELGANGER.get(), EchoDoppelganger.createAttributes().build());
        event.put(STITCHER.get(), Stitcher.createAttributes().build());
        event.put(SLEEPLESS.get(), Sleepless.createAttributes().build());
        event.put(HOLLOW_VILLAGER.get(), HollowVillager.createAttributes().build());
        event.put(DEEP_MOTHER.get(), DeepMother.createAttributes().build());
        event.put(MOTHER_HAND.get(), MotherHand.createAttributes().build());
        event.put(THE_DREAMER.get(), TheDreamer.createAttributes().build());
    }
}
