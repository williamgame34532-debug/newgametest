package com.williamgame.blockmemory;

import com.mojang.serialization.Codec;
import com.williamgame.blockmemory.block.EchoKeystoneBlock;
import com.williamgame.blockmemory.block.EchoKeystoneBlockEntity;
import com.williamgame.blockmemory.block.MemoryStoneBlock;
import com.williamgame.blockmemory.block.ReliquaryBlock;
import com.williamgame.blockmemory.block.ReliquaryBlockEntity;
import com.williamgame.blockmemory.block.WhisperingPillarBlock;
import com.williamgame.blockmemory.item.ArchivistArmorItem;
import com.williamgame.blockmemory.item.CodexItem;
import com.williamgame.blockmemory.item.EchoLensItem;
import com.williamgame.blockmemory.item.MemoryBrushItem;
import com.williamgame.blockmemory.item.MemoryFragmentItem;
import com.williamgame.blockmemory.item.RecallCharmItem;
import com.williamgame.blockmemory.item.RestorationTomeItem;
import com.williamgame.blockmemory.worldgen.ForgottenRuinsFeature;
import net.minecraft.Util;
import net.minecraft.core.component.DataComponentType;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;
import net.minecraft.world.level.material.MapColor;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

import java.util.EnumMap;
import java.util.List;
import java.util.function.Supplier;

public class ModRegistry {
    public static final String MODID = BlockMemory.MODID;

    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MODID);
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MODID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES = DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MODID);
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, MODID);
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MODID);
    public static final DeferredRegister<ArmorMaterial> ARMOR_MATERIALS = DeferredRegister.create(Registries.ARMOR_MATERIAL, MODID);
    public static final DeferredRegister<DataComponentType<?>> COMPONENTS = DeferredRegister.create(Registries.DATA_COMPONENT_TYPE, MODID);
    public static final DeferredRegister<Feature<?>> FEATURES = DeferredRegister.create(ForgeRegistries.FEATURES, MODID);

    // ---------------------------------------------------------------- sounds
    public static final RegistryObject<SoundEvent> SOUND_BRUSH_WHISPER = sound("brush_whisper");
    public static final RegistryObject<SoundEvent> SOUND_GHOST_RISE = sound("ghost_rise");
    public static final RegistryObject<SoundEvent> SOUND_FRAGMENT_UNLOCK = sound("fragment_unlock");
    public static final RegistryObject<SoundEvent> SOUND_CHAPTER_COMPLETE = sound("chapter_complete");
    public static final RegistryObject<SoundEvent> SOUND_CODEX_OPEN = sound("codex_open");
    public static final RegistryObject<SoundEvent> SOUND_PILLAR_WHISPER = sound("pillar_whisper");
    public static final RegistryObject<SoundEvent> SOUND_RECALL = sound("recall");

    private static RegistryObject<SoundEvent> sound(String name) {
        return SOUNDS.register(name, () -> SoundEvent.createVariableRangeEvent(BlockMemory.id(name)));
    }

    // ---------------------------------------------------------------- data components
    public static final RegistryObject<DataComponentType<Integer>> FRAGMENT_ID = COMPONENTS.register("fragment_id",
            () -> new DataComponentType.Builder<Integer>().persistent(Codec.INT).networkSynchronized(ByteBufCodecs.VAR_INT).build());

    // ---------------------------------------------------------------- blocks
    public static final RegistryObject<Block> MEMORY_STONE = block("memory_stone",
            () -> new MemoryStoneBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_BLUE).strength(2.5F, 8.0F)
                    .sound(SoundType.DEEPSLATE).requiresCorrectToolForDrops().lightLevel(s -> 3)));
    public static final RegistryObject<Block> CARVED_MEMORY_STONE = block("carved_memory_stone",
            () -> new MemoryStoneBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_BLUE).strength(2.5F, 8.0F)
                    .sound(SoundType.DEEPSLATE_TILES).requiresCorrectToolForDrops().lightLevel(s -> 5)));
    public static final RegistryObject<Block> FADED_BRICKS = block("faded_bricks",
            () -> new Block(bricks()));
    public static final RegistryObject<Block> CRACKED_FADED_BRICKS = block("cracked_faded_bricks",
            () -> new Block(bricks()));
    public static final RegistryObject<Block> MOSSY_FADED_BRICKS = block("mossy_faded_bricks",
            () -> new Block(bricks()));
    public static final RegistryObject<Block> FADED_BRICK_STAIRS = block("faded_brick_stairs",
            () -> new StairBlock(FADED_BRICKS.get().defaultBlockState(), bricks()));
    public static final RegistryObject<Block> FADED_BRICK_SLAB = block("faded_brick_slab",
            () -> new SlabBlock(bricks()));
    public static final RegistryObject<Block> WHISPERING_PILLAR = block("whispering_pillar",
            () -> new WhisperingPillarBlock(BlockBehaviour.Properties.of().mapColor(MapColor.QUARTZ).strength(2.0F, 6.0F)
                    .sound(SoundType.CALCITE).requiresCorrectToolForDrops().lightLevel(s -> 6)));
    public static final RegistryObject<Block> ECHO_KEYSTONE = block("echo_keystone",
            () -> new EchoKeystoneBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_CYAN).strength(3.5F, 12.0F)
                    .sound(SoundType.DEEPSLATE_BRICKS).requiresCorrectToolForDrops().lightLevel(s -> 5)));
    public static final RegistryObject<Block> MEMORY_RELIQUARY = block("memory_reliquary",
            () -> new ReliquaryBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_LIGHT_BLUE).strength(3.0F, 10.0F)
                    .sound(SoundType.DECORATED_POT).requiresCorrectToolForDrops().lightLevel(s -> 7)));

    private static BlockBehaviour.Properties bricks() {
        return BlockBehaviour.Properties.of().mapColor(MapColor.TERRACOTTA_LIGHT_GRAY).strength(1.8F, 6.0F)
                .sound(SoundType.MUD_BRICKS).requiresCorrectToolForDrops();
    }

    private static RegistryObject<Block> block(String name, Supplier<Block> sup) {
        RegistryObject<Block> b = BLOCKS.register(name, sup);
        ITEMS.register(name, () -> new BlockItem(b.get(), new Item.Properties()));
        return b;
    }

    // ---------------------------------------------------------------- block entities
    public static final RegistryObject<BlockEntityType<EchoKeystoneBlockEntity>> KEYSTONE_BE = BLOCK_ENTITIES.register("echo_keystone",
            () -> BlockEntityType.Builder.of(EchoKeystoneBlockEntity::new, ECHO_KEYSTONE.get()).build(null));
    public static final RegistryObject<BlockEntityType<ReliquaryBlockEntity>> RELIQUARY_BE = BLOCK_ENTITIES.register("memory_reliquary",
            () -> BlockEntityType.Builder.of(ReliquaryBlockEntity::new, MEMORY_RELIQUARY.get()).build(null));

    // ---------------------------------------------------------------- armor
    public static final RegistryObject<ArmorMaterial> ARCHIVIST_MATERIAL = ARMOR_MATERIALS.register("archivist", () -> new ArmorMaterial(
            Util.make(new EnumMap<>(ArmorItem.Type.class), m -> {
                m.put(ArmorItem.Type.BOOTS, 2);
                m.put(ArmorItem.Type.LEGGINGS, 5);
                m.put(ArmorItem.Type.CHESTPLATE, 7);
                m.put(ArmorItem.Type.HELMET, 3);
                m.put(ArmorItem.Type.BODY, 7);
            }),
            25, SoundEvents.ARMOR_EQUIP_LEATHER, () -> Ingredient.of(MEMORY_STONE.get().asItem()),
            List.of(new ArmorMaterial.Layer(BlockMemory.id("archivist"))), 1.0F, 0.0F));

    // ---------------------------------------------------------------- items
    public static final RegistryObject<Item> MEMORY_BRUSH = ITEMS.register("memory_brush",
            () -> new MemoryBrushItem(new Item.Properties().durability(160).rarity(Rarity.UNCOMMON)));
    public static final RegistryObject<Item> ECHO_LENS = ITEMS.register("echo_lens",
            () -> new EchoLensItem(new Item.Properties().stacksTo(1).rarity(Rarity.UNCOMMON)));
    public static final RegistryObject<Item> MEMORY_FRAGMENT = ITEMS.register("memory_fragment",
            () -> new MemoryFragmentItem(new Item.Properties().stacksTo(16).rarity(Rarity.UNCOMMON)));
    public static final RegistryObject<Item> CODEX = ITEMS.register("codex",
            () -> new CodexItem(new Item.Properties().stacksTo(1).rarity(Rarity.UNCOMMON)));
    public static final RegistryObject<Item> RECALL_CHARM = ITEMS.register("recall_charm",
            () -> new RecallCharmItem(new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> RESTORATION_TOME = ITEMS.register("restoration_tome",
            () -> new RestorationTomeItem(new Item.Properties().durability(96).rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> ARCHIVIST_HOOD = ITEMS.register("archivist_hood",
            () -> new ArchivistArmorItem(ARCHIVIST_MATERIAL.getHolder().get(), ArmorItem.Type.HELMET,
                    new Item.Properties().durability(ArmorItem.Type.HELMET.getDurability(22)).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> ARCHIVIST_ROBE = ITEMS.register("archivist_robe",
            () -> new ArchivistArmorItem(ARCHIVIST_MATERIAL.getHolder().get(), ArmorItem.Type.CHESTPLATE,
                    new Item.Properties().durability(ArmorItem.Type.CHESTPLATE.getDurability(22)).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> ARCHIVIST_LEGGINGS = ITEMS.register("archivist_leggings",
            () -> new ArchivistArmorItem(ARCHIVIST_MATERIAL.getHolder().get(), ArmorItem.Type.LEGGINGS,
                    new Item.Properties().durability(ArmorItem.Type.LEGGINGS.getDurability(22)).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> ARCHIVIST_SANDALS = ITEMS.register("archivist_sandals",
            () -> new ArchivistArmorItem(ARCHIVIST_MATERIAL.getHolder().get(), ArmorItem.Type.BOOTS,
                    new Item.Properties().durability(ArmorItem.Type.BOOTS.getDurability(22)).rarity(Rarity.RARE)));

    // ---------------------------------------------------------------- worldgen
    public static final RegistryObject<Feature<NoneFeatureConfiguration>> FORGOTTEN_RUINS = FEATURES.register("forgotten_ruins",
            () -> new ForgottenRuinsFeature(NoneFeatureConfiguration.CODEC));

    // ---------------------------------------------------------------- creative tab
    public static final RegistryObject<CreativeModeTab> TAB = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.blockmemory"))
            .icon(() -> new ItemStack(MEMORY_BRUSH.get()))
            .displayItems((params, output) -> {
                output.accept(MEMORY_BRUSH.get());
                output.accept(ECHO_LENS.get());
                output.accept(CODEX.get());
                output.accept(MEMORY_FRAGMENT.get());
                for (int i = 0; i < com.williamgame.blockmemory.codex.Fragments.TOTAL; i++) {
                    output.accept(MemoryFragmentItem.identified(i));
                }
                output.accept(RECALL_CHARM.get());
                output.accept(RESTORATION_TOME.get());
                output.accept(ARCHIVIST_HOOD.get());
                output.accept(ARCHIVIST_ROBE.get());
                output.accept(ARCHIVIST_LEGGINGS.get());
                output.accept(ARCHIVIST_SANDALS.get());
                for (RegistryObject<Block> b : BLOCKS.getEntries()) {
                    output.accept(b.get());
                }
            }).build());

    public static void register(IEventBus modBus) {
        BLOCKS.register(modBus);
        ITEMS.register(modBus);
        BLOCK_ENTITIES.register(modBus);
        SOUNDS.register(modBus);
        TABS.register(modBus);
        ARMOR_MATERIALS.register(modBus);
        COMPONENTS.register(modBus);
        FEATURES.register(modBus);
    }
}
