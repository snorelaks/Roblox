local RAMAccount = loadstring(readfile("lax_logs/RAMAccountNew.lua"))()
local accounts = string.split(RAMAccount.new(""):GetAccounts(), ",")

function joinGame(account, placeid, jobid)
    if jobid and jobid:sub(1,5) == "https" then
        account:LaunchAccount(game.PlaceId, jobid, false, true)
    elseif jobid then
        account:LaunchAccount(game.PlaceId, jobid, false, false)
    else
        account:LaunchAccount(game.PlaceId)
    end
end

local accountsLaunched = 0
for i,v in pairs(accounts) do
    if v ~= game.Players.LocalPlayer.Name then
        local currentAccount = RAMAccount.new(v)
        local fieldForGame = currentAccount:GetField(game.PlaceId)
        if fieldForGame ~= "" then
            accountsLaunched = accountsLaunched + 1
            if fieldForGame:sub(1,5) == "https" then
                joinGame(currentAccount, game.PlaceId, fieldForGame)
            else
                joinGame(currentAccount, game.PlaceId)
            end
            task.wait(5+(accountsLaunched/2))
        end
    end
end