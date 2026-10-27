package com.williamgame.echoesofsleep.registry;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.RegistryObject;

public class ModTabs {
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, EchoesOfSleep.MODID);

    public static final RegistryObject<CreativeModeTab> MAIN = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.echoesofsleep"))
            .icon(() -> new ItemStack(ModItems.DREAM_TOTEM.get()))
            .displayItems((params, output) -> {
                for (var obj : ModItems.TAB_ORDER) {
                    output.accept(obj.get());
                }
            }).build());
}
