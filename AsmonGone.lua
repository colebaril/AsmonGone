-- AsmonGone
-- Because some words are better left unread.

local ADDON_NAME = ...
local PREFIX = "|cffd95f5fAsmonGone|r"

local DEFAULT_KEYWORDS = {
    "asmon",
    "asmongold",
    "olympus",
    "olympuswow",
    "olympus wow",
}

-- Any guild whose normalized name begins with "olympus" is treated as blocked.
-- Examples: Olympus, Olympus I, Olympus X, Olympus XII, Olympus WoW.
local BLOCKED_GUILD_PREFIX = "olympus"

local FILTERED_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
}

-- Session-only caches. Guild membership can change, so these are intentionally
-- not SavedVariables.
local blockedPlayers = {}   -- [normalizedName] = true
local guildByPlayer = {}    -- [normalizedName] = guildName
local guildByGUID = {}      -- [guid] = guildName

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ": " .. tostring(message))
end

local function Normalize(text)
    if not text then return "" end
    text = tostring(text):lower()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function NormalizePlayerName(name)
    local n = Normalize(Trim(name))
    -- Keep realm-qualified names intact in the primary cache, but callers also
    -- check the short name so same-realm chat works consistently.
    return n
end

local function ShortPlayerName(name)
    return NormalizePlayerName(name):match("^([^%-]+)") or NormalizePlayerName(name)
end

local function IsBlockedGuild(guildName)
    local guild = Normalize(Trim(guildName))
    return guild ~= "" and guild:sub(1, #BLOCKED_GUILD_PREFIX) == BLOCKED_GUILD_PREFIX
end

local function RememberGuild(name, guid, guildName)
    if not guildName or guildName == "" then return false end

    local full = NormalizePlayerName(name)
    local short = ShortPlayerName(name)
    if full ~= "" then guildByPlayer[full] = guildName end
    if short ~= "" then guildByPlayer[short] = guildName end
    if guid and guid ~= "" then guildByGUID[guid] = guildName end

    if IsBlockedGuild(guildName) then
        if full ~= "" then blockedPlayers[full] = true end
        if short ~= "" then blockedPlayers[short] = true end
        return true
    end
    return false
end

local function EnsureDB()
    if type(AsmonGoneDB) ~= "table" then AsmonGoneDB = {} end
    if AsmonGoneDB.enabled == nil then AsmonGoneDB.enabled = true end
    if type(AsmonGoneDB.keywords) ~= "table" then
        AsmonGoneDB.keywords = {}
        for _, word in ipairs(DEFAULT_KEYWORDS) do
            AsmonGoneDB.keywords[#AsmonGoneDB.keywords + 1] = word
        end
    end
    if type(AsmonGoneDB.blocked) ~= "number" then AsmonGoneDB.blocked = 0 end
    if type(AsmonGoneDB.bubblesBlocked) ~= "number" then AsmonGoneDB.bubblesBlocked = 0 end
    if type(AsmonGoneDB.invitesBlocked) ~= "number" then AsmonGoneDB.invitesBlocked = 0 end
end

local function KeywordExists(keyword)
    local needle = Normalize(Trim(keyword))
    for i, word in ipairs(AsmonGoneDB.keywords) do
        if Normalize(word) == needle then return true, i end
    end
    return false, nil
end

local function MatchesBlockedKeyword(message)
    local normalized = Normalize(message)
    for _, keyword in ipairs(AsmonGoneDB.keywords) do
        local needle = Normalize(keyword)
        if needle ~= "" and normalized:find(needle, 1, true) then
            return true, keyword
        end
    end
    return false, nil
end

-- Attempts to learn guild membership from a visible/known unit token.
local function CacheUnitGuild(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    local name, realm = UnitName(unit)
    if not name then return false end
    local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
    local guildName = GetGuildInfo(unit)
    if guildName then
        return RememberGuild(fullName, UnitGUID(unit), guildName)
    end
    return false
end

local function FindAndCacheGUID(guid)
    if not guid or guid == "" then return false end
    if guildByGUID[guid] then return IsBlockedGuild(guildByGUID[guid]) end

    local commonUnits = { "target", "mouseover", "focus", "player" }
    for _, unit in ipairs(commonUnits) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return CacheUnitGuild(unit)
        end
    end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return CacheUnitGuild(unit)
        end
    end

    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return CacheUnitGuild(unit)
        end
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return CacheUnitGuild(unit)
        end
    end

    return false
end

-- Forever exposes modern tooltip APIs. When the player is known to the client,
-- a unit hyperlink can sometimes contain the guild even without a unit token.
-- This is best-effort and safely falls back if the client has no data.
local function TryCacheGuildFromGUID(name, guid)
    if not guid or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return false end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, "unit:" .. guid)
    if not ok or not data or type(data.lines) ~= "table" then return false end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" then
            local guild = text:match("^%s*<(.+)>%s*$")
            if guild then return RememberGuild(name, guid, guild) end
        end
    end
    return false
end

local function IsBlockedPlayer(name, guid)
    local full = NormalizePlayerName(name)
    local short = ShortPlayerName(name)
    if blockedPlayers[full] or blockedPlayers[short] then return true end

    local guild = (guid and guildByGUID[guid]) or guildByPlayer[full] or guildByPlayer[short]
    if guild then return IsBlockedGuild(guild) end

    if FindAndCacheGUID(guid) then return true end
    if TryCacheGuildFromGUID(name, guid) then return true end
    return false
end

-- Recursively finds visible text inside a Blizzard chat bubble.
local function CollectFrameText(frame, parts, depth)
    if not frame or depth > 5 then return end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text ~= "" then parts[#parts + 1] = text end
        end
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        CollectFrameText(child, parts, depth + 1)
    end
end

local function HideMatchingBubbles(message, forceMessageMatch)
    if not AsmonGoneDB or not AsmonGoneDB.enabled then return end
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end

    local wanted = Normalize(message)
    for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles() or {}) do
        if bubble and bubble.IsShown and bubble:IsShown() then
            local parts = {}
            CollectFrameText(bubble, parts, 0)
            local bubbleText = Normalize(table.concat(parts, " "))
            local keywordBlocked = MatchesBlockedKeyword(bubbleText)
            local sameMessage = forceMessageMatch and wanted ~= "" and bubbleText:find(wanted, 1, true)
            if keywordBlocked or sameMessage then
                bubble:Hide()
                AsmonGoneDB.bubblesBlocked = (AsmonGoneDB.bubblesBlocked or 0) + 1
            end
        end
    end
end

local function ScheduleBubbleSweep(message, forceMessageMatch)
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(0, function() HideMatchingBubbles(message, forceMessageMatch) end)
    C_Timer.After(0.08, function() HideMatchingBubbles(message, forceMessageMatch) end)
    C_Timer.After(0.20, function() HideMatchingBubbles(message, forceMessageMatch) end)
end

local function ChatFilter(self, event, message, author, ...)
    if not AsmonGoneDB or not AsmonGoneDB.enabled then return false end

    -- CHAT_MSG_* GUID is argument 12 overall, i.e. the 10th vararg here.
    local guid = select(10, ...)
    local keywordBlocked = MatchesBlockedKeyword(message)
    local guildBlocked = IsBlockedPlayer(author, guid)

    if keywordBlocked or guildBlocked then
        AsmonGoneDB.blocked = (AsmonGoneDB.blocked or 0) + 1
        -- For guild-blocked senders, hide their bubble by matching this exact
        -- message even if the text itself contains no blocked keyword.
        ScheduleBubbleSweep(message, guildBlocked)
        return true
    end

    -- Bubble filtering also runs for keyword matches independently of chat frame
    -- timing, because bubbles are separate UI objects.
    ScheduleBubbleSweep(message, false)
    return false
end

local function RejectGuildInvite(inviter, guildName)
    if not AsmonGoneDB or not AsmonGoneDB.enabled then return end
    if not IsBlockedGuild(guildName) then return end

    RememberGuild(inviter, nil, guildName)
    DeclineGuild()
    if StaticPopup_Hide then StaticPopup_Hide("GUILD_INVITE") end
    AsmonGoneDB.invitesBlocked = (AsmonGoneDB.invitesBlocked or 0) + 1
    Print("rejected guild invite from |cffffffff" .. tostring(inviter) .. "|r to <" .. tostring(guildName) .. ">.")
end

local function RejectPartyInviteIfBlocked(name, guid)
    if not AsmonGoneDB or not AsmonGoneDB.enabled then return end
    if not IsBlockedPlayer(name, guid) then return end

    DeclineGroup()
    -- Blizzard notes the popup can be created after this event handler. Hide now
    -- and again on the next frame to cover either ordering.
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
        end)
    end
    AsmonGoneDB.invitesBlocked = (AsmonGoneDB.invitesBlocked or 0) + 1
    Print("rejected group invite from known Olympus member |cffffffff" .. tostring(name) .. "|r.")
end

local function SortKeywords()
    table.sort(AsmonGoneDB.keywords, function(a, b) return Normalize(a) < Normalize(b) end)
end

local function ResetDefaults()
    AsmonGoneDB.keywords = {}
    for _, word in ipairs(DEFAULT_KEYWORDS) do
        AsmonGoneDB.keywords[#AsmonGoneDB.keywords + 1] = word
    end
    SortKeywords()
end

local function ShowHelp()
    Print("commands:")
    Print("  |cffffffff/ag add <word or phrase>|r - add a blocked term")
    Print("  |cffffffff/ag remove <word or phrase>|r - remove a blocked term")
    Print("  |cffffffff/ag list|r - list blocked terms")
    Print("  |cffffffff/ag on|r / |cffffffff/ag off|r - enable or disable filtering")
    Print("  |cffffffff/ag status|r - show current status")
    Print("  |cffffffff/ag stats|r - show hidden chat/bubble/invite counts")
    Print("  |cffffffff/ag test <message>|r - test a message against the blacklist")
    Print("  |cffffffff/ag defaults|r - restore the built-in blacklist")
    Print("  |cffffffff/ag clear|r - remove every blocked term")
end

local function SlashHandler(input)
    EnsureDB()
    local command, rest = (input or ""):match("^(%S*)%s*(.-)$")
    command = Normalize(command)
    rest = Trim(rest)

    if command == "" or command == "help" then
        ShowHelp()
    elseif command == "add" then
        if rest == "" then Print("Usage: /ag add <word or phrase>"); return end
        local exists = KeywordExists(rest)
        if exists then Print("Already blocked: |cffffffff" .. rest .. "|r"); return end
        AsmonGoneDB.keywords[#AsmonGoneDB.keywords + 1] = Normalize(rest)
        SortKeywords()
        Print("Banished from chat: |cffffffff" .. rest .. "|r")
    elseif command == "remove" or command == "delete" or command == "del" then
        if rest == "" then Print("Usage: /ag remove <word or phrase>"); return end
        local exists, index = KeywordExists(rest)
        if not exists then Print("Not currently blocked: |cffffffff" .. rest .. "|r"); return end
        local removed = table.remove(AsmonGoneDB.keywords, index)
        Print("Paroled: |cffffffff" .. removed .. "|r")
    elseif command == "list" then
        if #AsmonGoneDB.keywords == 0 then Print("The blacklist is empty. The gates are unguarded."); return end
        SortKeywords()
        Print("blacklist (" .. #AsmonGoneDB.keywords .. "):")
        for i, keyword in ipairs(AsmonGoneDB.keywords) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffaaaaaa%02d.|r |cffffffff%s|r", i, keyword))
        end
    elseif command == "on" or command == "enable" then
        AsmonGoneDB.enabled = true
        Print("enabled. Peace has been restored to Azeroth.")
    elseif command == "off" or command == "disable" then
        AsmonGoneDB.enabled = false
        Print("disabled. You have chosen chaos.")
    elseif command == "status" then
        local state = AsmonGoneDB.enabled and "|cff55ff55ON|r" or "|cffff5555OFF|r"
        Print(state .. " - " .. #AsmonGoneDB.keywords .. " blocked terms; Olympus guild filtering active.")
    elseif command == "stats" then
        Print(string.format("%d chat message%s, %d bubble%s, and %d invite%s sent to the Shadow Realm.",
            AsmonGoneDB.blocked or 0, (AsmonGoneDB.blocked or 0) == 1 and "" or "s",
            AsmonGoneDB.bubblesBlocked or 0, (AsmonGoneDB.bubblesBlocked or 0) == 1 and "" or "s",
            AsmonGoneDB.invitesBlocked or 0, (AsmonGoneDB.invitesBlocked or 0) == 1 and "" or "s"))
    elseif command == "test" then
        if rest == "" then Print("Usage: /ag test <message>"); return end
        local blocked, keyword = MatchesBlockedKeyword(rest)
        if blocked then Print("BLOCKED by |cffffffff" .. keyword .. "|r: " .. rest)
        else Print("ALLOWED: " .. rest) end
    elseif command == "defaults" or command == "reset" then
        ResetDefaults()
        Print("Default anti-Asmon blacklist restored.")
    elseif command == "clear" then
        AsmonGoneDB.keywords = {}
        Print("Blacklist cleared. /ag defaults will restore the built-ins.")
    else
        Print("Unknown command: |cffffffff" .. command .. "|r. Type |cffffffff/ag help|r.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GUILD_INVITE_REQUEST")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= ADDON_NAME then return end

        EnsureDB()
        SortKeywords()
        for _, chatEvent in ipairs(FILTERED_EVENTS) do
            ChatFrame_AddMessageEventFilter(chatEvent, ChatFilter)
        end
        SLASH_ASMONGONE1 = "/asmongone"
        SLASH_ASMONGONE2 = "/ag"
        SlashCmdList["ASMONGONE"] = SlashHandler
        Print("loaded. |cffffffff/ag help|r for commands. The timeline is healing.")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "GUILD_INVITE_REQUEST" then
        local inviter, guildName = ...
        RejectGuildInvite(inviter, guildName)

    elseif event == "PARTY_INVITE_REQUEST" then
        local name, _, _, _, _, _, inviterGUID = ...
        RejectPartyInviteIfBlocked(name, inviterGUID)

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CacheUnitGuild(...)

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CacheUnitGuild("mouseover")

    elseif event == "PLAYER_TARGET_CHANGED" then
        CacheUnitGuild("target")

    elseif event == "GROUP_ROSTER_UPDATE" then
        for i = 1, 4 do CacheUnitGuild("party" .. i) end
        for i = 1, 40 do CacheUnitGuild("raid" .. i) end
    end
end)
