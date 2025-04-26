--// Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = { Client = {} }

--// Dependencies
local Cardinal = require(ReplicatedStorage.Packages.Cardinal)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileServiceModule = require(ServerStorage.Packages.ProfileService)

--// Constants
local ProfileTemplate = {
	CmdrGroup = 0,
	InGamePurchases = {},

	BaseData = {

	},

	Inventory = {
		Units = {
			Equipped = {},
			Stored = {},
		},
		
	}
}

local ProfileStore = ProfileServiceModule.GetProfileStore("PlayerData.DEV1", ProfileTemplate)

--// Variables
local profiles = {}

--// Knit Events
ProfileService.Client.OnProfileUpdate = Cardinal.CreateSignal()
ProfileService.OnProfileUpdate = Signal.new()

--// Functions
local function valueByPath(action, dataTable, path, newValue)
	local pathComponents = path:split(".")

	-- Navigate through the table using the path components
	local currentTable = dataTable
	for i = 1, #pathComponents do
		local component = pathComponents[i]
		if i == #pathComponents then
			-- If this is the last component in the path, take action on the value
			if action == "GET" then
				return currentTable[component]
			elseif action == "SET" then
				currentTable[component] = newValue
			end
		else
			-- Otherwise, move to the next nested table
			currentTable = currentTable[component]
		end
	end
end

local function processGlobalUpdate(player, payload)
	local itemsSortedByPath = {}
	for _, item in payload do
		if itemsSortedByPath[item.Path] == nil then
			itemsSortedByPath[item.Path] = {}
		end
		table.insert(itemsSortedByPath[item.Path], item)
	end

	for path, items in itemsSortedByPath do
		local newPath = path:split(".")
		table.remove(newPath, 1)
		newPath = table.concat(newPath, ".")

		ProfileService:Update(player, path:split(".")[1], function(data)
			for _, item in items do
				local newValue
				if #newPath == 0 then
					newValue = data
				else
					newValue = valueByPath("GET", data, newPath)
				end

				if item.Type == "Increment" then
					newValue += item.Value
				elseif item.Type == "Insert" then
					table.insert(newValue, item.Value)
				elseif item.Type == "Set" then
					newValue = item.Value
				end

				if #newPath == 0 then
					data = newValue
				else
					valueByPath("SET", data, newPath, newValue)
				end
			end
			return data
		end)
	end
end

local function registerPlayer(player)
	local profile = ProfileStore.Mock:LoadProfileAsync(tostring(player.UserId), "ForceLoad")

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			profiles[player] = nil
			player:Kick(
				"\nYour player data might've been loaded on another Roblox server.\nNo data was corrupted during this process, you may rejoin."
			)
		end)
		if player:IsDescendantOf(Players) == true then
			profiles[player] = profile

			for _, update in profile.GlobalUpdates:GetActiveUpdates() do
				profile.GlobalUpdates:LockActiveUpdate(update[1])
			end
			for _, update in profile.GlobalUpdates:GetLockedUpdates() do
				processGlobalUpdate(player, update[2])
				profile.GlobalUpdates:ClearLockedUpdate(update[1])
			end

			profile.GlobalUpdates:ListenToNewActiveUpdate(function(update_id)
				profile.GlobalUpdates:LockActiveUpdate(update_id)
			end)
			profile.GlobalUpdates:ListenToNewLockedUpdate(function(update_id, update_data)
				processGlobalUpdate(player, update_data)
				profile.GlobalUpdates:ClearLockedUpdate(update_id)
			end)
		else
			profile:Release()
		end
	else
		player:Kick(
			"\nYour player data could not be loaded due to unknown reasons.\nNo data was corrupted during this process, you may rejoin."
		)
	end
end

local function getData(player, dataName)
	if player ~= nil and dataName ~= nil then
		if profiles[player] ~= nil and profiles[player]["Data"] ~= nil then
			if profiles[player]["Data"][dataName] ~= nil then
				local data = profiles[player]["Data"][dataName]
				if type(data) == "table" then
					return table.clone(profiles[player]["Data"][dataName])
				else
					return data
				end
			end
		end
	end
end

function ProfileService:Update(player, dataName, updateFunction)
	if not self:IsProfileLoaded(player) then
		return
	end

	profiles[player].Data[dataName] = updateFunction(profiles[player].Data[dataName])

	local value = profiles[player].Data[dataName]
	self.OnProfileUpdate:Fire(player, dataName, value)
	self.Client.OnProfileUpdate:Fire(player, dataName, value)
end

function ProfileService:GlobalUpdate(userId)
	local payload = {
		Data = {},
	}

	function payload:Increment(dataPath, value) -- Can only be used on numbers
		table.insert(self.Data, {
			Type = "Increment",
			Path = dataPath,
			Value = value,
		})
	end
	function payload:Insert(dataPath, value) -- Can only be used on tables
		table.insert(self.Data, {
			Type = "Insert",
			Path = dataPath,
			Value = value,
		})
	end
	function payload:Set(dataPath, value) -- Can be used on any value
		table.insert(self.Data, {
			Type = "Set",
			Path = dataPath,
			Value = value,
		})
	end
	function payload:Publish()
		ProfileStore:GlobalUpdateProfileAsync(tostring(userId), function(global_updates)
			global_updates:AddActiveUpdate(self.Data)
		end)
	end

	return payload
end

function ProfileService:GetProfile(player)
	if self:IsProfileLoaded(player) then
		return table.clone(profiles[player].Data)
	end
end

function ProfileService:Get(...)
	return getData(...)
end

function ProfileService.Client:Get(...)
	return getData(...)
end

function ProfileService:IsProfileLoaded(player)
	return profiles[player] ~= nil and profiles[player]["Data"] ~= nil
end

function ProfileService.Client:IsProfileLoaded(player)
	return profiles[player] ~= nil and profiles[player]["Data"] ~= nil
end

function ProfileService:OnStart()
	-- SERVICE REFERENCES

	for _, player in pairs(Players:GetPlayers()) do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile ~= nil then
			profile:Release()
		end
	end)
end

return ProfileService
