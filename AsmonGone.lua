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

-- Public/community-style chat only by default. Private/group chat is deliberately
-- left alone so messages from friends, guildmates, party members, etc. still appear.
local FILTERED_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ": " .. tostring(message))
end

local function Normalize(text)
    if not text then return "" end
    text = tostring(text):lower()
    -- Strip WoW colour/link formatting enough that keywords embedded in links or
    -- coloured spam cannot trivially bypass the filter.
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function EnsureDB()
    if type(AsmonGoneDB) ~= "table" then
        AsmonGoneDB = {}
    end
    if AsmonGoneDB.enabled == nil then
        AsmonGoneDB.enabled = true
    end
    if type(AsmonGoneDB.keywords) ~= "table" then
        AsmonGoneDB.keywords = {}
        for _, word in ipairs(DEFAULT_KEYWORDS) do
            AsmonGoneDB.keywords[#AsmonGoneDB.keywords + 1] = word
        end
    end
    if type(AsmonGoneDB.blocked) ~= "number" then
        AsmonGoneDB.blocked = 0
    end
end

local function KeywordExists(keyword)
    local needle = Normalize(Trim(keyword))
    for i, word in ipairs(AsmonGoneDB.keywords) do
        if Normalize(word) == needle then
            return true, i
        end
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

local function ChatFilter(self, event, message, author, ...)
    if not AsmonGoneDB or not AsmonGoneDB.enabled then
        return false
    end

    local blocked = MatchesBlockedKeyword(message)
    if blocked then
        AsmonGoneDB.blocked = (AsmonGoneDB.blocked or 0) + 1
        return true
    end

    return false
end

local function SortKeywords()
    table.sort(AsmonGoneDB.keywords, function(a, b)
        return Normalize(a) < Normalize(b)
    end)
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
    Print("  |cffffffff/ag stats|r - show how many messages have vanished")
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
        if rest == "" then
            Print("Usage: /ag add <word or phrase>")
            return
        end
        local exists = KeywordExists(rest)
        if exists then
            Print("Already blocked: |cffffffff" .. rest .. "|r")
            return
        end
        AsmonGoneDB.keywords[#AsmonGoneDB.keywords + 1] = Normalize(rest)
        SortKeywords()
        Print("Banished from chat: |cffffffff" .. rest .. "|r")

    elseif command == "remove" or command == "delete" or command == "del" then
        if rest == "" then
            Print("Usage: /ag remove <word or phrase>")
            return
        end
        local exists, index = KeywordExists(rest)
        if not exists then
            Print("Not currently blocked: |cffffffff" .. rest .. "|r")
            return
        end
        local removed = table.remove(AsmonGoneDB.keywords, index)
        Print("Paroled: |cffffffff" .. removed .. "|r")

    elseif command == "list" then
        if #AsmonGoneDB.keywords == 0 then
            Print("The blacklist is empty. The gates are unguarded.")
            return
        end
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
        Print(state .. " - " .. #AsmonGoneDB.keywords .. " blocked terms; " .. (AsmonGoneDB.blocked or 0) .. " messages hidden.")

    elseif command == "stats" then
        Print(string.format("%d unwanted message%s sent to the Shadow Realm.", AsmonGoneDB.blocked or 0, (AsmonGoneDB.blocked or 0) == 1 and "" or "s"))

    elseif command == "test" then
        if rest == "" then
            Print("Usage: /ag test <message>")
            return
        end
        local blocked, keyword = MatchesBlockedKeyword(rest)
        if blocked then
            Print("BLOCKED by |cffffffff" .. keyword .. "|r: " .. rest)
        else
            Print("ALLOWED: " .. rest)
        end

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
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event ~= "ADDON_LOADED" or loadedAddon ~= ADDON_NAME then
        return
    end

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
end)
