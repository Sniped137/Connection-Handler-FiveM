local bannedAccounts = {}
local nonBannedAccounts = {}
local tokenBanEvadingDetected = false
local accountBanEvadingDetected = false
local multipleAccountsDetected = false
local apiMinuteCooldown = false
local contactEmail = ""
local flags = "m"
local ban_logs_webhook = ""
local connection_logs_webhook = ""
local database_logs_webhook= ""
local discord_image = "" -- default is FiveM logo


local function banAccountUsingId(id, banReason, bannedby, banLength)
    MySQL.update.await('UPDATE user_identifiers SET isBanned = ?, banReason = ?, bannedBy = ?, banExpires = ?, timeModified = ? WHERE id = ?', 
    {1, banReason, bannedby, banLength, os.date("%Y-%m-%d %H:%M:%S", os.time()), id})
end

local function banAccountUsingSteamId(steamid, banReason, bannedby, banLength)
    MySQL.update.await('UPDATE user_identifiers SET isBanned = ?, banReason = ?, bannedBy = ?, banExpires = ?, timeModified = ? WHERE steam_id = ?', 
    {1, banReason, bannedby, banLength, os.date("%Y-%m-%d %H:%M:%S", os.time()), steamid})
end

local function unbanAccountUsingId(id)
    MySQL.update.await('UPDATE user_identifiers SET isBanned = ?, banReason = ?, bannedBy = ?, banExpires = ?, timeModified = ? WHERE id = ?', 
    {0, '', '', 0, os.date("%Y-%m-%d %H:%M:%S", os.time()), id})
end

local function doesAccountExistInDatabase(steamid)
    local result = MySQL.single.await('SELECT * FROM `user_identifiers` WHERE `steam_id` = ? LIMIT 1', {steamid})
    if result then 
        return result 
    else 
        return '' 
    end
end

local function checkForChangedTokens(steamid, playerTokens)
    local result = MySQL.single.await('SELECT tokens FROM `user_identifiers` WHERE `steam_id` = ? LIMIT 1', {steamid})
    local tokensFromDb = json.decode(result.tokens)
    local nonMatchingTokens = {}
    for i, dbToken in pairs(tokensFromDb) do 
        local foundMatch = false
        for j, playerToken in pairs(playerTokens) do 
            if dbToken == playerToken then
                foundMatch = true
                break
            end
        end 
        if not foundMatch then
            sendToDiscord("\n**Steam ID: ** "..steamid.." - has 1 or more new HWID tokens (new hardware added to accounts computer)", database_logs_webhook)
            table.insert(nonMatchingTokens, playerToken)
        end
    end
    if #nonMatchingTokens > 0 then 
        local combinedTokens = {}
        for k, dbToken in ipairs(tokensFromDb) do
            table.insert(combinedTokens, dbToken)
        end
        for l, nonMatchingToken in ipairs(nonMatchingTokens) do
            table.insert(combinedTokens, nonMatchingToken)
        end
        MySQL.update.await('UPDATE user_identifiers SET tokens = ? WHERE steam_id = ?', 
        {json.encode(combinedTokens), steamid})
    end
end

local function reloadBanTable()
    bannedAccounts = {}
    MySQL.query('SELECT * FROM `user_identifiers`', {}, function(accounts)
        if accounts then
            for i, account in pairs(accounts) do
                if account.isBanned then 
                    if tonumber(account.banExpires) < os.time() then 
                        unbanAccountUsingId(account.id)
                    else
                        table.insert(bannedAccounts, {
                        id = account.id,
                        steam_id = account.steam_id,
                        ip = account.ip,
                        license = account.license, 
                        discord = account.discord,
                        xbl = account.xbl,
                        liveid = account.liveid,
                        tokens = account.tokens,
                        lastKnownName = account.lastKnownName,
                        isBanned = account.isBanned,
                        banReason = account.banReason,
                        bannedBy = account.bannedBy,
                        banExpires = account.banExpires,
                        timeModified = account.timeModified,
                        timeCreated = account.timeCreated
                        })
                    end
                end
            end
        end
    end)
end

local function reloadNonBannedAccountsTable()
    nonBannedAccounts = {}
    MySQL.query('SELECT * FROM `user_identifiers`', {}, function(accounts)
        if accounts then
            for i, account in pairs(accounts) do
                if not account.isBanned then 
                        table.insert(nonBannedAccounts, {
                        id = account.id,
                        steam_id = account.steam_id,
                        ip = account.ip,
                        license = account.license, 
                        discord = account.discord,
                        xbl = account.xbl,
                        liveid = account.liveid,
                        tokens = account.tokens,
                        lastKnownName = account.lastKnownName,
                        isBanned = account.isBanned,
                        banReason = account.banReason,
                        bannedBy = account.bannedBy,
                        banExpires = account.banExpires,
                        timeModified = account.timeModified,
                        timeCreated = account.timeCreated
                    })
                end
            end
        end
    end)
end


local function addAccountToDatabase(steamid, ip, license, discord, xbl, liveid, playerTokens, playerName)
    MySQL.insert.await('INSERT INTO `user_identifiers` (steam_id, ip, license, discord, xbl, liveid, tokens, lastKnownName) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', 
    {steamid, ip, license, discord, xbl, liveid, json.encode(playerTokens), playerName})
    
    local row = MySQL.single.await('SELECT * FROM `user_identifiers` WHERE `steam_id` = ? LIMIT 1', {steamid})
    if row then 
        return row
    end
end

local function checkforMatchingIdentifiers(newAccountRow, steamid, ip, license, xbl, discord, liveid)
    for i, bannedAccount in pairs(bannedAccounts) do
        local attributes = {
        {name = "SteamID", value = steamid, accountValue = bannedAccount.steam_id},
        {name = "IP", value = ip, accountValue = bannedAccount.ip},
        {name = "License", value = license, accountValue = bannedAccount.license},
        {name = "Xbox Live", value = xbl, accountValue = bannedAccount.xbl},
        {name = "Discord", value = discord, accountValue = bannedAccount.discord},
        {name = "Live ID", value = liveid, accountValue = bannedAccount.liveid}}

        for _, attr in ipairs(attributes) do
            if attr.value == attr.accountValue then
                if newAccountRow.id ~= bannedAccount.id then
                    local year, month, day, hour, minute, second = 2400, 1, 1, 00, 00, 0
                    local permaBanLength = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
                    sendToDiscord("**SYSTEM** banned **"..newAccountRow.lastKnownName.." **("..newAccountRow.steam_id..") **Reason:** Detected Matching Identifier - Ban Evading, **Ban Expires:** "..os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                    sendToDiscord("**SYSTEM** banned **"..bannedAccount.lastKnownName.." **("..bannedAccount.steam_id..") **Reason:** Detected Matching Identifier - Ban Evading, **Ban Expires:** ".. os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                    banAccountUsingId(tonumber(newAccountRow.id), "Detected Matching Identifier - Ban Evading", "SYSTEM", permaBanLength)
                    banAccountUsingId(tonumber(bannedAccount.id), "Detected Matching Identifier - Ban Evading", "SYSTEM", permaBanLength)
                    accountBanEvadingDetected = true
                    return
                end
            end
        end   
    end
end

local function checkForMultipleAccounts(newAccountRow, playerTokens)
    for i, account in pairs(nonBannedAccounts) do
        local attributes = {
            {name = "SteamID", value = steamid, accountValue = account.steam_id},
            {name = "IP", value = ip, accountValue = account.ip},
            {name = "License", value = license, accountValue = account.license},
            {name = "Xbox Live", value = xbl, accountValue = account.xbl},
            {name = "Discord", value = discord, accountValue = account.discord},
            {name = "Live ID", value = liveid, accountValue = account.liveid}
        }

        for _, attr in ipairs(attributes) do
            if attr.value == attr.accountValue then
                if newAccountRow.id ~= account.id then
                    local year, month, day, hour, minute, second = 2400, 1, 1, 00, 00, 0
                    local permaBanLength = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
                    sendToDiscord("**SYSTEM** banned **"..newAccountRow.lastKnownName.." **("..newAccountRow.steam_id..") **Reason:** Detected Multiple Accounts - Matching Identifiers, **Ban Expires:** "..os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                    sendToDiscord("**SYSTEM** banned **"..account.lastKnownName.." **("..account.steam_id..") **Reason:** Detected Multiple Accounts - Matching Identifiers, **Ban Expires:** ".. os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                    banAccountUsingId(tonumber(newAccountRow.id), "Detected Multiple Accounts - Matching Identifiers", "SYSTEM", permaBanLength)
                    banAccountUsingId(tonumber(account.id), "Detected Multiple Accounts - Matching Identifiers", "SYSTEM", permaBanLength)
                    multipleAccountsDetected = true
                    return
                end
            end
        end
    end
    for i, account in pairs(nonBannedAccounts) do
        local accountTokens = json.decode(account.tokens)
        for j, token in pairs(accountTokens) do 
            for k, playerToken in pairs(playerTokens) do 
                if playerToken == token then 
                    if newAccountRow.id ~= account.id then
                        local year, month, day, hour, minute, second = 2400, 1, 1, 00, 00, 0
                        local permaBanLength = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
                        sendToDiscord("**SYSTEM** banned **"..newAccountRow.lastKnownName.." **("..newAccountRow.steam_id..") **Reason:** Detected Multiple Accounts - Matching Tokens, **Ban Expires:** "..os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                        sendToDiscord("**SYSTEM** banned **"..account.lastKnownName.." **("..account.steam_id..") **Reason:** Detected Multiple Accounts - Matching Tokens, **Ban Expires:** ".. os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                        banAccountUsingId(tonumber(newAccountRow.id), "Detected Multiple Accounts - Matching Tokens", "SYSTEM", permaBanLength)
                        banAccountUsingId(tonumber(account.id), "Detected Multiple Accounts - Matching Tokens", "SYSTEM", permaBanLength)
                        multipleAccountsDetected = true
                        return
                    end
                end 
            end 
        end
    end
end

local function checkForMatchingTokens(newAccountRow, playerTokens)
    for i, bannedAccount in pairs(bannedAccounts) do 
        local accountTokens = json.decode(bannedAccount.tokens)
        for j, token in pairs(accountTokens) do 
            for k, playerToken in pairs(playerTokens) do 
                if playerToken == token then 
                    if steamid ~= bannedAccount.steam_id then
                        local year, month, day, hour, minute, second = 2400, 1, 1, 00, 00, 0
                        local permaBanLength = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
                        sendToDiscord("**SYSTEM** banned **"..newAccountRow.lastKnownName.." **("..newAccountRow.steam_id..") **Reason:** Detected Matching Token - Ban Evading, **Ban Expires:** "..os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                        sendToDiscord("**SYSTEM** banned **"..bannedAccount.lastKnownName.." **("..bannedAccount.steam_id..") **Reason:** Detected Matching Token - Ban Evading, **Ban Expires:** ".. os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                        banAccountUsingId(tonumber(newAccountRow.id), "Detected Matching Token - Ban Evading", "SYSTEM", permaBanLength)
                        banAccountUsingId(tonumber(bannedAccount.id), "Detected Matching Token - Ban Evading", "SYSTEM", permaBanLength)
                        tokenBanEvadingDetected = true
                        return 
                    end
                end 
            end 
        end
    end
end

local function checkForProxy(ip, steamid, playerName)
    local formattedIP = ip:gsub("ip:", "")
    PerformHttpRequest("http://check.getipintel.net/check.php?ip=" .. formattedIP .. "&contact=" .. contactEmail .. "&flags=" .. flags, function(statusCode, response, headers)
        if response then
            probability = tonumber(response)
            if probability > 0.99 then
                local year, month, day, hour, minute, second = 2400, 1, 1, 00, 00, 0
                local permaBanLength = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=second})
                sendToDiscord("**SYSTEM** banned **"..playerName.." **("..steamid..") **Reason:** Proxy/VPN Connection Detected, **Ban Expires:** "..os.date("%d/%m/%Y %H:%M:%S", permaBanLength).." (DD/MM/YYYY)", ban_logs_webhook)
                banAccountUsingSteamId(steamid, "Proxy/VPN Connection Detected", "SYSTEM", permaBanLength)
                apiMinuteCooldown = false
                return
            end 
        else 
            apiMinuteCooldown = true
        end
    end)
end

function sendToDiscord(message, channelWebhook)
    PerformHttpRequest(channelWebhook, function(err, text, headers) end, 'POST', json.encode({content = message, avatar_url = discord_image}), { ['Content-Type'] = 'application/json' })
end

MySQL.ready(function()
    reloadNonBannedAccountsTable()
    Wait(100)
    print("Loaded \27[94mNon Banned\27[0m Accounts Table") -- \27[94m sets the color to light blue, \27[0m resets the color
    reloadBanTable()
    Wait(100)
    print("Loaded \27[91mBanned\27[0m Accounts Table") -- \27[91m sets the color to light red, \27[0m resets the color
end)


AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local source = source
    local numTokens = GetNumPlayerTokens(source)
    local playerTokens = {}
    local steamid = ""
    local license = ""
    local discord = ""
    local xbl = ""
    local liveid = ""
    local ip = ""
    local newAccountRow = 0
    tokenBanEvadingDetected = false
    accountBanEvadingDetected = false
    multipleAccountsDetected = false
    apiMinuteCooldown = false
    
    deferrals.defer()

    Wait(0)

    deferrals.update(string.format("Checking account details..."))

    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(source, i) 
        table.insert(playerTokens, token)
    end

    Wait(5)


    for k,v in pairs(GetPlayerIdentifiers(source))do
        if string.sub(v, 1, string.len("steam:")) == "steam:" then
            steamid = v
        elseif string.sub(v, 1, string.len("license:")) == "license:" then
            license = v
        elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
            xbl  = v
        elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
            ip = v
        elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
            discord = v
        elseif string.sub(v, 1, string.len("live:")) == "live:" then
            liveid = v
        end
    end

    if steamid == nil or steamid == "" or steamid == "NONE" or not steamid then
        sendToDiscord("**"..playerName.."** failed to connect. **Reason:** Steam is not running, Open Steam first, then Restart FiveM", connection_logs_webhook)
        deferrals.done("\n\nYou are not allowed to join Grand Theft Roleplay\n\nReason: Steam is not running, Open Steam first, then restart FiveM")
        return 
    end
    if numTokens < 0 or numTokens == 0 or numTokens == "**Invalid**" or numTokens == nil or numTokens == "null" or numTokens == "NONE" or not numTokens then 
        sendToDiscord("**"..playerName.."** **Steam ID:** ("..steamid..") failed to connect. **Reason:** Unable to fetch account tokens. Restart FiveM and Try Again", connection_logs_webhook)
        deferrals.done("\n\nYou are not allowed to join Grand Theft Roleplay\n\nReason: Unable to fetch account tokens. Restart FiveM and Try Again")
        return
    end

    Wait(5)

    local accountData = doesAccountExistInDatabase(steamid) 
    
    if accountData.steam_id ~= steamid then
        newAccountRow = addAccountToDatabase(steamid, ip, license, discord, xbl, liveid, playerTokens, playerName)
        if #nonBannedAccounts > 0 or #bannedAccounts > 0 then
            checkforMatchingIdentifiers(newAccountRow, steamid, ip, license, xbl, discord, liveid)
            if not accountBanEvadingDetected then 
                checkForMultipleAccounts(newAccountRow, playerTokens)
            end 
            if not accountBanEvadingDetected and multipleAccountsDetected then 
                checkForMatchingTokens(newAccountRow, playerTokens)
            end   
        end
    else 
        checkForChangedTokens(steamid, playerTokens)
    end

    Wait(500)

    if not tokenBanEvadingDetected and not accountBanEvadingDetected and not multipleAccountsDetected then
        checkForProxy(ip, steamid, playerName)
        if apiMinuteCooldown then 
            deferrals.done("Proxy/VPN API is on Cooldown. Please wait a minute, and then try again.")
        end
    end

    Wait(600)

    reloadBanTable()

    Wait(600)

    for i, bannedAccount in pairs(bannedAccounts) do
        if steamid == bannedAccount.steam_id then 
            sendToDiscord("** **\n**Steam Name:** "..playerName.." **\nSteam ID:** "..steamid.." - failed to connect. **\nReason:** Attempted to join while banned. **\nBan Reason:** "..bannedAccount.banReason.." **\nBanned By:** "..bannedAccount.bannedBy.."**\nBan Expires:** " .. os.date("%d/%m/%Y %H:%M:%S", bannedAccount.banExpires), connection_logs_webhook)
            deferrals.done("\n\nYou are not allowed to join Grand Theft Roleplay\n\nReason: " .. bannedAccount.banReason .. "\n Banned By: "..bannedAccount.bannedBy.."\nBan Expires: " .. os.date("%d/%m/%Y %H:%M:%S", bannedAccount.banExpires) .. "\n\nAppeal on Discord: https://discord.gg/ert98f4Bb2")
            break
        end
        if newAccountRow ~= 0 then 
            if newAccountRow.steam_id == bannedAccount.steam_id then 
                sendToDiscord("** **\n**Steam Name:** "..playerName.." **\nSteam ID:** "..steamid.." - failed to connect. **\nReason:** Attempted to join while banned. **\nBan Reason:** "..bannedAccount.banReason.." **\nBanned By:** "..bannedAccount.bannedBy.."**\nBan Expires:** " .. os.date("%d/%m/%Y %H:%M:%S", bannedAccount.banExpires), connection_logs_webhook)
                deferrals.done("\n\nYou are not allowed to join Grand Theft Roleplay\n\nReason: " .. bannedAccount.banReason .. "\n Banned By: "..bannedAccount.bannedBy.."\nBan Expires: " .. os.date("%d/%m/%Y %H:%M:%S", bannedAccount.banExpires) .. "\n\nAppeal on Discord: https://discord.gg/ert98f4Bb2")
                break
            end 
        end
    end
    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local player = source
    local steamid = GetPlayerIdentifierByType(player, 'steam')
    local playerName = GetPlayerName(player)
    sendToDiscord("\n**Server ID: **"..player.." - has connected to the server**\nSteam Name:** "..playerName.."**\nSteam ID: **("..steamid..")", connection_logs_webhook)
end)

AddEventHandler('playerDropped', function (reason)
    local player = source
    local steamid = GetPlayerIdentifierByType(player, 'steam')
    local playerName = GetPlayerName(player)
    sendToDiscord("\n**Server ID: **"..player.." - has disconnected from the server **\nSteam Name:** "..playerName.."**\nSteam ID: **("..steamid..") \n**Reason:** "..reason, connection_logs_webhook)
end)

  