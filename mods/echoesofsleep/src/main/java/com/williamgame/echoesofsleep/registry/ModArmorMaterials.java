package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.Util;
import net.minecraft.core.registries.Registries;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.RegistryObject;

import java.util.EnumMap;
import java.util.List;
import java.util.function.Supplier;

public class ModArmorMaterials {
    public static final DeferredRegister<ArmorMaterial> ARMOR_MATERIALS = DeferredRegister.create(Registries.ARMOR_MATERIAL, EchoesOfSleep.MODID);

    /** Dreamcatcher: night vision during a Distortion, nightmares glow. */
    public static final RegistryObject<ArmorMaterial> DREAMCATCHER = ARMOR_MATERIALS.register("dreamcatcher",
            () -> make("dreamcatcher", 3, 6, 8, 3, 18, 2.5F, 0.0F, () -> Ingredient.of(ModItems.DREAM_SHARD.get())));
    /** Wakeful: -30% damage from nightmares. */
    public static final RegistryObject<ArmorMaterial> WAKEFUL = ARMOR_MATERIALS.register("wakeful",
            () -> make("wakeful", 3, 7, 8, 3, 15, 3.0F, 0.05F, () -> Ingredient.of(ModItems.DAWN_INGOT.get())));
    /** Nightmare Eater: heals on nightmare kill, dash on sneak + jump. */
    public static final RegistryObject<ArmorMaterial> NIGHTMARE_EATER = ARMOR_MATERIALS.register("nightmare_eater",
            () -> make("nightmare_eater", 4, 7, 9, 4, 20, 3.5F, 0.1F, () -> Ingredient.of(ModItems.NIGHTMARE_HEART.get())));

    private static ArmorMaterial make(String name, int boots, int legs, int chest, int helmet, int enchant,
                                      float toughness, float knockback, Supplier<Ingredient> repair) {
        return new ArmorMaterial(
                Util.make(new EnumMap<>(ArmorItem.Type.class), m -> {
                    m.put(ArmorItem.Type.BOOTS, boots);
                    m.put(ArmorItem.Type.LEGGINGS, legs);
                    m.put(ArmorItem.Type.CHESTPLATE, chest);
                    m.put(ArmorItem.Type.HELMET, helmet);
                    m.put(ArmorItem.Type.BODY, chest + 3);
                }),
                enchant, SoundEvents.ARMOR_EQUIP_NETHERITE, repair,
                List.of(new ArmorMaterial.Layer(EchoesOfSleep.id(name))), toughness, knockback);
    }
}
