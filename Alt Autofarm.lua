local HttpService = game:GetService("HttpService")
local runningID = HttpService:GenerateGUID()
_G.running = runningID

local import = getrenv().shared.import
getfenv(import).getfenv = function() return { script = game.Players.LocalPlayer.PlayerScripts.Client } end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local raceColliders = workspace["$raceColliders"]
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Races = PlayerGui.Races
local Keyboard = require(game.ReplicatedStorage.src.pcar.CarInput.Keyboard)
local CarPlacer = require(game.ReplicatedStorage.src.pcar.CarPlacer)
local CarTracker = require(game.ReplicatedStorage.src.pcar.CarTracker)
local ClientCarState = require(game.ReplicatedStorage.src.pcar.ClientCarState)
local ClientRaceState = require(game.ReplicatedStorage.src.prace["ClientRaceState.client"])
local databus = getrawmetatable(require(game.ReplicatedStorage.src.pcar["ClientCarDataBus.client"]))
local interactionClient = import('/game/Interaction.client')

local checkpointModel = game.Workspace["%Placeables"]
local myCar
local mainRaceFolder = game.ReplicatedStorage.assets.races["Downtown Race"]
local mainRaceCircle = mainRaceFolder.StartArea

local isRacingVal
local isDrivingVal

local trackValues = {}

local interactionList = getupvalue(interactionClient.new, 2)

local driveInteraction do
	for _, interaction in next, interactionList do
		if (type(interaction) == 'table' and rawget(interaction, '_name') == 'Drive') then
			driveInteraction = interaction; 
			break
		end
	end
end

local function executeInAlternateContext(fn, ...)
	syn.set_thread_identity(2)
	local results = { pcall(fn, ...) }
	syn.set_thread_identity(6)

	assert(results[1], results[2])
	return unpack(results, 2)
end

local function getCurrentSpawnedCar()
	for _, car in next, workspace['$cars']:GetChildren() do
		local state = car:FindFirstChild('State')
		local owner = state and state:FindFirstChild('Owner')

		if owner and owner.Value == game.Players.LocalPlayer then
			return car
		end
	end
end

for _, tb in next, getgc(true) do
    if type(tb) == 'table' and type(rawget(tb, '_kill')) == 'function' then
        tb._kill = function() end
    end
end

local ResetVelocityOfLocalPlayersCar = function(...)
	local LocalPlayersCar = myCar
	local Descendants = LocalPlayersCar:GetDescendants()
	table.foreachi(Descendants, function(_, Value, ...)
		if Value:IsA("BasePart") then
			Value.AssemblyLinearVelocity = Vector3.new()
			Value.AssemblyAngularVelocity = Vector3.new()
			return
		else
			return
		end
	end)
	return
end

function teleportCar(vector, offset)
    if not offset then
       offset = Vector3.new() 
    end
    CarPlacer.place(nil, myCar, CFrame.new(vector + offset))
end

function getFastestCar()
    local datatable = databus.__index.getOwnedCarIds()
    local fastestCar = {topSpeed = 0, car = nil}

    for i,v in pairs(datatable) do
        if game.ReplicatedStorage.cars[v] then
            local currentCarMaxSpeed = require(game.ReplicatedStorage.cars[v].Module).MaxSpeed
            if currentCarMaxSpeed > fastestCar.topSpeed then
                fastestCar.topSpeed = 225--currentCarMaxSpeed
                fastestCar.car = v
            end
        end
    end
    return fastestCar
end

function spawnCar()
    local waitfor = game.ReplicatedStorage.remotes.cms.SpawnCarRequest:InvokeServer(getFastestCar().car)
    local spawnedcar do
        while spawnedcar == nil do
            local doihavethecar = getCurrentSpawnedCar()
            if doihavethecar ~= nil then
                spawnedcar = doihavethecar
            end
            task.wait(0.3)
        end
    end
    task.wait(0.1)
    executeInAlternateContext(driveInteraction._callback, driveInteraction, spawnedcar.Body.DriverDummy.SeatAttachment)
    task.wait(1)
    myCar = CarTracker.getCarFromDriver(game.Players.LocalPlayer)
end

local bindablefunc = Instance.new("BindableFunction")

bindablefunc.OnInvoke = function(valueName, val) --Very cool custom :WaitFor
    if valueName == "isDriving" then
        if (myCar.PrimaryPart.Position - mainRaceCircle.Position).magnitude > mainRaceCircle.Size.X/2-6 or (myCar.PrimaryPart.Position.Y - (mainRaceCircle.Position.Y - mainRaceCircle.Size.Y)) < 0 then
            teleportCar(mainRaceCircle.Position)
        end
    elseif valueName == "isRacing" and val == true then
        local HudContainer = game.Players.LocalPlayer.PlayerGui.Races:WaitForChild("HudContainer", 10)
        if HudContainer then
            task.wait(0.5)
            getrenv().shared.remote("/races/Forfeit"):FireServer()
        end
    end
end

function checkValue(valuename, value)
    local valName = tostring(valuename)
    local oldValue = trackValues[valuename]
    if oldValue ~= value then
        bindablefunc:Invoke(valName, value)
    end
    trackValues[valuename] = value
    return value
end

function removeCollision(obj)
    if _G.running == runningID then
        if obj.State.Owner.Value ~= game.Players.LocalPlayer then
            for i,v in pairs(obj:GetDescendants()) do
                pcall(function()
                    v.CanCollide = false
                end)
            end 
        end
    end
end

for i,v in pairs(game.Workspace["$cars"]:GetChildren()) do
    removeCollision(v)
end

game.Workspace["$cars"].ChildAdded:connect(function(obj)
   removeCollision(obj) 
end)

task.spawn(function()
    while _G.running == runningID do
        if not ClientCarState.isDriving then
            spawnCar()
        else
            myCar = CarTracker.getCarFromDriver(game.Players.LocalPlayer)
        end
        isDrivingVal = checkValue("isDriving", ClientCarState.isDriving)
        isRacingVal = checkValue("isRacing", ClientRaceState.racing)
        if isDrivingVal then
            if not isRacingVal and ((myCar.PrimaryPart.Position - mainRaceCircle.Position).magnitude > mainRaceCircle.Size.X/2-6 or myCar.PrimaryPart.Position.Y - (mainRaceCircle.Position.Y - mainRaceCircle.Size.Y/2) < 0.4 or (myCar.PrimaryPart.Position.Y - (mainRaceCircle.Position.Y + mainRaceCircle.Size.Y/2)) > 0) then
                teleportCar(mainRaceCircle.Position, Vector3.new(0,-3,0))
            elseif not isRacingVal then
                for i,v in pairs(game.Workspace["$cars"]:GetChildren()) do
                    removeCollision(v)
                end
            end
        end
        task.wait()
    end
end)

for i,v in pairs(getconnections(game.Players.LocalPlayer.Idled)) do --anti afk
    pcall(function()
        if v["Disable"] then
            v["Disable"](v)
        elseif v["Disconnect"] then
            v["Disconnect"](v)
        end
    end)
end

game:GetService("RunService"):Set3dRenderingEnabled(false)
setfpscap(10)
