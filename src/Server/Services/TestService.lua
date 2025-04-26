--|=| Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

--|=| Core
local Cardinal = require(ReplicatedStorage.Packages.Cardinal)
local TestService = {Client = {
    TestSignal = Cardinal.CreateSignal()
}}

--|=| Dependencies
local ProfileService = require(ServerStorage.Server.Services.Universal.ProfileService)

--|=| Constants

--|=| Variables

--|=| Tables

--|=| Events

--|=| Functions
function TestService.Client:TestFunction(player: Player)
    -- return "Hello from the Server!"
end

function TestService:OnStart()
    --|=| SERVICE REFERENCES
    Players.PlayerAdded:Connect(function(player)
        task.delay(3, function()
            -- self.Client.TestSignal:Fire(player, "Hello from the server!")
        end)
    end)
end

return TestService