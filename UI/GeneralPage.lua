--[[
Página General
==============

Opciones para cualquier clase en /sdeck config, debajo de Teclas. Como las
secciones de clase (UI/ClassPages), solo describe las filas (ver
UI/OptionsPage.lua); el estado lo guardan los módulos de Features/.
]]

local _, ns = ...

ns.GeneralPage = {
    title = "General",
    rows = {
        { kind = "header", label = "Al abrir un vendedor" },
        {
            kind = "check",
            label = "Reparar el equipo",
            tooltip = {
                "Reparar solo",
                "Repara todo el equipo si el vendedor repara y te llega el dinero.",
                "Lo que cuesta sale en el chat. También con /sdeck reparar.",
            },
            get = function() return ns.Merchant.IsRepairEnabled() end,
            set = function(on) ns.Merchant.SetRepairEnabled(on) end,
        },
        {
            kind = "check",
            label = "Vender la basura (objetos grises)",
            tooltip = {
                "Vender la basura",
                "Vende los objetos grises que el vendedor compra; nada blanco o mejor.",
                "Lo que da sale en el chat. También con /sdeck basura.",
            },
            get = function() return ns.Merchant.IsJunkEnabled() end,
            set = function(on) ns.Merchant.SetJunkEnabled(on) end,
        },
        { kind = "note", text = "Primero vende y después repara, así cuenta con lo que da la basura. Abre el vendedor con Mayús pulsada para que no haga nada." },
    },
}
