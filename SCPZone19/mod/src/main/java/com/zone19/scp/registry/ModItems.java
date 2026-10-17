package com.zone19.scp.registry;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.item.DocumentItem;
import com.zone19.scp.item.GunItem;
import com.zone19.scp.item.KeycardItem;
import com.zone19.scp.item.MedicalItem;
import com.zone19.scp.item.ModArmorMaterials;
import com.zone19.scp.item.RadioItem;
import com.zone19.scp.item.SnavItem;
import com.zone19.scp.item.StunBatonItem;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.level.block.Block;
import net.minecraftforge.common.ForgeSpawnEggItem;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModItems {
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, Zone19Mod.MODID);

    public static final RegistryObject<Item> KEYCARD_1 = keycard("keycard_1", 1, Rarity.COMMON);
    public static final RegistryObject<Item> KEYCARD_2 = keycard("keycard_2", 2, Rarity.COMMON);
    public static final RegistryObject<Item> KEYCARD_3 = keycard("keycard_3", 3, Rarity.UNCOMMON);
    public static final RegistryObject<Item> KEYCARD_4 = keycard("keycard_4", 4, Rarity.UNCOMMON);
    public static final RegistryObject<Item> KEYCARD_5 = keycard("keycard_5", 5, Rarity.RARE);
    public static final RegistryObject<Item> KEYCARD_OMNI = keycard("keycard_omni", 6, Rarity.EPIC);

    public static final RegistryObject<Item> AMMO_9MM = ITEMS.register("ammo_9mm", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> AMMO_57 = ITEMS.register("ammo_57", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> AMMO_12G = ITEMS.register("ammo_12g", () -> new Item(new Item.Properties()));

    public static final RegistryObject<Item> USP = ITEMS.register("usp", () -> new GunItem(new GunItem.Stats()
            .damage(6.0F).fireDelay(5).magazine(12).spread(0.015).recoil(2.5F).reload(30)
            .ammo(AMMO_9MM).sound(ModSounds.GUN_PISTOL)));
    public static final RegistryObject<Item> MP5SD = ITEMS.register("mp5sd", () -> new GunItem(new GunItem.Stats()
            .damage(4.5F).fireDelay(2).automatic().magazine(30).spread(0.035).recoil(1.2F).reload(45)
            .ammo(AMMO_9MM).sound(ModSounds.GUN_PISTOL).volume(0.55F)));
    public static final RegistryObject<Item> P90 = ITEMS.register("p90", () -> new GunItem(new GunItem.Stats()
            .damage(4.0F).fireDelay(2).automatic().magazine(50).spread(0.03).recoil(1.0F).reload(50)
            .ammo(AMMO_57).sound(ModSounds.GUN_RIFLE)));
    public static final RegistryObject<Item> SPAS12 = ITEMS.register("spas12", () -> new GunItem(new GunItem.Stats()
            .damage(3.5F).pellets(8).fireDelay(16).magazine(6).spread(0.11).recoil(7.0F).reload(60).range(24)
            .ammo(AMMO_12G).sound(ModSounds.GUN_RIFLE).pitch(0.7F)));
    public static final RegistryObject<Item> STUN_BATON = ITEMS.register("stun_baton", StunBatonItem::new);

    public static final RegistryObject<Item> SCP500 = ITEMS.register("scp500",
            () -> new MedicalItem(MedicalItem.Kind.SCP500, new Item.Properties().stacksTo(8).rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> FIRST_AID = ITEMS.register("first_aid",
            () -> new MedicalItem(MedicalItem.Kind.FIRST_AID, new Item.Properties().stacksTo(4)));
    public static final RegistryObject<Item> EYEDROPS = ITEMS.register("eyedrops",
            () -> new MedicalItem(MedicalItem.Kind.EYEDROPS, new Item.Properties().stacksTo(8)));
    public static final RegistryObject<Item> RADIO = ITEMS.register("radio", RadioItem::new);
    public static final RegistryObject<Item> SNAV = ITEMS.register("snav", SnavItem::new);
    public static final RegistryObject<Item> GAS_MASK = ITEMS.register("gas_mask",
            () -> new ArmorItem(ModArmorMaterials.GASMASK, ArmorItem.Type.HELMET, new Item.Properties()));
    public static final RegistryObject<Item> BALLISTIC_VEST = ITEMS.register("ballistic_vest",
            () -> new ArmorItem(ModArmorMaterials.TACTICAL, ArmorItem.Type.CHESTPLATE, new Item.Properties()));

    public static final RegistryObject<Item> DOC_173 = ITEMS.register("doc_173", () -> new DocumentItem("173"));
    public static final RegistryObject<Item> DOC_096 = ITEMS.register("doc_096", () -> new DocumentItem("096"));
    public static final RegistryObject<Item> DOC_106 = ITEMS.register("doc_106", () -> new DocumentItem("106"));
    public static final RegistryObject<Item> DOC_049 = ITEMS.register("doc_049", () -> new DocumentItem("049"));

    public static final RegistryObject<Item> SCP173_EGG = ITEMS.register("scp173_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SCP173, 0xC9B48A, 0x9B1D16, new Item.Properties()));
    public static final RegistryObject<Item> SCP096_EGG = ITEMS.register("scp096_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SCP096, 0xD6D1CB, 0x2A0D0D, new Item.Properties()));
    public static final RegistryObject<Item> SCP106_EGG = ITEMS.register("scp106_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SCP106, 0x2A231C, 0x0C0A08, new Item.Properties()));
    public static final RegistryObject<Item> SCP049_2_EGG = ITEMS.register("scp049_2_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SCP049_2, 0x7D8872, 0x93AAB8, new Item.Properties()));

    static {
        for (RegistryObject<Block> block : ModBlocks.ALL) {
            ITEMS.register(block.getId().getPath(), () -> new BlockItem(block.get(), new Item.Properties()));
        }
    }

    private static RegistryObject<Item> keycard(String name, int level, Rarity rarity) {
        return ITEMS.register(name, () -> new KeycardItem(level, new Item.Properties().stacksTo(1).rarity(rarity)));
    }

    private ModItems() {
    }
}
