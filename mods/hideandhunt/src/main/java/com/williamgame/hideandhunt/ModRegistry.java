package com.williamgame.hideandhunt;

import com.williamgame.hideandhunt.block.PedestalButtonBlock;
import com.williamgame.hideandhunt.block.TeamPadBlock;
import com.williamgame.hideandhunt.item.GameMasterTabletItem;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.material.PushReaction;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

import java.util.ArrayList;
import java.util.List;

public final class ModRegistry {
    private ModRegistry() {}

    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, HideAndHunt.MODID);
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, HideAndHunt.MODID);
    public static final DeferredRegister<SoundEvent> SOUNDS = DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, HideAndHunt.MODID);
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, HideAndHunt.MODID);

    private static final List<RegistryObject<Item>> TAB_ITEMS = new ArrayList<>();

    // ---------------------------------------------------------------- sounds
    public static final RegistryObject<SoundEvent> SND_COUNTDOWN = sound("countdown");
    public static final RegistryObject<SoundEvent> SND_HIDE_START = sound("hide_start");
    public static final RegistryObject<SoundEvent> SND_HUNT_START = sound("hunt_start");
    public static final RegistryObject<SoundEvent> SND_CAUGHT = sound("caught");
    public static final RegistryObject<SoundEvent> SND_TAUNT = sound("taunt");
    public static final RegistryObject<SoundEvent> SND_RANDOM_TICK = sound("randomizer_tick");
    public static final RegistryObject<SoundEvent> SND_RANDOM_REVEAL = sound("randomizer_reveal");
    public static final RegistryObject<SoundEvent> SND_VICTORY = sound("victory");
    public static final RegistryObject<SoundEvent> SND_HINT = sound("hint_ping");
    public static final RegistryObject<SoundEvent> SND_JOIN = sound("join");
    public static final RegistryObject<SoundEvent> SND_DEFEAT = sound("defeat");
    public static final RegistryObject<SoundEvent> SND_RANDOM_POP = sound("randomizer_pop");

    private static RegistryObject<SoundEvent> sound(String name) {
        return SOUNDS.register(name, () -> SoundEvent.createVariableRangeEvent(HideAndHunt.id(name)));
    }

    // ---------------------------------------------------------------- blocks
    private static BlockBehaviour.Properties padProps(MapColor color) {
        return BlockBehaviour.Properties.of().mapColor(color).strength(-1.0F, 3600000.0F)
                .sound(SoundType.AMETHYST).lightLevel(s -> 10).noOcclusion().pushReaction(PushReaction.BLOCK);
    }

    private static BlockBehaviour.Properties buttonProps(MapColor color) {
        return BlockBehaviour.Properties.of().mapColor(color).strength(-1.0F, 3600000.0F)
                .sound(SoundType.METAL).noOcclusion().pushReaction(PushReaction.BLOCK)
                .lightLevel(s -> s.getValue(BlockStateProperties.POWERED) ? 12 : 6);
    }

    public static final RegistryObject<Block> HIDER_PAD = block("hider_pad",
            () -> new TeamPadBlock(padProps(MapColor.EMERALD), TeamPadBlock.PadType.HIDER));
    public static final RegistryObject<Block> HUNTER_PAD = block("hunter_pad",
            () -> new TeamPadBlock(padProps(MapColor.COLOR_RED), TeamPadBlock.PadType.HUNTER));
    public static final RegistryObject<Block> LOBBY_PAD = block("lobby_pad",
            () -> new TeamPadBlock(padProps(MapColor.COLOR_PURPLE), TeamPadBlock.PadType.LOBBY));

    public static final RegistryObject<Block> HIDER_BUTTON = block("hider_button",
            () -> new PedestalButtonBlock(buttonProps(MapColor.EMERALD), PedestalButtonBlock.ButtonType.HIDER));
    public static final RegistryObject<Block> HUNTER_BUTTON = block("hunter_button",
            () -> new PedestalButtonBlock(buttonProps(MapColor.COLOR_RED), PedestalButtonBlock.ButtonType.HUNTER));
    public static final RegistryObject<Block> LEAVE_BUTTON = block("leave_button",
            () -> new PedestalButtonBlock(buttonProps(MapColor.COLOR_GRAY), PedestalButtonBlock.ButtonType.LEAVE));
    public static final RegistryObject<Block> RANDOMIZER_BUTTON = block("randomizer_button",
            () -> new PedestalButtonBlock(buttonProps(MapColor.GOLD), PedestalButtonBlock.ButtonType.RANDOMIZER));
    public static final RegistryObject<Block> START_BUTTON = block("start_button",
            () -> new PedestalButtonBlock(buttonProps(MapColor.DIAMOND), PedestalButtonBlock.ButtonType.START));

    private static RegistryObject<Block> block(String name, java.util.function.Supplier<Block> sup) {
        RegistryObject<Block> b = BLOCKS.register(name, sup);
        TAB_ITEMS.add(ITEMS.register(name, () -> new BlockItem(b.get(), new Item.Properties())));
        return b;
    }

    // ---------------------------------------------------------------- items
    public static final RegistryObject<Item> TABLET = ITEMS.register("game_master_tablet",
            () -> new GameMasterTabletItem(new Item.Properties().stacksTo(1).rarity(Rarity.EPIC)));

    public static final RegistryObject<CreativeModeTab> TAB = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.hideandhunt"))
            .icon(() -> new ItemStack(TABLET.get()))
            .displayItems((params, output) -> {
                output.accept(TABLET.get());
                for (RegistryObject<Item> it : TAB_ITEMS) {
                    output.accept(it.get());
                }
            }).build());

    public static void register(IEventBus modBus) {
        BLOCKS.register(modBus);
        ITEMS.register(modBus);
        SOUNDS.register(modBus);
        TABS.register(modBus);
    }
}
