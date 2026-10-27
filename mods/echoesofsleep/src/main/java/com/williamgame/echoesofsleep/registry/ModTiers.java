package com.williamgame.echoesofsleep.registry;

import net.minecraft.tags.BlockTags;
import net.minecraft.tags.TagKey;
import net.minecraft.world.item.Tier;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.level.block.Block;

public class ModTiers {
    /** Dawn: a little better than netherite. */
    public static final Tier DAWN = new Tier() {
        @Override public int getUses() { return 2200; }
        @Override public float getSpeed() { return 9.5F; }
        @Override public float getAttackDamageBonus() { return 4.0F; }
        @Override public TagKey<Block> getIncorrectBlocksForDrops() { return BlockTags.INCORRECT_FOR_NETHERITE_TOOL; }
        @Override public int getEnchantmentValue() { return 18; }
        @Override public Ingredient getRepairIngredient() { return Ingredient.of(ModItems.DAWN_INGOT.get()); }
    };

    /** Echo: forged from nightmare shards. */
    public static final Tier ECHO = new Tier() {
        @Override public int getUses() { return 1900; }
        @Override public float getSpeed() { return 8.0F; }
        @Override public float getAttackDamageBonus() { return 4.5F; }
        @Override public TagKey<Block> getIncorrectBlocksForDrops() { return BlockTags.INCORRECT_FOR_NETHERITE_TOOL; }
        @Override public int getEnchantmentValue() { return 20; }
        @Override public Ingredient getRepairIngredient() { return Ingredient.of(ModItems.DREAM_SHARD.get()); }
    };
}
