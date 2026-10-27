package com.williamgame.blockmemory.worldgen;

import com.mojang.serialization.Codec;
import com.williamgame.blockmemory.BlockMemory;
import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.block.EchoKeystoneBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.RandomizableContainer;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.CandleBlock;
import net.minecraft.world.level.block.ChestBlock;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.Half;
import net.minecraft.world.level.block.state.properties.SlabType;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;
import net.minecraft.world.level.storage.loot.LootTable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Ruins of the Forgotten. Builds an intact building (tower, archive or shrine) in memory, lets time
 * destroy most of it, places what survived and buries an Echo Keystone that remembers the original
 * shape so the Memory Brush can make it rise again as ghosts.
 */
public class ForgottenRuinsFeature extends Feature<NoneFeatureConfiguration> {
    public static final ResourceKey<LootTable> CHEST_LOOT = ResourceKey.create(Registries.LOOT_TABLE, BlockMemory.id("chests/forgotten_ruins"));

    private static final int MAX_RADIUS = 12;

    public ForgottenRuinsFeature(Codec<NoneFeatureConfiguration> codec) {
        super(codec);
    }

    /** Intact design, decay and extras of a single ruin, in absolute coordinates. */
    private static final class Plan {
        final Map<BlockPos, BlockState> design = new LinkedHashMap<>();
        final Set<BlockPos> clear = new HashSet<>();
        final Set<BlockPos> floor = new HashSet<>();
        final Map<BlockPos, BlockState> extras = new LinkedHashMap<>();
        final List<BlockPos> reliquaries = new ArrayList<>();
        BlockPos chest;
        Direction chestFacing = Direction.NORTH;
        final BlockPos origin;

        Plan(BlockPos origin) {
            this.origin = origin;
        }

        BlockPos at(int x, int y, int z) {
            return origin.offset(x, y, z);
        }

        void set(int x, int y, int z, BlockState s) {
            design.put(at(x, y, z), s);
        }

        void floor(int x, int z, BlockState s) {
            BlockPos p = at(x, -1, z);
            design.put(p, s);
            floor.add(p);
        }

        void clear(int x, int y, int z) {
            clear.add(at(x, y, z));
        }
    }

    // ------------------------------------------------------------------ palette helpers

    private static BlockState s(Block b) {
        return b.defaultBlockState();
    }

    private static BlockState bricks() {
        return s(ModRegistry.FADED_BRICKS.get());
    }

    private static BlockState stone() {
        return s(ModRegistry.MEMORY_STONE.get());
    }

    private static BlockState carved() {
        return s(ModRegistry.CARVED_MEMORY_STONE.get());
    }

    private static BlockState pillar() {
        return s(ModRegistry.WHISPERING_PILLAR.get()).setValue(RotatedPillarBlock.AXIS, Direction.Axis.Y);
    }

    private static BlockState slab(SlabType type) {
        return s(ModRegistry.FADED_BRICK_SLAB.get()).setValue(SlabBlock.TYPE, type);
    }

    private static BlockState stairs(Direction facing, Half half) {
        return s(ModRegistry.FADED_BRICK_STAIRS.get()).setValue(StairBlock.FACING, facing).setValue(StairBlock.HALF, half);
    }

    // ------------------------------------------------------------------ placement

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> ctx) {
        WorldGenLevel level = ctx.level();
        RandomSource random = ctx.random();
        BlockPos origin = ctx.origin();

        if (!level.getFluidState(origin).isEmpty() || !level.getFluidState(origin.below()).isEmpty()) return false;
        if (!level.getBlockState(origin.below()).isFaceSturdy(level, origin.below(), Direction.UP)) return false;
        for (int i = 0; i < 8; i++) {
            double a = i * Math.PI / 4;
            int x = origin.getX() + (int) Math.round(Math.cos(a) * 6);
            int z = origin.getZ() + (int) Math.round(Math.sin(a) * 6);
            int y = level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z);
            if (Math.abs(y - origin.getY()) > 4) return false;
            if (!level.getFluidState(new BlockPos(x, y - 1, z)).isEmpty()) return false;
        }

        Plan plan = new Plan(origin);
        int kind = random.nextInt(3);
        String kindName;
        switch (kind) {
            case 0 -> {
                buildTower(plan, random);
                kindName = "tower";
            }
            case 1 -> {
                buildArchive(plan, random);
                kindName = "archive";
            }
            default -> {
                buildShrine(plan, random);
                kindName = "shrine";
            }
        }

        Map<BlockPos, BlockState> finalBlocks = decay(plan, kind, random);

        // clear the inside of the building so terrain does not poke through
        for (BlockPos p : plan.clear) {
            if (!finalBlocks.containsKey(p) && inRange(origin, p)) {
                level.setBlock(p, Blocks.AIR.defaultBlockState(), 2);
            }
        }
        // foundation under the floor
        for (BlockPos p : plan.floor) {
            if (!inRange(origin, p)) continue;
            for (int d = 1; d <= 6; d++) {
                BlockPos below = p.below(d);
                BlockState b = level.getBlockState(below);
                if (!b.isAir() && b.getFluidState().isEmpty() && !b.canBeReplaced()) break;
                level.setBlock(below, random.nextInt(4) == 0 ? s(Blocks.COBBLESTONE) : s(Blocks.STONE), 2);
            }
        }
        // what survived
        for (Map.Entry<BlockPos, BlockState> e : finalBlocks.entrySet()) {
            if (inRange(origin, e.getKey())) level.setBlock(e.getKey(), e.getValue(), 2);
        }
        // little things that were never part of the memory
        for (Map.Entry<BlockPos, BlockState> e : plan.extras.entrySet()) {
            BlockPos p = e.getKey();
            if (inRange(origin, p) && level.getBlockState(p).isAir() && level.getBlockState(p.below()).isFaceSturdy(level, p.below(), Direction.UP)) {
                level.setBlock(p, e.getValue(), 2);
            }
        }
        scatterRubble(level, plan, finalBlocks, random);

        for (BlockPos p : plan.reliquaries) {
            if (inRange(origin, p)) level.setBlock(p, s(ModRegistry.MEMORY_RELIQUARY.get()), 2);
        }
        if (plan.chest != null && inRange(origin, plan.chest)) {
            level.setBlock(plan.chest, s(Blocks.CHEST).setValue(ChestBlock.FACING, plan.chestFacing), 2);
            RandomizableContainer.setBlockEntityLootTable(level, random, plan.chest, CHEST_LOOT);
        }

        // the keystone remembers everything that is gone or changed
        Map<BlockPos, BlockState> memory = new HashMap<>();
        for (Map.Entry<BlockPos, BlockState> e : plan.design.entrySet()) {
            BlockState now = finalBlocks.get(e.getKey());
            if (now != e.getValue()) memory.put(e.getKey(), e.getValue());
        }
        BlockPos keystone = origin.offset(0, -2, 0);
        level.setBlock(keystone, s(ModRegistry.ECHO_KEYSTONE.get()), 2);
        BlockEntity be = level.getBlockEntity(keystone);
        if (be instanceof EchoKeystoneBlockEntity k) {
            k.setMemory(memory, 600 + random.nextInt(2400), kindName);
        }
        return true;
    }

    private static boolean inRange(BlockPos origin, BlockPos p) {
        return Math.abs(p.getX() - origin.getX()) <= MAX_RADIUS && Math.abs(p.getZ() - origin.getZ()) <= MAX_RADIUS;
    }

    // ------------------------------------------------------------------ designs

    private static void buildTower(Plan plan, RandomSource random) {
        int r = 3 + random.nextInt(2);
        int h = 12 + random.nextInt(7);
        Direction door = Direction.Plane.HORIZONTAL.getRandomDirection(random);
        for (int x = -r - 1; x <= r + 1; x++) {
            for (int z = -r - 1; z <= r + 1; z++) {
                double d = Math.sqrt(x * x + z * z);
                if (d > r + 0.5) continue;
                // floor: rings of memory stone with a carved heart
                plan.floor(x, z, d < 1 ? carved() : ((int) d % 2 == 0 ? stone() : bricks()));
                boolean wall = d > r - 0.5;
                for (int y = 0; y < h; y++) {
                    if (wall) {
                        boolean doorway = y < 2 && isDoor(x, z, door, r);
                        boolean window = y % 5 == 2 && (x == 0 || z == 0);
                        if (doorway || window) {
                            plan.clear(x, y, z);
                            continue;
                        }
                        BlockState st = y % 6 == 5 ? carved() : bricks();
                        plan.set(x, y, z, st);
                    } else {
                        plan.clear(x, y, z);
                        if (y > 0 && y % 5 == 4 && d > 1.5) {
                            plan.set(x, y, z, slab(SlabType.TOP)); // inner floors
                        }
                    }
                }
                // crenellations
                if (wall && ((x + z) & 1) == 0) plan.set(x, h, z, bricks());
            }
        }
        // the spine: a whispering pillar through the middle of the tower
        for (int y = 0; y < h - 1; y++) plan.set(0, y, 0, pillar());
        plan.set(0, h - 1, 0, carved());
        // cap
        plan.set(0, h, 0, s(Blocks.SOUL_LANTERN));
        plan.reliquaries.add(plan.at(r - 1 == 2 ? 1 : 2, 0, 0));
        if (random.nextFloat() < 0.5F) {
            plan.chest = plan.at(-1, 0, r - 2 > 0 ? r - 2 : 1);
            plan.chestFacing = Direction.EAST;
        }
        plan.extras.put(plan.at(0, 0, -(r - 1)), s(Blocks.CANDLE).setValue(CandleBlock.CANDLES, 1 + random.nextInt(4)));
    }

    private static boolean isDoor(int x, int z, Direction door, int r) {
        return switch (door) {
            case NORTH -> x == 0 && z < 0;
            case SOUTH -> x == 0 && z > 0;
            case WEST -> z == 0 && x < 0;
            default -> z == 0 && x > 0;
        };
    }

    private static void buildArchive(Plan plan, RandomSource random) {
        int hw = 3 + random.nextInt(2);   // half width (x)
        int hl = 5 + random.nextInt(2);   // half length (z)
        int wallH = 5;
        for (int x = -hw; x <= hw; x++) {
            for (int z = -hl; z <= hl; z++) {
                boolean edgeX = Math.abs(x) == hw;
                boolean edgeZ = Math.abs(z) == hl;
                plan.floor(x, z, ((x + z) & 1) == 0 ? stone() : bricks());
                for (int y = 0; y < wallH; y++) {
                    if (edgeX || edgeZ) {
                        boolean corner = edgeX && edgeZ;
                        boolean midPillar = edgeX && z % 3 == 0;
                        boolean doorway = edgeZ && z < 0 && x == 0 && y < 3;
                        boolean window = edgeX && !midPillar && y == 2 && Math.abs(z) % 3 == 1;
                        if (doorway || window) {
                            plan.clear(x, y, z);
                        } else if (corner || midPillar) {
                            plan.set(x, y, z, pillar());
                        } else {
                            plan.set(x, y, z, y == wallH - 1 ? carved() : bricks());
                        }
                    } else {
                        plan.clear(x, y, z);
                        // shelves of memory along the long walls
                        if (Math.abs(x) == hw - 1 && y >= 0 && y <= 2 && Math.abs(z) < hl - 1 && z % 3 != 0) {
                            plan.set(x, y, z, y == 2 ? slab(SlabType.BOTTOM) : s(Blocks.BOOKSHELF));
                        }
                    }
                }
            }
        }
        // gable roof along z, stairs climbing from both long sides
        for (int z = -hl; z <= hl; z++) {
            for (int i = 0; i <= hw; i++) {
                int y = wallH + i;
                if (i < hw) {
                    plan.set(-hw + i, y, z, stairs(Direction.EAST, Half.BOTTOM));
                    plan.set(hw - i, y, z, stairs(Direction.WEST, Half.BOTTOM));
                    if (Math.abs(z) == hl) {
                        for (int x = -hw + i + 1; x < hw - i; x++) plan.set(x, y, z, bricks());
                    }
                } else {
                    plan.set(0, y, z, slab(SlabType.BOTTOM));
                }
            }
        }
        // lectern of the archivist and a reliquary in the apse
        plan.set(0, 0, hl - 2, carved());
        plan.reliquaries.add(plan.at(0, 1, hl - 2));
        plan.extras.put(plan.at(0, 0, hl - 4), s(Blocks.LECTERN));
        if (random.nextFloat() < 0.7F) {
            plan.chest = plan.at(-(hw - 1), 0, -(hl - 1));
            plan.chestFacing = Direction.SOUTH;
        }
        if (random.nextBoolean()) plan.reliquaries.add(plan.at(hw - 1, 0, -(hl - 1)));
        for (int i = 0; i < 4; i++) {
            int x = random.nextInt(hw * 2 - 1) - (hw - 1);
            int z = random.nextInt(hl * 2 - 1) - (hl - 1);
            plan.extras.put(plan.at(x, 0, z), random.nextBoolean() ? s(Blocks.MOSS_CARPET) : s(Blocks.COBWEB));
        }
    }

    private static void buildShrine(Plan plan, RandomSource random) {
        int r = 5 + random.nextInt(2);
        int pillars = random.nextBoolean() ? 6 : 8;
        int ph = 4 + random.nextInt(3);
        for (int x = -r; x <= r; x++) {
            for (int z = -r; z <= r; z++) {
                double d = Math.sqrt(x * x + z * z);
                if (d > r + 0.3) continue;
                BlockState f = d < 1.5 ? carved() : (Math.abs(d - 3) < 0.5 ? stone() : bricks());
                plan.floor(x, z, f);
                for (int y = 0; y <= ph + 1; y++) plan.clear(x, y, z);
                if (d > r - 0.7) plan.set(x, 0, z, slab(SlabType.BOTTOM)); // low rim
            }
        }
        int pr = r - 1;
        List<BlockPos> tops = new ArrayList<>();
        for (int i = 0; i < pillars; i++) {
            double a = i * Math.PI * 2 / pillars;
            int x = (int) Math.round(Math.cos(a) * pr);
            int z = (int) Math.round(Math.sin(a) * pr);
            for (int y = 0; y < ph; y++) plan.set(x, y, z, pillar());
            plan.set(x, ph, z, carved());
            tops.add(plan.at(x, ph, z));
        }
        // lintel ring connecting the pillar tops
        for (int i = 0; i < 64; i++) {
            double a = i * Math.PI * 2 / 64;
            int x = (int) Math.round(Math.cos(a) * pr);
            int z = (int) Math.round(Math.sin(a) * pr);
            BlockPos p = plan.at(x, ph, z);
            if (!plan.design.containsKey(p)) plan.design.put(p, slab(SlabType.BOTTOM));
        }
        // altar
        plan.set(0, 0, 0, carved());
        for (Direction d : Direction.Plane.HORIZONTAL) {
            plan.set(d.getStepX(), 0, d.getStepZ(), stairs(d.getOpposite(), Half.BOTTOM));
        }
        plan.reliquaries.add(plan.at(0, 1, 0));
        for (Direction d : Direction.Plane.HORIZONTAL) {
            BlockPos c = plan.at(d.getStepX() * 2, 0, d.getStepZ() * 2);
            if (random.nextBoolean()) plan.extras.put(c, s(Blocks.CANDLE).setValue(CandleBlock.CANDLES, 1 + random.nextInt(4)));
        }
        if (random.nextFloat() < 0.35F) {
            plan.chest = plan.at(0, 0, -(r - 2));
            plan.chestFacing = Direction.SOUTH;
        }
    }

    // ------------------------------------------------------------------ decay

    private static Map<BlockPos, BlockState> decay(Plan plan, int kind, RandomSource random) {
        Map<BlockPos, BlockState> out = new LinkedHashMap<>();
        BlockPos o = plan.origin;
        double collapseDir = random.nextDouble() * Math.PI * 2;
        int maxY = 0;
        for (BlockPos p : plan.design.keySet()) maxY = Math.max(maxY, p.getY() - o.getY());
        double survive = 0.35 + random.nextDouble() * 0.25; // fraction of height that survives on the low side
        Map<Long, Integer> pillarBreak = new HashMap<>();

        for (Map.Entry<BlockPos, BlockState> e : plan.design.entrySet()) {
            BlockPos p = e.getKey();
            BlockState st = e.getValue();
            int dx = p.getX() - o.getX(), dy = p.getY() - o.getY(), dz = p.getZ() - o.getZ();
            boolean keep;
            if (dy < 0) {
                keep = random.nextFloat() > 0.06F; // floors survive almost intact
            } else if (kind == 0) {
                // tower: jagged collapse, lower on one side
                double ang = Math.atan2(dz, dx);
                double side = (Math.cos(ang - collapseDir) + 1) / 2; // 0..1
                double cut = maxY * (survive + 0.45 * side) + random.nextInt(3) - 1;
                keep = dy < cut && random.nextFloat() > 0.08F;
            } else if (kind == 1) {
                // archive: roof caved in, one end of the hall fallen
                double along = (dz + 8) / 16.0;
                double cut = 2 + (maxY - 2) * Mth.clamp(along * 1.4 - 0.2 + (Math.cos(collapseDir) * 0.3), 0.1, 1.0);
                boolean roof = dy >= 5;
                keep = dy < cut && random.nextFloat() > (roof ? 0.75F : 0.15F);
            } else {
                // shrine: pillars broken at random heights, lintel mostly gone
                long col = ((long) dx << 32) ^ (dz & 0xFFFFFFFFL);
                int brk = pillarBreak.computeIfAbsent(col, c -> 1 + random.nextInt(6));
                boolean lintel = st.getBlock() == ModRegistry.FADED_BRICK_SLAB.get() && dy > 1;
                keep = lintel ? random.nextFloat() < 0.3F : dy < brk + 1 || dy == 0;
                if (keep && random.nextFloat() < 0.05F) keep = false;
            }
            if (!keep) continue;
            out.put(p, weather(st, random));
        }
        return out;
    }

    private static BlockState weather(BlockState st, RandomSource random) {
        Block b = st.getBlock();
        if (b == ModRegistry.FADED_BRICKS.get()) {
            float f = random.nextFloat();
            if (f < 0.25F) return s(ModRegistry.CRACKED_FADED_BRICKS.get());
            if (f < 0.45F) return s(ModRegistry.MOSSY_FADED_BRICKS.get());
        } else if (b == Blocks.BOOKSHELF && random.nextFloat() < 0.5F) {
            return random.nextBoolean() ? s(Blocks.COBWEB) : s(ModRegistry.CRACKED_FADED_BRICKS.get());
        } else if (b == ModRegistry.MEMORY_STONE.get() && random.nextFloat() < 0.15F) {
            return s(Blocks.COBBLED_DEEPSLATE);
        }
        return st;
    }

    private static void scatterRubble(WorldGenLevel level, Plan plan, Map<BlockPos, BlockState> finalBlocks, RandomSource random) {
        int removed = plan.design.size() - finalBlocks.size();
        int count = Math.min(36, removed / 5);
        BlockPos o = plan.origin;
        for (int i = 0; i < count; i++) {
            int x = o.getX() + random.nextInt(MAX_RADIUS * 2 - 3) - (MAX_RADIUS - 2);
            int z = o.getZ() + random.nextInt(MAX_RADIUS * 2 - 3) - (MAX_RADIUS - 2);
            int y = level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z);
            BlockPos p = new BlockPos(x, y, z);
            if (Math.abs(y - o.getY()) > 6 || plan.design.containsKey(p)) continue;
            BlockState at = level.getBlockState(p);
            BlockPos below = p.below();
            if (!(at.isAir() || at.canBeReplaced()) || !level.getFluidState(p).isEmpty()) continue;
            if (!level.getBlockState(below).isFaceSturdy(level, below, Direction.UP)) continue;
            float f = random.nextFloat();
            BlockState rubble = f < 0.3F ? slab(SlabType.BOTTOM)
                    : f < 0.55F ? s(ModRegistry.CRACKED_FADED_BRICKS.get())
                    : f < 0.7F ? s(ModRegistry.MOSSY_FADED_BRICKS.get())
                    : f < 0.85F ? s(Blocks.COBBLESTONE)
                    : s(Blocks.MOSSY_COBBLESTONE);
            level.setBlock(p, rubble, 2);
        }
    }
}
