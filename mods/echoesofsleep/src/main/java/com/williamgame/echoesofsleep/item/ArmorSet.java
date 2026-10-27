package com.williamgame.echoesofsleep.item;

import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;

/** The three dream armor sets and their full-set check. */
public enum ArmorSet {
    DREAMCATCHER("dreamcatcher"),
    WAKEFUL("wakeful"),
    NIGHTMARE_EATER("nightmare_eater");

    private final String name;

    ArmorSet(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public boolean isWornBy(LivingEntity entity) {
        for (EquipmentSlot slot : new EquipmentSlot[]{EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET}) {
            ItemStack s = entity.getItemBySlot(slot);
            if (!(s.getItem() instanceof DreamArmorItem a) || a.getSet() != this) return false;
        }
        return true;
    }
}
