package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.block.AshenGrassBlock;
import com.williamgame.echoesofsleep.block.DreamrotBlock;
import com.williamgame.echoesofsleep.block.WeepingLeavesBlock;
import net.minecraft.util.valueproviders.UniformInt;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.DropExperienceBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.material.PushReaction;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public class ModBlocks {
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, EchoesOfSleep.MODID);

    public static final RegistryObject<Block> DREAM_SHARD_ORE = BLOCKS.register("dream_shard_ore",
            () -> new DropExperienceBlock(UniformInt.of(3, 7), BlockBehaviour.Properties.of()
                    .mapColor(MapColor.STONE).strength(3.0F, 3.0F).requiresCorrectToolForDrops()
                    .sound(SoundType.STONE).lightLevel(s -> 3)));
    public static final RegistryObject<Block> DEEPSLATE_DREAM_SHARD_ORE = BLOCKS.register("deepslate_dream_shard_ore",
            () -> new DropExperienceBlock(UniformInt.of(3, 7), BlockBehaviour.Properties.of()
                    .mapColor(MapColor.DEEPSLATE).strength(4.5F, 3.0F).requiresCorrectToolForDrops()
                    .sound(SoundType.DEEPSLATE).lightLevel(s -> 3)));

    // Distortion blocks: they only exist while the world is dreaming and are always reverted.
    public static final RegistryObject<Block> ASHEN_GRASS = BLOCKS.register("ashen_grass",
            () -> new AshenGrassBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_GRAY)
                    .strength(0.6F).sound(SoundType.GRAVEL).pushReaction(PushReaction.BLOCK)));
    public static final RegistryObject<Block> DREAMROT = BLOCKS.register("dreamrot",
            () -> new DreamrotBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_RED)
                    .strength(0.8F).sound(SoundType.SLIME_BLOCK).lightLevel(s -> 4).pushReaction(PushReaction.BLOCK)));
    public static final RegistryObject<Block> WEEPING_LEAVES = BLOCKS.register("weeping_leaves",
            () -> new WeepingLeavesBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_PURPLE)
                    .strength(0.2F).sound(SoundType.WET_GRASS).noOcclusion()
                    .isSuffocating((s, l, p) -> false).isViewBlocking((s, l, p) -> false)
                    .pushReaction(PushReaction.BLOCK)));
}
