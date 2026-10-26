package com.williamgame.apiprobe;

import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.item.*;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.core.Holder;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.Util;
import java.util.EnumMap;
import java.util.List;

@Mod(ApiProbe.MODID)
public class ApiProbe {
    public static final String MODID = "apiprobe";

    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MODID);
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MODID);
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, MODID);
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, MODID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES = DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MODID);
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MODID);
    public static final DeferredRegister<ArmorMaterial> ARMOR_MATERIALS = DeferredRegister.create(Registries.ARMOR_MATERIAL, MODID);

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    public static final RegistryObject<SoundEvent> WHISPER = SOUNDS.register("whisper",
            () -> SoundEvent.createVariableRangeEvent(id("whisper")));

    public static final RegistryObject<ArmorMaterial> DREAM_ARMOR = ARMOR_MATERIALS.register("dream", () -> new ArmorMaterial(
            Util.make(new EnumMap<>(ArmorItem.Type.class), m -> {
                m.put(ArmorItem.Type.BOOTS, 3);
                m.put(ArmorItem.Type.LEGGINGS, 6);
                m.put(ArmorItem.Type.CHESTPLATE, 8);
                m.put(ArmorItem.Type.HELMET, 3);
                m.put(ArmorItem.Type.BODY, 11);
            }),
            15, SoundEvents.ARMOR_EQUIP_NETHERITE, () -> Ingredient.of(Items.AMETHYST_SHARD),
            List.of(new ArmorMaterial.Layer(id("dream"))), 3.0F, 0.1F));

    public static final Tier DREAM_TIER = new SimpleTier(
            net.minecraft.tags.BlockTags.INCORRECT_FOR_NETHERITE_TOOL, 2200, 9.0F, 4.0F, 18,
            () -> Ingredient.of(Items.AMETHYST_SHARD));

    public static final RegistryObject<Block> PAD = BLOCKS.register("pad",
            () -> new ProbeBlock(BlockBehaviour.Properties.of().strength(2.0F).sound(SoundType.AMETHYST).lightLevel(s -> 7)));
    public static final RegistryObject<Item> PAD_ITEM = ITEMS.register("pad", () -> new BlockItem(PAD.get(), new Item.Properties()));
    public static final RegistryObject<BlockEntityType<ProbeBlockEntity>> PAD_BE = BLOCK_ENTITIES.register("pad",
            () -> BlockEntityType.Builder.of(ProbeBlockEntity::new, PAD.get()).build(null));

    public static final RegistryObject<Item> SWORD = ITEMS.register("dream_sword", () -> new SwordItem(DREAM_TIER,
            new Item.Properties().attributes(SwordItem.createAttributes(DREAM_TIER, 3, -2.4F)).rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> HELMET = ITEMS.register("dream_helmet", () -> new ArmorItem(DREAM_ARMOR.getHolder().get(),
            ArmorItem.Type.HELMET, new Item.Properties().durability(ArmorItem.Type.HELMET.getDurability(37))));

    public static final RegistryObject<EntityType<ProbeMonster>> MONSTER = ENTITIES.register("probe_monster",
            () -> EntityType.Builder.of(ProbeMonster::new, MobCategory.MONSTER).sized(0.6F, 2.9F).clientTrackingRange(10)
                    .build(id("probe_monster").toString()));

    public static final RegistryObject<Item> SPAWN_EGG = ITEMS.register("probe_monster_spawn_egg",
            () -> new net.minecraftforge.common.ForgeSpawnEggItem(MONSTER, 0x111111, 0x6633aa, new Item.Properties()));

    public static final RegistryObject<CreativeModeTab> TAB = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.apiprobe"))
            .icon(() -> new ItemStack(SWORD.get()))
            .displayItems((params, output) -> {
                output.accept(SWORD.get());
                output.accept(HELMET.get());
                output.accept(PAD_ITEM.get());
                output.accept(SPAWN_EGG.get());
            }).build());

    public ApiProbe(FMLJavaModLoadingContext context) {
        IEventBus modBus = context.getModEventBus();
        ITEMS.register(modBus);
        BLOCKS.register(modBus);
        ENTITIES.register(modBus);
        SOUNDS.register(modBus);
        BLOCK_ENTITIES.register(modBus);
        TABS.register(modBus);
        ARMOR_MATERIALS.register(modBus);
        modBus.addListener(this::attributes);
        context.registerConfig(net.minecraftforge.fml.config.ModConfig.Type.COMMON, ProbeConfig.SPEC);
        ProbeNetwork.register();
        MinecraftForge.EVENT_BUS.register(ProbeEvents.class);
    }

    private void attributes(EntityAttributeCreationEvent event) {
        event.put(MONSTER.get(), Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 60).add(Attributes.MOVEMENT_SPEED, 0.3).add(Attributes.ATTACK_DAMAGE, 8).build());
    }
}
