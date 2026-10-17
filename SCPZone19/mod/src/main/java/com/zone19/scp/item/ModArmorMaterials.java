package com.zone19.scp.item;

import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.Ingredient;

/** Names map to textures/models/armor/<name>_layer_1.png in the scpzone19 namespace. */
public enum ModArmorMaterials implements ArmorMaterial {
    GASMASK("scpzone19:gasmask", 1, 0.0F, SoundEvents.ARMOR_EQUIP_LEATHER),
    TACTICAL("scpzone19:tactical", 7, 1.5F, SoundEvents.ARMOR_EQUIP_IRON);

    private final String name;
    private final int defense;
    private final float toughness;
    private final SoundEvent sound;

    ModArmorMaterials(String name, int defense, float toughness, SoundEvent sound) {
        this.name = name;
        this.defense = defense;
        this.toughness = toughness;
        this.sound = sound;
    }

    @Override
    public int getDurabilityForType(ArmorItem.Type type) {
        return 300;
    }

    @Override
    public int getDefenseForType(ArmorItem.Type type) {
        return defense;
    }

    @Override
    public int getEnchantmentValue() {
        return 8;
    }

    @Override
    public SoundEvent getEquipSound() {
        return sound;
    }

    @Override
    public Ingredient getRepairIngredient() {
        return Ingredient.of(Items.IRON_INGOT);
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public float getToughness() {
        return toughness;
    }

    @Override
    public float getKnockbackResistance() {
        return 0.0F;
    }
}
