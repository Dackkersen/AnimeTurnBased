local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

Cardinal.Load(script.Parent:WaitForChild("Client"):WaitForChild("Controllers"), {Deep = true})

Cardinal.Start():andThen(function()
    print("Client started")
end)