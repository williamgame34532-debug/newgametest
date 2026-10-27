package com.williamgame.symbiont;

import net.minecraftforge.common.ForgeConfigSpec;

public class SymbiontConfig {
    public static final ForgeConfigSpec.Builder BUILDER = new ForgeConfigSpec.Builder();

    // --- general
    public static final ForgeConfigSpec.BooleanValue GIVE_EGG_ON_FIRST_JOIN;
    public static final ForgeConfigSpec.BooleanValue ALLOW_NEW_EGG_AFTER_LEAVING;

    // --- affinity XP
    public static final ForgeConfigSpec.DoubleValue XP_MULT_MINER;
    public static final ForgeConfigSpec.DoubleValue XP_MULT_WARRIOR;
    public static final ForgeConfigSpec.DoubleValue XP_MULT_FARMER;
    public static final ForgeConfigSpec.DoubleValue XP_MULT_EXPLORER;
    public static final ForgeConfigSpec.DoubleValue XP_ORE;
    public static final ForgeConfigSpec.DoubleValue XP_STONE;
    public static final ForgeConfigSpec.DoubleValue XP_KILL_MONSTER;
    public static final ForgeConfigSpec.DoubleValue XP_KILL_OTHER;
    public static final ForgeConfigSpec.DoubleValue XP_HARVEST;
    public static final ForgeConfigSpec.DoubleValue XP_BREED;
    public static final ForgeConfigSpec.DoubleValue XP_PLANT;
    public static final ForgeConfigSpec.DoubleValue XP_NEW_CHUNK;
    public static final ForgeConfigSpec.DoubleValue XP_NEW_BIOME;
    public static final ForgeConfigSpec.DoubleValue XP_NEW_DIMENSION;

    // --- evolution
    public static final ForgeConfigSpec.IntValue STAGE1_XP;
    public static final ForgeConfigSpec.IntValue STAGE2_XP;
    public static final ForgeConfigSpec.IntValue STAGE3_XP;
    public static final ForgeConfigSpec.IntValue STAGE1_BOND;
    public static final ForgeConfigSpec.IntValue STAGE2_BOND;
    public static final ForgeConfigSpec.IntValue STAGE3_BOND;

    // --- bond and neglect
    public static final ForgeConfigSpec.BooleanValue NEGLECT_ENABLED;
    public static final ForgeConfigSpec.IntValue HUNGER_INTERVAL_TICKS;
    public static final ForgeConfigSpec.IntValue STARVING_BOND_LOSS_INTERVAL_TICKS;
    public static final ForgeConfigSpec.IntValue LEAVE_AFTER_TICKS_AT_ZERO_BOND;
    public static final ForgeConfigSpec.IntValue TOGETHER_BOND_INTERVAL_TICKS;
    public static final ForgeConfigSpec.IntValue PET_COOLDOWN_TICKS;
    public static final ForgeConfigSpec.IntValue DEATH_BOND_LOSS;
    public static final ForgeConfigSpec.IntValue RESPAWN_TICKS_NEST;
    public static final ForgeConfigSpec.IntValue RESPAWN_TICKS_NO_NEST;

    // --- abilities
    public static final ForgeConfigSpec.BooleanValue VEIN_MINE_ENABLED;
    public static final ForgeConfigSpec.IntValue VEIN_MINE_STAGE2;
    public static final ForgeConfigSpec.IntValue VEIN_MINE_STAGE3;
    public static final ForgeConfigSpec.BooleanValue STRUCTURE_REVEAL_ENABLED;
    public static final ForgeConfigSpec.BooleanValue OWNER_BUFFS_ENABLED;

    static {
        BUILDER.push("general");
        GIVE_EGG_ON_FIRST_JOIN = BUILDER.comment("Give every player a Symbiont Egg the first time they join").define("giveEggOnFirstJoin", true);
        ALLOW_NEW_EGG_AFTER_LEAVING = BUILDER.comment("Allow hatching a NEW symbiont (crafted egg) after the old one left forever").define("allowNewEggAfterLeaving", true);
        BUILDER.pop();

        BUILDER.push("affinity");
        XP_MULT_MINER = BUILDER.comment("Global multiplier for Miner affinity").defineInRange("minerMultiplier", 1.0, 0.0, 100.0);
        XP_MULT_WARRIOR = BUILDER.comment("Global multiplier for Warrior affinity").defineInRange("warriorMultiplier", 1.0, 0.0, 100.0);
        XP_MULT_FARMER = BUILDER.comment("Global multiplier for Farmer affinity").defineInRange("farmerMultiplier", 1.0, 0.0, 100.0);
        XP_MULT_EXPLORER = BUILDER.comment("Global multiplier for Explorer affinity").defineInRange("explorerMultiplier", 1.0, 0.0, 100.0);
        XP_ORE = BUILDER.comment("Miner XP per ore block broken").defineInRange("oreXp", 4.0, 0.0, 1000.0);
        XP_STONE = BUILDER.comment("Miner XP per other pickaxe block broken").defineInRange("stoneXp", 0.2, 0.0, 1000.0);
        XP_KILL_MONSTER = BUILDER.comment("Warrior XP per hostile mob killed (by you or the symbiont)").defineInRange("monsterKillXp", 5.0, 0.0, 1000.0);
        XP_KILL_OTHER = BUILDER.comment("Warrior XP per other living thing killed").defineInRange("otherKillXp", 1.0, 0.0, 1000.0);
        XP_HARVEST = BUILDER.comment("Farmer XP per fully grown crop harvested").defineInRange("harvestXp", 2.0, 0.0, 1000.0);
        XP_BREED = BUILDER.comment("Farmer XP per animal bred").defineInRange("breedXp", 6.0, 0.0, 1000.0);
        XP_PLANT = BUILDER.comment("Farmer XP per crop/sapling planted or bone-mealed").defineInRange("plantXp", 0.5, 0.0, 1000.0);
        XP_NEW_CHUNK = BUILDER.comment("Explorer XP per never-visited chunk").defineInRange("newChunkXp", 1.5, 0.0, 1000.0);
        XP_NEW_BIOME = BUILDER.comment("Explorer XP per newly discovered biome").defineInRange("newBiomeXp", 15.0, 0.0, 1000.0);
        XP_NEW_DIMENSION = BUILDER.comment("Explorer XP per newly visited dimension").defineInRange("newDimensionXp", 60.0, 0.0, 10000.0);
        BUILDER.pop();

        BUILDER.push("evolution");
        STAGE1_XP = BUILDER.comment("Affinity XP needed to leave the Hatchling form (dominant branch is chosen)").defineInRange("stage1Xp", 60, 1, 1000000);
        STAGE2_XP = BUILDER.comment("Branch XP needed for stage 2").defineInRange("stage2Xp", 350, 1, 1000000);
        STAGE3_XP = BUILDER.comment("Branch XP needed for stage 3").defineInRange("stage3Xp", 1200, 1, 1000000);
        STAGE1_BOND = BUILDER.comment("Bond needed for stage 1").defineInRange("stage1Bond", 20, 0, 100);
        STAGE2_BOND = BUILDER.comment("Bond needed for stage 2").defineInRange("stage2Bond", 45, 0, 100);
        STAGE3_BOND = BUILDER.comment("Bond needed for stage 3").defineInRange("stage3Bond", 65, 0, 100);
        BUILDER.pop();

        BUILDER.push("bond");
        NEGLECT_ENABLED = BUILDER.comment("If false the symbiont never gets hungry, never loses bond from neglect and never leaves").define("neglectEnabled", true);
        HUNGER_INTERVAL_TICKS = BUILDER.comment("Ticks (while its owner is online) for satiety to drop by 1 (100 = full). 480 = full to empty in ~2 in-game days").defineInRange("hungerIntervalTicks", 480, 20, 1000000);
        STARVING_BOND_LOSS_INTERVAL_TICKS = BUILDER.comment("While starving, bond drops by 1 every this many ticks").defineInRange("starvingBondLossIntervalTicks", 600, 20, 1000000);
        LEAVE_AFTER_TICKS_AT_ZERO_BOND = BUILDER.comment("Ticks spent at 0 bond before the symbiont leaves forever").defineInRange("leaveAfterTicksAtZeroBond", 6000, 20, 10000000);
        TOGETHER_BOND_INTERVAL_TICKS = BUILDER.comment("Staying close to it gives +1 bond every this many ticks").defineInRange("togetherBondIntervalTicks", 2400, 20, 1000000);
        PET_COOLDOWN_TICKS = BUILDER.comment("Cooldown between petting bond gains").defineInRange("petCooldownTicks", 1200, 0, 1000000);
        DEATH_BOND_LOSS = BUILDER.comment("Bond lost when the symbiont dies (halved with a Nest)").defineInRange("deathBondLoss", 20, 0, 100);
        RESPAWN_TICKS_NEST = BUILDER.comment("Respawn time when a Symbiont Nest is bound").defineInRange("respawnTicksWithNest", 1200, 20, 1000000);
        RESPAWN_TICKS_NO_NEST = BUILDER.comment("Respawn time without a Nest").defineInRange("respawnTicksWithoutNest", 6000, 20, 1000000);
        BUILDER.pop();

        BUILDER.push("abilities");
        VEIN_MINE_ENABLED = BUILDER.comment("Miner symbionts (stage 2+) mine connected ore veins with you (sneak to mine a single block)").define("veinMine", true);
        VEIN_MINE_STAGE2 = BUILDER.comment("Max extra ores mined at stage 2").defineInRange("veinMineStage2", 8, 0, 256);
        VEIN_MINE_STAGE3 = BUILDER.comment("Max extra ores mined at stage 3").defineInRange("veinMineStage3", 24, 0, 256);
        STRUCTURE_REVEAL_ENABLED = BUILDER.comment("Explorer symbionts can sense the nearest structure (uses structure search, may be slow on huge modpacks)").define("structureReveal", true);
        OWNER_BUFFS_ENABLED = BUILDER.comment("Stage-3 symbionts give their owner a small potion buff while close").define("ownerBuffs", true);
        BUILDER.pop();
    }

    public static final ForgeConfigSpec SPEC = BUILDER.build();

    public static double branchMultiplier(Branch b) {
        return switch (b) {
            case MINER -> XP_MULT_MINER.get();
            case WARRIOR -> XP_MULT_WARRIOR.get();
            case FARMER -> XP_MULT_FARMER.get();
            case EXPLORER -> XP_MULT_EXPLORER.get();
        };
    }

    public static int stageXp(int stage) {
        return switch (stage) {
            case 1 -> STAGE1_XP.get();
            case 2 -> STAGE2_XP.get();
            default -> STAGE3_XP.get();
        };
    }

    public static int stageBond(int stage) {
        return switch (stage) {
            case 1 -> STAGE1_BOND.get();
            case 2 -> STAGE2_BOND.get();
            default -> STAGE3_BOND.get();
        };
    }
}
