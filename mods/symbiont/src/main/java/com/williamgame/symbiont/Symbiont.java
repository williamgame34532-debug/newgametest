package com.williamgame.symbiont;

import com.williamgame.symbiont.block.SymbiontNestBlock;
import com.williamgame.symbiont.entity.SymbiontEntity;
import com.williamgame.symbiont.item.FarewellNoteItem;
import com.williamgame.symbiont.item.SymbiontEggItem;
import com.williamgame.symbiont.item.SymbiontTreatItem;
import com.williamgame.symbiont.network.SymbiontNetwork;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

@Mod(Symbiont.MODID)
public class Symbiont {
    public static final String MODID = "symbiont";

    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MODID);
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MODID);
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, MODID);
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, MODID);
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MODID);

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    private static RegistryObject<SoundEvent> sound(String name) {
        return SOUNDS.register(name, () -> SoundEvent.createVariableRangeEvent(id(name)));
    }

    public static final RegistryObject<SoundEvent> SOUND_CHIRP = sound("chirp");
    public static final RegistryObject<SoundEvent> SOUND_HAPPY = sound("happy");
    public static final RegistryObject<SoundEvent> SOUND_SAD = sound("sad");
    public static final RegistryObject<SoundEvent> SOUND_EVOLVE = sound("evolve");
    public static final RegistryObject<SoundEvent> SOUND_HATCH = sound("hatch");
    public static final RegistryObject<SoundEvent> SOUND_HURT = sound("hurt");
    public static final RegistryObject<SoundEvent> SOUND_DEATH = sound("death");

    public static final RegistryObject<EntityType<SymbiontEntity>> SYMBIONT = ENTITIES.register("symbiont",
            () -> EntityType.Builder.of(SymbiontEntity::new, MobCategory.MISC).sized(0.5F, 0.55F)
                    .clientTrackingRange(10).updateInterval(2)
                    .build(id("symbiont").toString()));

    public static final RegistryObject<Block> NEST = BLOCKS.register("symbiont_nest",
            () -> new SymbiontNestBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_YELLOW)
                    .strength(0.8F).sound(SoundType.GRASS).noOcclusion().lightLevel(s -> 5)));

    public static final RegistryObject<Item> NEST_ITEM = ITEMS.register("symbiont_nest",
            () -> new BlockItem(NEST.get(), new Item.Properties()));
    public static final RegistryObject<Item> EGG = ITEMS.register("symbiont_egg",
            () -> new SymbiontEggItem(new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> TREAT = ITEMS.register("symbiont_treat",
            () -> new SymbiontTreatItem(new Item.Properties().stacksTo(16)));
    public static final RegistryObject<Item> FAREWELL_NOTE = ITEMS.register("farewell_note",
            () -> new FarewellNoteItem(new Item.Properties().stacksTo(1).rarity(Rarity.UNCOMMON)));

    public static final RegistryObject<CreativeModeTab> TAB = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.symbiont"))
            .icon(() -> new ItemStack(EGG.get()))
            .displayItems((params, output) -> {
                output.accept(EGG.get());
                output.accept(TREAT.get());
                output.accept(NEST_ITEM.get());
            }).build());

    public Symbiont(FMLJavaModLoadingContext context) {
        IEventBus modBus = context.getModEventBus();
        ITEMS.register(modBus);
        BLOCKS.register(modBus);
        ENTITIES.register(modBus);
        SOUNDS.register(modBus);
        TABS.register(modBus);
        modBus.addListener(this::attributes);
        context.registerConfig(ModConfig.Type.COMMON, SymbiontConfig.SPEC);
        SymbiontNetwork.register();
        MinecraftForge.EVENT_BUS.register(SymbiontEvents.class);
    }

    private void attributes(EntityAttributeCreationEvent event) {
        event.put(SYMBIONT.get(), SymbiontEntity.createAttributes().build());
    }
}
