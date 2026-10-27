package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.Util;
import net.minecraft.core.Holder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.crafting.Ingredient;

import java.util.EnumMap;
import java.util.List;
import java.util.function.Supplier;

/**
 * Armor materials. They are registered straight into the vanilla registry the first time this class is
 * touched, which only happens inside the armor items' suppliers (i.e. during item registration, while the
 * registries are open). This avoids depending on the order in which Forge fires registry events
 * (ARMOR_MATERIAL is declared after ITEM in vanilla).
 */
public final class ModArmorMaterials {
    /** Dreamcatcher: night vision during a Distortion, nightmares glow. */
    public static final Holder<ArmorMaterial> DREAMCATCHER =
            register("dreamcatcher", 3, 6, 8, 3, 18, 2.0F, 0.0F, () -> Ingredient.of(ModItems.DREAM_SHARD.get()));
    /** Wakeful: -30% damage from nightmares. */
    public static final Holder<ArmorMaterial> WAKEFUL =
            register("wakeful", 3, 7, 8, 3, 15, 3.0F, 0.05F, () -> Ingredient.of(ModItems.DAWN_INGOT.get()));
    /** Nightmare Eater: heals on nightmare kill, dash on sneak + jump. */
    public static final Holder<ArmorMaterial> NIGHTMARE_EATER =
            register("nightmare_eater", 4, 7, 9, 4, 20, 3.5F, 0.1F, () -> Ingredient.of(ModItems.NIGHTMARE_HEART.get()));

    private ModArmorMaterials() {
    }

    private static Holder<ArmorMaterial> register(String name, int boots, int legs, int chest, int helmet, int enchant,
                                                  float toughness, float knockback, Supplier<Ingredient> repair) {
        ArmorMaterial material = new ArmorMaterial(
                Util.make(new EnumMap<>(ArmorItem.Type.class), m -> {
                    m.put(ArmorItem.Type.BOOTS, boots);
                    m.put(ArmorItem.Type.LEGGINGS, legs);
                    m.put(ArmorItem.Type.CHESTPLATE, chest);
                    m.put(ArmorItem.Type.HELMET, helmet);
                    m.put(ArmorItem.Type.BODY, chest + 3);
                }),
                enchant, SoundEvents.ARMOR_EQUIP_NETHERITE, repair,
                List.of(new ArmorMaterial.Layer(EchoesOfSleep.id(name))), toughness, knockback);
        return Registry.registerForHolder(BuiltInRegistries.ARMOR_MATERIAL, EchoesOfSleep.id(name), material);
    }
}
