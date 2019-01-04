local L = LibStub("AceLocale-3.0"):GetLocale("Emotive")

local options = {
    name = "Emotive",
    handler = Emotive,
    type = "group",
    args = {
        dropdown = {
            type = "toggle",
            name = L["Show Dropdown"],
            desc = L["Toggles the display of the Emotive dropdown menu."],
            get = "IsShowDropdown",
            set = "ToggleShowDropdown",
        },
        minimap = {
            type = "toggle",
            name = L["Show Minimap"],
            desc = L["Toggles the display of the Emotive minimap icon."],
            get = "IsShowMinimap",
            set = "ToggleShowMinimap"
        }
    },
}

local defaults = {
    profile = {
        minimap = {
            hide = false
        },
        menu = {
            hide = false
        },
        recent = {},
    },
}

function Emotive:OnInitialize()
    Emotive.db = LibStub("AceDB-3.0"):New("EmotiveDB", defaults, true)

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Emotive", options)
    Emotive.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Emotive", "Emotive")
    Emotive:RegisterChatCommand("emotive", "ChatCommand")

    Emotive.ldb = LibStub("LibDataBroker-1.1"):NewDataObject("Emotive", {
        type = "data source",
        text = "Emotive",
        icon = "Interface\\AddOns\\" .. Emotive.name .. "\\images\\" .. Emotive.name,
        OnClick = function(self, button)
            if button == "RightButton" then
                InterfaceOptionsFrame_OpenToCategory(Emotive.optionsFrame)
            else
                Emotive.ToggleEmotesList()
            end
        end,
    })

    Emotive.icon = LibStub("LibDBIcon-1.0")
    Emotive.icon:Register("Emotive", Emotive.ldb, Emotive.db.profile.minimap)

    if (not Emotive.db.profile.menu.hide) then
        Emotive.InitializeMenu()
    end
end

function Emotive:ChatCommand(input)
    if not input or input:trim() == "" then
        InterfaceOptionsFrame_OpenToCategory(Emotive.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("emotive", "Emotive", input)
    end
end

function Emotive:IsShowDropdown(info)
    return not Emotive.db.profile.menu.hide
end

function Emotive:ToggleShowDropdown(info, value)
    Emotive.db.profile.menu.hide = value
    Emotive.ToggleEmotesList()
end

function Emotive:IsShowMinimap(info)
    return not Emotive.db.profile.minimap.hide
end

function Emotive:ToggleShowMinimap(info, value)
    Emotive.db.profile.minimap.hide = value
    Emotive.ToggleMinimap()
end

function Emotive:InitializeMenu()
    if (Emotive.menu and Emotive.menu:IsShown()) then
        return
    else
        Emotive.ToggleEmotesList()
    end
end

function Emotive:SendEmote(emote)
    DEFAULT_CHAT_FRAME.editBox:SetText("/" .. emote)
    ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)

    local index = {}
    for k,v in pairs(Emotive.db.profile.recent) do
        index[v]=k
    end

    if (index[emote] ~= nil) then
        table.remove(Emotive.db.profile.recent, index[emote])
        table.insert(Emotive.db.profile.recent, 1, emote);
    else
        table.insert(Emotive.db.profile.recent, 1, emote)
    end

    while #Emotive.db.profile.recent > 5 do
        table.remove(Emotive.db.profile.recent, #Emotive.db.profile.recent)
    end

    CloseDropDownMenus()
end

function Emotive:ToggleMinimap()
    if (not Emotive.icon) then
        return
    end

    if (Emotive.db.profile.minimap.hide) then
        Emotive.db.profile.minimap.hide = false
        Emotive.icon:Show("Emotive")
    else
        Emotive.db.profile.minimap.hide = true
        Emotive.icon:Hide("Emotive")
    end
end

function Emotive:ToggleEmotesList()
    if (Emotive.menu and Emotive.db.profile.menu.hide) then
        Emotive.db.profile.menu.hide = false
        Emotive.menu:Show()
    elseif (Emotive.menu) then
        Emotive.db.profile.menu.hide = true
        Emotive.menu:Hide()
    else
        function AddRecent()
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.hasArrow, info.notCheckable, info.menuList = L["Recent"], true, 1, "RECENT"
            UIDropDownMenu_AddButton(info)
        end

        function AddSeparator(level)
            UIDropDownMenu_AddSeparator(level)
        end

        function AddEmote(emote, level)
            local _, raceEn = UnitRace("player")
            local targetName, _ = UnitName("target")
            local info = UIDropDownMenu_CreateInfo()
            local descriptor = "Text"
            local key = string.upper(string.sub(emote, 1, 1))

            if Emotive.emotesByLetter[key] == nil then
                return
            end

            if Emotive.emotesByLetter[key][emote] == nil then
                return
            end

            local definition = Emotive.emotesByLetter[key][emote]

            if definition["Animation"] and definition["Voice"] then
                info.colorCode = "|cff1eff00"
                descriptor = L["Animation"] .. "/" .. L["Voice"]
            elseif definition["Animation"] then
                info.colorCode = "|cff9482c9"
                descriptor = L["Animation"]
            elseif definition["Voice"] then
                info.colorCode = "|cffff8000"
                descriptor = L["Voice"]
            end

            info.tooltipTitle = L["Self"] .. " (" .. descriptor .. ")"
            info.tooltipText = L[emote]["Self"]

            if (targetName ~= nil) then
                info.tooltipTitle = L["Target"] .. " (" .. descriptor .. ")"
                info.tooltipText = L[emote]["Target"](targetName)
            end

            info.text, info.func, info.notCheckable, info.arg1, info.tooltipOnButton, info.tooltipWhileDisabled = emote, Emotive.SendEmote, 1, emote, 1, 1

            --- Disable clicking if player doesn't meet restrictions
            if definition["Restrictions"] ~= nil and definition["Restrictions"]["race"] ~= nil and definition["Restrictions"]["race"] ~= raceEn then
                info.tooltipTitle = info.tooltipTitle .. " [" .. L["X Only"](definition["Restrictions"]["race"]) .. "]"
                info.notClickable = 1
            end

            UIDropDownMenu_AddButton(info, level)
        end

        function AddLetter(letter)
            if Emotive.emotesByLetter[letter] == nil then
                return
            end

            local info = UIDropDownMenu_CreateInfo()
            info.text, info.hasArrow, info.notCheckable, info.menuList = letter, true, 1, letter
            UIDropDownMenu_AddButton(info)
        end

        function AddLetters()
            local alphabet = L["Alphabet"]
            for i = 1, #alphabet do
                local letter = string.sub(alphabet, i, i)
                AddLetter(letter)
            end
        end

        function AddRecentEmotes(level)
            for i = 1, #Emotive.db.profile.recent do
                AddEmote(Emotive.db.profile.recent[i], level)
            end
        end

        function MenuInitialize(self, level, menuList)
            if (not level) then
                level = 1;
            end

            if (level == 1) then
                AddRecent()
                AddSeparator()
                AddLetters()
            elseif menuList then
                if (menuList == "RECENT") then
                    AddRecentEmotes(level)
                else
                    local letterEmotes = {}

                    for emote in pairs(Emotive.emotesByLetter[menuList]) do
                        table.insert(letterEmotes, emote)
                    end

                    table.sort(letterEmotes)

                    for _, emote in ipairs(letterEmotes) do
                        AddEmote(emote, level)
                    end
                end
            end
        end

        Emotive.menu = CreateFrame("FRAME", "EmotiveDropDown", UIParent, "UIDropDownMenuTemplate")
        Emotive.menu:SetPoint("CENTER")
        Emotive.menu:SetMovable(true)
        Emotive.menu:EnableMouse(true)
        Emotive.menu:SetClampedToScreen(true)
        Emotive.menu:RegisterForDrag("LeftButton")

        if (Emotive.db.profile.menu.point and Emotive.db.profile.menu.relativePoint and Emotive.db.profile.menu.x and Emotive.db.profile.menu.y) then
            Emotive.menu:ClearAllPoints()
            Emotive.menu:SetPoint(Emotive.db.profile.menu.point, nil, Emotive.db.profile.menu.relativePoint, Emotive.db.profile.menu.x, Emotive.db.profile.menu.y)
        end

        UIDropDownMenu_SetWidth(Emotive.menu, Emotive.db.profile.menu.width or 100)
        UIDropDownMenu_SetText(Emotive.menu, L["Emotive"])
        UIDropDownMenu_Initialize(Emotive.menu, MenuInitialize)

        Emotive.menu:SetScript("OnDragStart", Emotive.menu.StartMoving)
        Emotive.menu:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            Emotive.db.profile.menu.point, _, Emotive.db.profile.menu.relativePoint, Emotive.db.profile.menu.x, Emotive.db.profile.menu.y = self:GetPoint(1)
            Emotive.db.profile.menu.width = self:GetWidth()
        end)

        Emotive.db.profile.menu.hide = false
    end
end