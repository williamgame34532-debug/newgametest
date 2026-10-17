package com.zone19.scp.world;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.block.KeycardDoorBlock;
import com.zone19.scp.registry.ModBlocks;
import com.zone19.scp.world.ZoneLayout.Room;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.WallSignBlock;
import net.minecraft.world.level.block.entity.SignBlockEntity;
import net.minecraft.world.level.block.entity.SignText;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.SlabType;

import static com.zone19.scp.world.ZoneLayout.*;

/**
 * Builds the facility block by block. The whole footprint is first poured as solid concrete,
 * then every room is hollowed out of it, so neighbouring rooms automatically share walls.
 */
public final class FacilityBuilder {
    private static final int FLAGS = Block.UPDATE_CLIENTS | Block.UPDATE_KNOWN_SHAPE;
    private final ServerLevel level;
    private final BlockPos.MutableBlockPos cursor = new BlockPos.MutableBlockPos();

    private FacilityBuilder(ServerLevel level) {
        this.level = level;
    }

    public static void build(ServerLevel level) {
        long t = System.currentTimeMillis();
        new FacilityBuilder(level).run();
        Zone19Mod.LOGGER.info("Zone-19 facility built in {} ms", System.currentTimeMillis() - t);
    }

    private void run() {
        fill(-2, FLOOR - 1, -30, 234, CEILING + 1, 24, ModBlocks.CONCRETE_WALL.get().defaultBlockState());
        for (Room r : ROOMS) carve(r);
        for (Room r : ROOMS) decorate(r);
        for (Room r : ROOMS) lights(r);

        // spawn room opens straight into the corridor
        fill(16, FEET, -2, 16, FEET + 3, 2, Blocks.AIR.defaultBlockState());
        // LCZ checkpoint: a wall across the corridor with a level-2 door
        fill(50, FEET, -2, 50, CEILING - 1, 2, ModBlocks.WHITE_WALL.get().defaultBlockState());
        fill(50, FLOOR, -2, 50, FLOOR, 2, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());

        door(ModBlocks.LCZ_DOOR.get(), 33, 3, Direction.NORTH, 1, 0);
        door(ModBlocks.LCZ_DOOR.get(), 50, -1, Direction.EAST, 3, 2);
        door(ModBlocks.LCZ_DOOR.get(), 69, -3, Direction.NORTH, 1, 2);
        door(ModBlocks.LCZ_DOOR.get(), 90, -3, Direction.NORTH, 1, 3);
        door(ModBlocks.HEAVY_DOOR.get(), 99, -23, Direction.EAST, 3, 3);
        door(ModBlocks.HEAVY_DOOR.get(), 100, -1, Direction.EAST, 3, 3);
        door(ModBlocks.LCZ_DOOR.get(), 118, 6, Direction.NORTH, 1, 3);
        door(ModBlocks.HEAVY_DOOR.get(), 150, -1, Direction.EAST, 3, 4);
        door(ModBlocks.LCZ_DOOR.get(), 165, 3, Direction.NORTH, 1, 4);
        door(ModBlocks.HEAVY_DOOR.get(), 185, 3, Direction.NORTH, 1, 4);
        door(ModBlocks.LCZ_DOOR.get(), 186, -3, Direction.NORTH, 1, 4);
        door(ModBlocks.HEAVY_DOOR.get(), 200, -1, Direction.EAST, 3, 5);

        props();
        signs();
    }

    // ------------------------------------------------------------------ primitives
    private void set(int x, int y, int z, BlockState state) {
        level.setBlock(cursor.set(x, y, z), state, FLAGS);
    }

    private void fill(int x1, int y1, int z1, int x2, int y2, int z2, BlockState state) {
        for (int x = Math.min(x1, x2); x <= Math.max(x1, x2); x++)
            for (int z = Math.min(z1, z2); z <= Math.max(z1, z2); z++)
                for (int y = Math.min(y1, y2); y <= Math.max(y1, y2); y++)
                    set(x, y, z, state);
    }

    private BlockState wall(Room r) {
        return switch (r.theme()) {
            case LCZ -> ModBlocks.WHITE_WALL.get().defaultBlockState();
            case OFFICE -> ModBlocks.OFFICE_WALL.get().defaultBlockState();
            default -> ModBlocks.CONCRETE_WALL.get().defaultBlockState();
        };
    }

    private BlockState trim(Room r) {
        return switch (r.theme()) {
            case LCZ, OFFICE -> ModBlocks.WHITE_WALL_TRIM.get().defaultBlockState();
            case GATE -> ModBlocks.HAZARD_STRIPE.get().defaultBlockState();
            default -> ModBlocks.CONCRETE_WALL_TRIM.get().defaultBlockState();
        };
    }

    private BlockState floor(Room r) {
        return switch (r.theme()) {
            case LCZ, OFFICE -> ModBlocks.TILE_FLOOR.get().defaultBlockState();
            default -> ModBlocks.CONCRETE_FLOOR.get().defaultBlockState();
        };
    }

    private BlockState ceiling(Room r) {
        return r.theme() == Theme.HCZ || r.theme() == Theme.GATE
                ? ModBlocks.DIRTY_METAL.get().defaultBlockState()
                : ModBlocks.METAL_PANEL.get().defaultBlockState();
    }

    private void carve(Room r) {
        fill(r.x1() + 1, FEET, r.z1() + 1, r.x2() - 1, CEILING - 1, r.z2() - 1, Blocks.AIR.defaultBlockState());
        fill(r.x1() + 1, FLOOR, r.z1() + 1, r.x2() - 1, FLOOR, r.z2() - 1, floor(r));
        fill(r.x1() + 1, CEILING, r.z1() + 1, r.x2() - 1, CEILING, r.z2() - 1, ceiling(r));
    }

    private void decorate(Room r) {
        BlockState w = wall(r), t = trim(r);
        for (int x = r.x1(); x <= r.x2(); x++) {
            for (int z = r.z1(); z <= r.z2(); z++) {
                if (x != r.x1() && x != r.x2() && z != r.z1() && z != r.z2()) continue;
                set(x, FEET, z, t);
                for (int y = FEET + 1; y < CEILING; y++) set(x, y, z, w);
            }
        }
    }

    private void lights(Room r) {
        int ix1 = r.x1() + 1, ix2 = r.x2() - 1, iz1 = r.z1() + 1, iz2 = r.z2() - 1;
        boolean narrow = iz2 - iz1 <= 4;
        int n = 0;
        for (int x = ix1 + 1; x <= ix2 - 1; x += 4) {
            for (int z = narrow ? (iz1 + iz2) / 2 : iz1 + 1; z <= (narrow ? (iz1 + iz2) / 2 : iz2 - 1); z += 4) {
                boolean red = (r.theme() == Theme.HCZ && n % 3 == 2) || r.theme() == Theme.GATE && n % 2 == 1;
                set(x, CEILING, z, (red ? ModBlocks.EMERGENCY_LIGHT : ModBlocks.CEILING_LIGHT).get().defaultBlockState());
                n++;
            }
        }
    }

    /** Places a door leaf `width` cells wide and two blocks tall. EAST/WEST doors run along Z. */
    private void door(Block block, int x, int z, Direction facing, int width, int clearance) {
        boolean alongZ = facing.getAxis() == Direction.Axis.X;
        for (int i = 0; i < width; i++) {
            int dx = alongZ ? x : x + i;
            int dz = alongZ ? z + i : z;
            for (int dy = 0; dy < 2; dy++) {
                set(dx, FEET + dy, dz, block.defaultBlockState()
                        .setValue(KeycardDoorBlock.FACING, facing)
                        .setValue(KeycardDoorBlock.UPPER, dy == 1)
                        .setValue(KeycardDoorBlock.LEVEL, clearance)
                        .setValue(KeycardDoorBlock.OPEN, false));
            }
        }
    }

    private void facing(Block block, BlockPos pos, Direction dir) {
        level.setBlock(pos, block.defaultBlockState().setValue(HorizontalDirectionalBlock.FACING, dir), FLAGS);
    }

    private void desk(int x, int z, Block slab) {
        set(x, FEET, z, slab.defaultBlockState().setValue(SlabBlock.TYPE, SlabType.TOP));
    }

    private void chair(int x, int z, Direction facing) {
        set(x, FEET, z, Blocks.SPRUCE_STAIRS.defaultBlockState().setValue(StairBlock.FACING, facing));
    }

    // ------------------------------------------------------------------ furniture
    private void props() {
        // guard post: reception desk, benches and the Foundation emblem in hazard stripes
        for (int z = -3; z <= 3; z++) desk(4, z, Blocks.POLISHED_ANDESITE_SLAB);
        chair(3, -1, Direction.EAST);
        chair(3, 1, Direction.EAST);
        for (int x = 9; x <= 13; x++) {
            desk(x, -7, Blocks.SMOOTH_STONE_SLAB);
            desk(x, 7, Blocks.SMOOTH_STONE_SLAB);
        }
        fill(6, FLOOR, -1, 10, FLOOR, 1, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());

        for (BlockPos p : ARMORY_LOCKERS) facing(ModBlocks.ARMORY_LOCKER.get(), p, Direction.NORTH);
        for (int x = 28; x <= 38; x += 2) facing(ModBlocks.ARMORY_LOCKER.get(), new BlockPos(x, FEET, 4), Direction.SOUTH);
        for (int z = 7; z <= 11; z++) desk(33, z, Blocks.POLISHED_ANDESITE_SLAB);

        for (BlockPos p : CONTROL_CONSOLES) facing(ModBlocks.CONTROL_CONSOLE.get(), p, Direction.SOUTH);
        for (int x = 63; x <= 75; x++) desk(x, -14, Blocks.POLISHED_ANDESITE_SLAB);
        for (int x = 64; x <= 74; x += 3) chair(x, -13, Direction.NORTH);
        fill(62, FEET + 1, -17, 76, FEET + 3, -17, ModBlocks.FACILITY_GLASS.get().defaultBlockState());

        facing(ModBlocks.RECONTAINMENT_TERMINAL.get(), RECONTAIN_TERMINALS[0], Direction.SOUTH);
        facing(ModBlocks.RECONTAINMENT_TERMINAL.get(), RECONTAIN_TERMINALS[1], Direction.SOUTH);
        facing(ModBlocks.RECONTAINMENT_TERMINAL.get(), RECONTAIN_TERMINALS[2], Direction.WEST);
        for (int x = 84; x <= 94; x += 5) {
            for (int z = -24; z <= -7; z += 6) {
                desk(x, z, Blocks.DARK_OAK_SLAB);
                desk(x + 1, z, Blocks.DARK_OAK_SLAB);
                chair(x, z + 1, Direction.NORTH);
            }
        }

        // SCP-173's cell: stripe ring on the floor
        for (int x = 101; x <= 109; x++) {
            set(x, FLOOR, -26, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());
            set(x, FLOOR, -18, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());
        }

        facing(ModBlocks.MEDICAL_CABINET.get(), MEDICAL_CABINET, Direction.NORTH);
        for (int x = 112; x <= 124; x += 3) {
            set(x, FEET, 15, Blocks.WHITE_WOOL.defaultBlockState());
            set(x, FEET, 14, Blocks.WHITE_CARPET.defaultBlockState());
        }

        for (BlockPos p : GENERATORS_POS) facing(ModBlocks.BACKUP_GENERATOR.get(), p, Direction.NORTH);
        for (int x = 157; x <= 173; x += 4) fill(x, FEET, 8, x + 1, FEET + 2, 9, ModBlocks.METAL_PANEL.get().defaultBlockState());

        facing(ModBlocks.FEMUR_BREAKER.get(), FEMUR_BREAKER, Direction.NORTH);
        fill(180, FEET + 1, 12, 190, FEET + 3, 12, ModBlocks.FACILITY_GLASS.get().defaultBlockState());
        fill(180, FEET, 12, 190, FEET, 12, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());
        fill(183, FEET, 12, 187, FEET, 12, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());

        facing(ModBlocks.O5_SAFE.get(), O5_SAFE, Direction.SOUTH);
        fill(180, FLOOR, -14, 192, FLOOR, -6, Blocks.RED_WOOL.defaultBlockState());
        for (int x = 183; x <= 189; x++) desk(x, -12, Blocks.DARK_OAK_SLAB);
        chair(186, -13, Direction.SOUTH);
        for (int x = 177; x <= 195; x += 2) set(x, FEET, -17, Blocks.BOOKSHELF.defaultBlockState());
        set(186, FEET, -17, ModBlocks.O5_SAFE.get().defaultBlockState().setValue(HorizontalDirectionalBlock.FACING, Direction.SOUTH));

        // Gate B: floodlights and the blast shutter at the far end
        for (int z = -10; z <= 10; z += 5) set(231, FEET + 3, z, Blocks.SEA_LANTERN.defaultBlockState());
        fill(232, FEET, -6, 232, FEET + 3, 6, Blocks.IRON_BARS.defaultBlockState());
        fill(214, FLOOR, -11, 214, FLOOR, 11, ModBlocks.HAZARD_STRIPE.get().defaultBlockState());
    }

    private void signs() {
        sign(32, 2, Direction.NORTH, "armory", 0);
        sign(49, 2, Direction.WEST, "checkpoint", 2);
        sign(68, -2, Direction.SOUTH, "control_room", 2);
        sign(89, -2, Direction.SOUTH, "lcz_office", 3);
        sign(98, -24, Direction.WEST, "chamber_173", 3);
        sign(99, 2, Direction.WEST, "hcz", 3);
        sign(117, 5, Direction.NORTH, "medbay", 3);
        sign(149, 2, Direction.WEST, "hcz_deep", 4);
        sign(164, 2, Direction.NORTH, "generators", 4);
        sign(184, 2, Direction.NORTH, "femur_room", 4);
        sign(185, -2, Direction.SOUTH, "o5_office", 4);
        sign(199, 2, Direction.WEST, "gate_b", 5);
        sign(15, 3, Direction.WEST, "guard_post", 0);
    }

    private void sign(int x, int z, Direction facing, String key, int clearance) {
        BlockPos pos = new BlockPos(x, FEET + 1, z);
        level.setBlock(pos, Blocks.DARK_OAK_WALL_SIGN.defaultBlockState().setValue(WallSignBlock.FACING, facing), Block.UPDATE_ALL);
        if (level.getBlockEntity(pos) instanceof SignBlockEntity sign) {
            SignText text = sign.getFrontText()
                    .setMessage(1, Component.translatable("sign.scpzone19." + key))
                    .setMessage(2, clearance > 0 ? Component.translatable("sign.scpzone19.clearance", clearance) : Component.empty())
                    .setColor(DyeColor.WHITE)
                    .setHasGlowingText(true);
            sign.setText(text, true);
            sign.setWaxed(true);
            sign.setChanged();
        }
    }
}
