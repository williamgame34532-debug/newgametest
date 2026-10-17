package com.zone19.scp.registry;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.block.KeycardDoorBlock;
import com.zone19.scp.block.LockerBlock;
import com.zone19.scp.block.TerminalBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.GlassBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;

public final class ModBlocks {
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, Zone19Mod.MODID);
    /** Every block in registration order; ModItems turns each into a BlockItem. */
    public static final List<RegistryObject<Block>> ALL = new ArrayList<>();

    public static final RegistryObject<Block> CONCRETE_WALL = reg("concrete_wall", () -> new Block(facility()));
    public static final RegistryObject<Block> CONCRETE_WALL_TRIM = reg("concrete_wall_trim", () -> new Block(facility()));
    public static final RegistryObject<Block> WHITE_WALL = reg("white_wall", () -> new Block(facility()));
    public static final RegistryObject<Block> WHITE_WALL_TRIM = reg("white_wall_trim", () -> new Block(facility()));
    public static final RegistryObject<Block> TILE_FLOOR = reg("tile_floor", () -> new Block(facility()));
    public static final RegistryObject<Block> CONCRETE_FLOOR = reg("concrete_floor", () -> new Block(facility()));
    public static final RegistryObject<Block> METAL_PANEL = reg("metal_panel", () -> new Block(facility().sound(SoundType.METAL)));
    public static final RegistryObject<Block> DIRTY_METAL = reg("dirty_metal", () -> new Block(facility().sound(SoundType.METAL)));
    public static final RegistryObject<Block> OFFICE_WALL = reg("office_wall", () -> new Block(facility()));
    public static final RegistryObject<Block> HAZARD_STRIPE = reg("hazard_stripe", () -> new Block(facility()));
    public static final RegistryObject<Block> CEILING_LIGHT = reg("ceiling_light",
            () -> new Block(facility().lightLevel(s -> 14).sound(SoundType.GLASS)));
    public static final RegistryObject<Block> EMERGENCY_LIGHT = reg("emergency_light",
            () -> new Block(facility().lightLevel(s -> 8).sound(SoundType.GLASS)));
    public static final RegistryObject<Block> FACILITY_GLASS = reg("facility_glass", () -> new GlassBlock(facility()
            .sound(SoundType.GLASS).noOcclusion().isViewBlocking((s, l, p) -> false).isSuffocating((s, l, p) -> false)));

    public static final RegistryObject<Block> LCZ_DOOR = reg("lcz_door",
            () -> new KeycardDoorBlock(facility().noOcclusion().sound(SoundType.METAL), false));
    public static final RegistryObject<Block> HEAVY_DOOR = reg("heavy_door",
            () -> new KeycardDoorBlock(facility().noOcclusion().sound(SoundType.METAL), true));

    public static final RegistryObject<Block> RECONTAINMENT_TERMINAL = reg("recontainment_terminal",
            () -> new TerminalBlock(machine(), TerminalBlock.RECONTAIN));
    public static final RegistryObject<Block> CONTROL_CONSOLE = reg("control_console",
            () -> new TerminalBlock(machine(), TerminalBlock.CONTROL));
    public static final RegistryObject<Block> BACKUP_GENERATOR = reg("backup_generator",
            () -> new TerminalBlock(machine(), TerminalBlock.GENERATOR));
    public static final RegistryObject<Block> FEMUR_BREAKER = reg("femur_breaker",
            () -> new TerminalBlock(machine(), TerminalBlock.FEMUR));

    public static final RegistryObject<Block> ARMORY_LOCKER = reg("armory_locker", () -> new LockerBlock(machine(), LockerBlock.ARMORY));
    public static final RegistryObject<Block> MEDICAL_CABINET = reg("medical_cabinet", () -> new LockerBlock(machine(), LockerBlock.MEDICAL));
    public static final RegistryObject<Block> O5_SAFE = reg("o5_safe", () -> new LockerBlock(machine(), LockerBlock.O5_SAFE));

    /** Facility shell blocks are as hard as bedrock: only creative players can reshape the site. */
    private static BlockBehaviour.Properties facility() {
        return BlockBehaviour.Properties.of().mapColor(MapColor.STONE).strength(-1.0F, 3600000.0F)
                .sound(SoundType.STONE).noLootTable();
    }

    private static BlockBehaviour.Properties machine() {
        return facility().sound(SoundType.METAL).lightLevel(s -> 3);
    }

    private static RegistryObject<Block> reg(String name, Supplier<Block> sup) {
        RegistryObject<Block> ro = BLOCKS.register(name, sup);
        ALL.add(ro);
        return ro;
    }

    private ModBlocks() {
    }
}
