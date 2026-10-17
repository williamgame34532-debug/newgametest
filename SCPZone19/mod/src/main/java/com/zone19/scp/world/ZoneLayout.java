package com.zone19.scp.world;

import net.minecraft.core.BlockPos;
import net.minecraft.world.phys.AABB;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Floor plan of Site-19's security wing, built in the scpzone19:zone19 dimension.
 * Room bounds are the outer walls (inclusive); the walkable interior is one block inside.
 *
 * <pre>
 *            [control]  [office ][173]          [ O5 ]
 * [post]=====corridor LCZ=========##==HCZ hall==##===HCZ corridor===##[ GATE B ]
 *        [armory]                     [medbay]   [generators][femur]
 * </pre>
 */
public final class ZoneLayout {
    public static final int FLOOR = 64;
    public static final int FEET = FLOOR + 1;
    public static final int CEILING = FLOOR + 6;

    public enum Theme { ENTRANCE, LCZ, OFFICE, HCZ, GATE }

    public record Room(String id, int x1, int z1, int x2, int z2, Theme theme) {
        public AABB interior() {
            return new AABB(x1 + 1, FEET, z1 + 1, x2, CEILING, z2);
        }

        public BlockPos center() {
            return new BlockPos((x1 + x2) / 2, FEET, (z1 + z2) / 2);
        }
    }

    public static final Room GUARD_POST = new Room("guard_post", 0, -8, 16, 8, Theme.ENTRANCE);
    public static final Room CORRIDOR_LCZ = new Room("corridor_lcz", 16, -3, 100, 3, Theme.LCZ);
    public static final Room ARMORY = new Room("armory", 26, 3, 40, 15, Theme.LCZ);
    public static final Room CONTROL = new Room("control_room", 60, -18, 78, -3, Theme.LCZ);
    public static final Room OFFICE = new Room("lcz_office", 80, -28, 99, -3, Theme.OFFICE);
    public static final Room CHAMBER_173 = new Room("chamber_173", 99, -28, 111, -16, Theme.HCZ);
    public static final Room HCZ_HALL = new Room("hcz_hall", 100, -6, 150, 6, Theme.HCZ);
    public static final Room MEDBAY = new Room("medbay", 110, 6, 126, 18, Theme.LCZ);
    public static final Room CORRIDOR_HCZ = new Room("corridor_hcz", 150, -3, 200, 3, Theme.HCZ);
    public static final Room GENERATORS = new Room("generators", 155, 3, 175, 22, Theme.HCZ);
    public static final Room FEMUR = new Room("femur_room", 178, 3, 192, 16, Theme.HCZ);
    public static final Room O5 = new Room("o5_office", 176, -18, 196, -3, Theme.OFFICE);
    public static final Room GATE_B = new Room("gate_b", 200, -12, 232, 12, Theme.GATE);

    public static final List<Room> ROOMS = List.of(GUARD_POST, CORRIDOR_LCZ, ARMORY, CONTROL, OFFICE, CHAMBER_173,
            HCZ_HALL, MEDBAY, CORRIDOR_HCZ, GENERATORS, FEMUR, O5, GATE_B);

    /** Story trigger volumes. */
    public static final Map<String, AABB> REGIONS = new LinkedHashMap<>();

    static {
        for (Room r : ROOMS) REGIONS.put(r.id(), r.interior());
        REGIONS.put("lcz_checkpoint", new AABB(51, FEET, -2, 57, CEILING, 3));
        REGIONS.put("gate_exit", new AABB(214, FEET, -11, 232, CEILING, 12));
    }

    // story props
    public static final BlockPos SPAWN = new BlockPos(8, FEET, 0);
    public static final BlockPos[] ARMORY_LOCKERS = {new BlockPos(30, FEET, 14), new BlockPos(33, FEET, 14), new BlockPos(36, FEET, 14)};
    public static final BlockPos[] CONTROL_CONSOLES = {new BlockPos(66, FEET, -17), new BlockPos(69, FEET, -17), new BlockPos(72, FEET, -17)};
    public static final BlockPos[] RECONTAIN_TERMINALS = {new BlockPos(82, FEET, -27), new BlockPos(97, FEET, -27), new BlockPos(98, FEET, -10)};
    public static final BlockPos MEDICAL_CABINET = new BlockPos(118, FEET, 17);
    public static final BlockPos[] GENERATORS_POS = {new BlockPos(158, FEET, 21), new BlockPos(172, FEET, 21)};
    public static final BlockPos FEMUR_BREAKER = new BlockPos(185, FEET, 15);
    public static final BlockPos O5_SAFE = new BlockPos(186, FEET, -17);

    // SCP spawn points
    public static final BlockPos SCP173_SPAWN = new BlockPos(90, FEET, -16);
    public static final BlockPos SCP106_SPAWN = new BlockPos(176, FEET, 0);
    public static final BlockPos SCP096_SPAWN = new BlockPos(196, FEET, 2);
    public static final BlockPos[] SCP049_2_SPAWNS = {
            new BlockPos(112, FEET, -3), new BlockPos(119, FEET, 3), new BlockPos(126, FEET, -4),
            new BlockPos(133, FEET, 2), new BlockPos(140, FEET, -2), new BlockPos(146, FEET, 4)};

    /** Respawn / chapter start positions, index = chapter number. */
    public static final BlockPos[] CHECKPOINTS = {
            SPAWN, SPAWN, new BlockPos(53, FEET, 0), new BlockPos(95, FEET, 0), new BlockPos(88, FEET, 0),
            new BlockPos(147, FEET, 0), new BlockPos(160, FEET, 0)};

    public static BlockPos checkpoint(int chapter) {
        return CHECKPOINTS[Math.max(0, Math.min(CHECKPOINTS.length - 1, chapter))];
    }

    public static BlockPos regionCenter(String id) {
        AABB box = REGIONS.get(id);
        if (box == null) return SPAWN;
        return BlockPos.containing(box.getCenter().x, FEET, box.getCenter().z);
    }

    private ZoneLayout() {
    }
}
