package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.item.*;
import net.minecraft.core.Holder;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.item.SwordItem;
import net.minecraft.world.level.block.Block;
import net.minecraftforge.common.ForgeSpawnEggItem;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;

public class ModItems {
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, EchoesOfSleep.MODID);
    /** Everything in creative-tab order. */
    public static final List<RegistryObject<? extends Item>> TAB_ORDER = new ArrayList<>();

    // Materials
    public static final RegistryObject<Item> DREAM_SHARD = add(ITEMS.register("dream_shard",
            () -> new LoreItem(new Item.Properties().rarity(Rarity.UNCOMMON), "dream_shard", false)));
    public static final RegistryObject<Item> DAWN_INGOT = add(ITEMS.register("dawn_ingot",
            () -> new LoreItem(new Item.Properties().rarity(Rarity.RARE), "dawn_ingot", false)));
    public static final RegistryObject<Item> NIGHTMARE_HEART = add(ITEMS.register("nightmare_heart",
            () -> new LoreItem(new Item.Properties().rarity(Rarity.EPIC).fireResistant(), "nightmare_heart", true)));

    // Consumables / special
    public static final RegistryObject<Item> DAWN_TINCTURE = add(ITEMS.register("dawn_tincture",
            () -> new DawnTinctureItem(new Item.Properties().stacksTo(16).rarity(Rarity.UNCOMMON))));
    public static final RegistryObject<Item> DREAM_TOTEM = add(ITEMS.register("dream_totem",
            () -> new DreamTotemItem(new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).fireResistant())));

    // Weapons
    public static final RegistryObject<Item> DAWN_BLADE = add(ITEMS.register("dawn_blade",
            () -> new DawnBladeItem(ModTiers.DAWN, new Item.Properties()
                    .attributes(SwordItem.createAttributes(ModTiers.DAWN, 4, -2.3F)).rarity(Rarity.RARE).fireResistant())));
    public static final RegistryObject<Item> ECHO_SCYTHE = add(ITEMS.register("echo_scythe",
            () -> new EchoScytheItem(ModTiers.ECHO, new Item.Properties()
                    .attributes(SwordItem.createAttributes(ModTiers.ECHO, 6, -2.9F)).rarity(Rarity.EPIC).fireResistant())));
    public static final RegistryObject<Item> LULLABY_STAFF = add(ITEMS.register("lullaby_staff",
            () -> new LullabyStaffItem(new Item.Properties().durability(320).rarity(Rarity.RARE))));
    public static final RegistryObject<Item> INSOMNIA_LANTERN = add(ITEMS.register("insomnia_lantern",
            () -> new InsomniaLanternItem(new Item.Properties().stacksTo(1).rarity(Rarity.RARE))));

    // Armor
    public static final RegistryObject<Item> DREAMCATCHER_HELMET = armor("dreamcatcher_helmet", () -> ModArmorMaterials.DREAMCATCHER, ArmorItem.Type.HELMET, 35, ArmorSet.DREAMCATCHER);
    public static final RegistryObject<Item> DREAMCATCHER_CHESTPLATE = armor("dreamcatcher_chestplate", () -> ModArmorMaterials.DREAMCATCHER, ArmorItem.Type.CHESTPLATE, 35, ArmorSet.DREAMCATCHER);
    public static final RegistryObject<Item> DREAMCATCHER_LEGGINGS = armor("dreamcatcher_leggings", () -> ModArmorMaterials.DREAMCATCHER, ArmorItem.Type.LEGGINGS, 35, ArmorSet.DREAMCATCHER);
    public static final RegistryObject<Item> DREAMCATCHER_BOOTS = armor("dreamcatcher_boots", () -> ModArmorMaterials.DREAMCATCHER, ArmorItem.Type.BOOTS, 35, ArmorSet.DREAMCATCHER);
    public static final RegistryObject<Item> WAKEFUL_HELMET = armor("wakeful_helmet", () -> ModArmorMaterials.WAKEFUL, ArmorItem.Type.HELMET, 38, ArmorSet.WAKEFUL);
    public static final RegistryObject<Item> WAKEFUL_CHESTPLATE = armor("wakeful_chestplate", () -> ModArmorMaterials.WAKEFUL, ArmorItem.Type.CHESTPLATE, 38, ArmorSet.WAKEFUL);
    public static final RegistryObject<Item> WAKEFUL_LEGGINGS = armor("wakeful_leggings", () -> ModArmorMaterials.WAKEFUL, ArmorItem.Type.LEGGINGS, 38, ArmorSet.WAKEFUL);
    public static final RegistryObject<Item> WAKEFUL_BOOTS = armor("wakeful_boots", () -> ModArmorMaterials.WAKEFUL, ArmorItem.Type.BOOTS, 38, ArmorSet.WAKEFUL);
    public static final RegistryObject<Item> NIGHTMARE_EATER_HELMET = armor("nightmare_eater_helmet", () -> ModArmorMaterials.NIGHTMARE_EATER, ArmorItem.Type.HELMET, 40, ArmorSet.NIGHTMARE_EATER);
    public static final RegistryObject<Item> NIGHTMARE_EATER_CHESTPLATE = armor("nightmare_eater_chestplate", () -> ModArmorMaterials.NIGHTMARE_EATER, ArmorItem.Type.CHESTPLATE, 40, ArmorSet.NIGHTMARE_EATER);
    public static final RegistryObject<Item> NIGHTMARE_EATER_LEGGINGS = armor("nightmare_eater_leggings", () -> ModArmorMaterials.NIGHTMARE_EATER, ArmorItem.Type.LEGGINGS, 40, ArmorSet.NIGHTMARE_EATER);
    public static final RegistryObject<Item> NIGHTMARE_EATER_BOOTS = armor("nightmare_eater_boots", () -> ModArmorMaterials.NIGHTMARE_EATER, ArmorItem.Type.BOOTS, 40, ArmorSet.NIGHTMARE_EATER);

    // Blocks
    public static final RegistryObject<Item> DREAM_SHARD_ORE = block("dream_shard_ore", ModBlocks.DREAM_SHARD_ORE);
    public static final RegistryObject<Item> DEEPSLATE_DREAM_SHARD_ORE = block("deepslate_dream_shard_ore", ModBlocks.DEEPSLATE_DREAM_SHARD_ORE);
    public static final RegistryObject<Item> ASHEN_GRASS = block("ashen_grass", ModBlocks.ASHEN_GRASS);
    public static final RegistryObject<Item> DREAMROT = block("dreamrot", ModBlocks.DREAMROT);
    public static final RegistryObject<Item> WEEPING_LEAVES = block("weeping_leaves", ModBlocks.WEEPING_LEAVES);

    // Spawn eggs
    public static final RegistryObject<Item> ECHO_DOPPELGANGER_SPAWN_EGG = add(ITEMS.register("echo_doppelganger_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.ECHO_DOPPELGANGER, 0x1a1a22, 0xc9c3b5, new Item.Properties())));
    public static final RegistryObject<Item> STITCHER_SPAWN_EGG = add(ITEMS.register("stitcher_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.STITCHER, 0x6b5a4a, 0x8a1c1c, new Item.Properties())));
    public static final RegistryObject<Item> SLEEPLESS_SPAWN_EGG = add(ITEMS.register("sleepless_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SLEEPLESS, 0xd8d4cc, 0x0a0a0a, new Item.Properties())));
    public static final RegistryObject<Item> HOLLOW_VILLAGER_SPAWN_EGG = add(ITEMS.register("hollow_villager_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.HOLLOW_VILLAGER, 0x56493d, 0x1c0f0f, new Item.Properties())));
    public static final RegistryObject<Item> DEEP_MOTHER_SPAWN_EGG = add(ITEMS.register("deep_mother_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.DEEP_MOTHER, 0xb7a9a0, 0x3b2a3f, new Item.Properties())));
    public static final RegistryObject<Item> THE_DREAMER_SPAWN_EGG = add(ITEMS.register("the_dreamer_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.THE_DREAMER, 0x14081f, 0xe8d27a, new Item.Properties())));

    private static <T extends Item> RegistryObject<T> add(RegistryObject<T> obj) {
        TAB_ORDER.add(obj);
        return obj;
    }

    private static RegistryObject<Item> armor(String name, Supplier<Holder<ArmorMaterial>> material, ArmorItem.Type type,
                                              int durability, ArmorSet set) {
        return add(ITEMS.register(name, () -> new DreamArmorItem(material.get(), type,
                new Item.Properties().durability(type.getDurability(durability)).rarity(Rarity.RARE), set)));
    }

    private static RegistryObject<Item> block(String name, RegistryObject<Block> block) {
        return add(ITEMS.register(name, () -> new BlockItem(block.get(), new Item.Properties())));
    }
}
