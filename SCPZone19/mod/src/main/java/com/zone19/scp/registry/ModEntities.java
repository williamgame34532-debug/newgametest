package com.zone19.scp.registry;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.entity.Scp0492Entity;
import com.zone19.scp.entity.Scp096Entity;
import com.zone19.scp.entity.Scp106Entity;
import com.zone19.scp.entity.Scp173Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, Zone19Mod.MODID);

    public static final RegistryObject<EntityType<Scp173Entity>> SCP173 = ENTITIES.register("scp173",
            () -> EntityType.Builder.of(Scp173Entity::new, MobCategory.MONSTER).sized(0.8F, 2.4F)
                    .clientTrackingRange(10).build(Zone19Mod.id("scp173").toString()));
    public static final RegistryObject<EntityType<Scp096Entity>> SCP096 = ENTITIES.register("scp096",
            () -> EntityType.Builder.of(Scp096Entity::new, MobCategory.MONSTER).sized(0.6F, 2.5F)
                    .clientTrackingRange(10).build(Zone19Mod.id("scp096").toString()));
    public static final RegistryObject<EntityType<Scp106Entity>> SCP106 = ENTITIES.register("scp106",
            () -> EntityType.Builder.of(Scp106Entity::new, MobCategory.MONSTER).sized(0.6F, 1.95F)
                    .fireImmune().clientTrackingRange(10).build(Zone19Mod.id("scp106").toString()));
    public static final RegistryObject<EntityType<Scp0492Entity>> SCP049_2 = ENTITIES.register("scp049_2",
            () -> EntityType.Builder.of(Scp0492Entity::new, MobCategory.MONSTER).sized(0.6F, 1.95F)
                    .clientTrackingRange(8).build(Zone19Mod.id("scp049_2").toString()));

    public static void onAttributes(EntityAttributeCreationEvent event) {
        event.put(SCP173.get(), Scp173Entity.createAttributes().build());
        event.put(SCP096.get(), Scp096Entity.createAttributes().build());
        event.put(SCP106.get(), Scp106Entity.createAttributes().build());
        event.put(SCP049_2.get(), Scp0492Entity.createAttributes().build());
    }

    private ModEntities() {
    }
}
