local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

Cardinal.Load(game:GetService("ServerStorage"):WaitForChild("Server"):WaitForChild("Services"), {Deep = true})

Cardinal.Start():andThen(function()
    print("Server started")
end)