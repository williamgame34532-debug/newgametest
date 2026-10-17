package com.zone19.scp.registry;

import com.zone19.scp.Zone19Mod;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.RegistryObject;

public final class ModTabs {
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, Zone19Mod.MODID);

    public static final RegistryObject<CreativeModeTab> MAIN = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.scpzone19"))
            .icon(() -> new ItemStack(ModItems.KEYCARD_5.get()))
            .displayItems((params, out) -> ModItems.ITEMS.getEntries().forEach(i -> out.accept(i.get())))
            .build());

    private ModTabs() {
    }
}
