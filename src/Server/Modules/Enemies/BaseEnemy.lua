local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseEnemy = {}
BaseEnemy.__index = BaseEnemy

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BattleUpdate = Remotes:WaitForChild("BattleUpdate")
local NPCUpdate = Remotes:WaitForChild("NPCUpdate")

function BaseEnemy.new(...)
    local args = {...}

	local self = setmetatable({}, BaseEnemy)
	self.Health = 100
	self.MaxHealth = 100
	self.Damage = 10
    self.Speed = math.random(10, 20)
    self.Alive = true
    self.IsEnemy = true
    self.Owner = nil
    self.UniqueId = nil
    self.AttackDelay = 1
    self.Abilities = {}

	return self
end

function BaseEnemy:Spawn(player: Player, spot: number, uniqueId: string)
    self.UniqueId = uniqueId
    self.Owner = player.UserId
    BattleUpdate:FireClient(player, "SpawnUnit", self, spot, true)

    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.Name = self.UniqueId
    part.Parent = workspace.Arena.Characters.Enemy

    part:SetAttribute("Health", self.Health)
    part:SetAttribute("MaxHealth", self.MaxHealth)
    part:SetAttribute("Damage", self.Damage)
    part:SetAttribute("Speed", self.Speed)
    part:SetAttribute("Alive", self.Alive)
    part:SetAttribute("IsEnemy", self.IsEnemy)
    part:SetAttribute("UniqueId", self.UniqueId)
    part:SetAttribute("Owner", self.Owner)
    part:SetAttribute("AttackDelay", self.AttackDelay)
    part:SetAttribute("Name", self.Name)

    self.Part = part
end

function BaseEnemy:TakeDamage(amount: number)
    self.Health = math.max(self.Health - amount, 0)

    self.Part:SetAttribute("Health", self.Health)

	if self.Health == 0 then
		self.Alive = false
        self.Part:SetAttribute("Alive", false)
	end
end

function BaseEnemy:IsAlive()
    return self.Health > 0
end

function BaseEnemy:Attack(target)
	target:TakeDamage(self.Damage)
end

return BaseEnemy