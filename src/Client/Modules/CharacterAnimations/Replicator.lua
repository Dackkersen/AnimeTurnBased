local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replicator = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AnimationReplicator = Remotes:WaitForChild("AnimationReplicator")
local Animations = script.Parent

function Replicator:ReplicateAnimation(abilityName: string, player: Player, animationPart: string, ...)
    local newAnimation = require(Animations:FindFirstChild(abilityName))

    if not newAnimation then
        return
    end

    if not newAnimation[animationPart] then
        return
    end

    local callback = newAnimation[animationPart]

    if callback then
        callback(newAnimation, ...)
    end
end

function Replicator:Load()
    AnimationReplicator.OnClientEvent:Connect(function(player, animationName: string, animationPart: string, ...)
        Replicator:ReplicateAbility(animationName, player, animationPart, ...)
    end)
end

return Replicator