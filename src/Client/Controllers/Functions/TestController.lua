--|=| Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--|=| Core
local Cardinal = require(ReplicatedStorage.Packages.Cardinal)
local TestController = {}

--|=| Dependencies
local ProfileService = Cardinal.GetService("ProfileService")
local TestService = Cardinal.GetService("TestService")
local CharacterUtil = require(ReplicatedStorage.Common.CharacterUtil)

--|=| Constants

--|=| Variables
local player = Cardinal.Player

--|=| Functions

function TestController:OnStart()
    --|=| SERVICE & CONTROLLER REFERENCES

    task.delay(3, function()
        print(TestService:TestFunction())

        print(CharacterUtil:GetRootPart(player).Name)
    end)

    CharacterUtil:OnCharacterReady(player, function(character)
        print("Character is ready:", character.Name)
    end)

    TestService.TestSignal:Connect(function(message)
        print("Received message from server:", message)
    end)
end

return TestController