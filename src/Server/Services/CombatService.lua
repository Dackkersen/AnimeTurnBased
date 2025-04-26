--|=| Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

--|=| Core
local Cardinal = require(ReplicatedStorage.Packages.Cardinal)
local CombatService = {Client = {}}

--|=| Dependencies
local ProfileService = require(ServerStorage.Server.Services.Universal.ProfileService)
local BaseUnit = require(ServerStorage.Server.Modules.Units.BaseUnit)
local BaseEnemy = require(ServerStorage.Server.Modules.Enemies.BaseEnemy)

--|=| Constants
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BattleUpdate = Remotes:WaitForChild("BattleUpdate")
local TURN_TIME_LIMIT = 60

--|=| Variables

--|=| Tables
local ActiveBattles = {} -- [player.UserId] = Battle
type Battle = {
    Player: Player,
    Units: { [string]: BaseUnit },
    Enemies: { [string]: BaseEnemy },
    TurnQueue: { any },
    CurrentTurnIndex: number,
    InProgress: boolean
}

--|=| Events

--|=| Functions
function CombatService:StartBattle(player: Player, playerUnitsData: {any}, enemyTypes: {any})
    if ActiveBattles[player.UserId] then
        warn("Player is already in a battle!")
        return
    end

    local battle: Battle = {
        Player = player,
        Units = {},
        Enemies = {},
        TurnQueue = {},
        CurrentTurnIndex = 1,
        InProgress = true
    }

    for i, unitData in ipairs(playerUnitsData) do
        if i > 4 then break end
        local unit = BaseUnit.new()
        for k,v in pairs(unitData) do
            unit[k] = v
        end
        local uniqueId = "Unit_"..i.."_"..player.UserId.."_"..math.random(1, 10000)
        unit:Spawn(player, i, uniqueId)
        battle.Units[uniqueId] = unit

        print("Unit spawned:", unit.Name, "with ID:", uniqueId, unit)
    end

    for i, enemyData in ipairs(enemyTypes) do
        if i > 4 then break end
        local enemy = BaseEnemy.new()
        for k,v in pairs(enemyData) do
            enemy[k] = v
        end
        local uniqueId = "Enemy_"..i.."_"..player.UserId.."_"..math.random(1, 10000)
        enemy:Spawn(player, i, uniqueId)
        battle.Enemies[uniqueId] = enemy

        print("Enemy spawned:", enemy.Name, "with ID:", uniqueId, enemy)
    end
    
    CombatService:BuildTurnQueue(battle)
    ActiveBattles[player.UserId] = battle
    CombatService:StartTurnLoop(battle)

    BattleUpdate:FireClient(player, "GameState", true)
end

function CombatService:BuildTurnQueue(battle: Battle)
    local queue = {}

    for _, unit in pairs(battle.Units) do
        if unit:IsAlive() then
            table.insert(queue, unit)
        end
    end
    for _, enemy in pairs(battle.Enemies) do
        if enemy:IsAlive() then
            table.insert(queue, enemy)
        end
    end

    table.sort(queue, function(a, b)
        return a.Speed > b.Speed
    end)

    battle.TurnQueue = queue
    battle.CurrentTurnIndex = 1
end

function CombatService:StartTurnLoop(battle: Battle)
    task.spawn(function()
        while battle.InProgress do
            local currentFighter = battle.TurnQueue[battle.CurrentTurnIndex]
            if not currentFighter or not currentFighter:IsAlive() then
                -- Skip dead fighters
                battle.CurrentTurnIndex = (battle.CurrentTurnIndex % #battle.TurnQueue) + 1
                continue
            end

            if currentFighter.IsEnemy then
                -- Enemy AI Turn
                CombatService:EnemyTurn(battle, currentFighter)
                BattleUpdate:FireClient(battle.Player, "EnemyTurn", currentFighter.UniqueId)
            else
                -- Player Turn
                BattleUpdate:FireClient(battle.Player, "YourTurn", currentFighter.UniqueId)

                -- Wait for player action (or timeout)
                local turnFinished = false

                local connection
                connection = Remotes.BattleUpdate.OnServerEvent:Connect(function(player, action, data)
                    if player ~= battle.Player then return end

                    local target = battle.Units[data.targetId] or battle.Enemies[data.targetId]

                    if target.Health <= 0 then
                        return
                    end

                    if action == "Attack" and data.attackerId == currentFighter.UniqueId then
                        CombatService:HandleAttack(battle, currentFighter, data.targetId)
                        turnFinished = true
                        connection:Disconnect()
                    end
                end)

                local startTime = tick()
                repeat
                    task.wait(0.1)
                until turnFinished or (tick() - startTime > TURN_TIME_LIMIT)

                if not turnFinished then
                    -- Timeout, auto-skip or random move
                    CombatService:AutoAttack(battle, currentFighter)
                    connection:Disconnect()
                end
            end
            
            CombatService:CheckBattleStatus(battle)

            -- Next Turn
            battle.CurrentTurnIndex = (battle.CurrentTurnIndex % #battle.TurnQueue) + 1
            task.wait(1.5 + currentFighter.AttackDelay) -- Wait for attack animation to finish
        end
    end)
end

function CombatService:EnemyTurn(battle: Battle, enemy)
    -- Very simple AI: attack random player unit
    local aliveUnits = {}
    for _, unit in battle.Units do
        if unit:IsAlive() then
            table.insert(aliveUnits, unit)
        end
    end
    if #aliveUnits == 0 then return end

    local target = aliveUnits[math.random(1, #aliveUnits)]

    task.delay(enemy.AttackDelay, function()
        enemy:Attack(target)
    end)

    BattleUpdate:FireClient(battle.Player, "Attack", {attackerId = enemy.UniqueId, targetId = target.UniqueId, target = target, attackDelay = enemy.AttackDelay})

    task.wait(0.5)
end

function CombatService:HandleAttack(battle: Battle, attacker, targetId: string)
    local target = battle.Units[targetId] or battle.Enemies[targetId]
    if not target or not target:IsAlive() then return end

    task.delay(attacker.AttackDelay, function()
        attacker:Attack(target)
    end)

    BattleUpdate:FireClient(battle.Player, "Attack", {attackerId = attacker.UniqueId, targetId = targetId, target = target, attackDelay = attacker.AttackDelay})
end

function CombatService:AutoAttack(battle: Battle, attacker)
    local enemies = {}
    for _, enemy in pairs(battle.Enemies) do
        if enemy:IsAlive() then
            table.insert(enemies, enemy)
        end
    end
    if #enemies == 0 then return end

    local target = enemies[math.random(1, #enemies)]
    attacker:Attack(target)
    BattleUpdate:FireClient(battle.Player, "Attack", {attackerId = attacker.UniqueId, targetId = target.UniqueId})
end

function CombatService:CheckBattleStatus(battle: Battle)
    local playerAlive = false
    for _, unit in pairs(battle.Units) do
        if unit:IsAlive() then
            playerAlive = true
            break
        end
    end

    print("Player Alive:", playerAlive)

    local enemyAlive = false
    for _, enemy in pairs(battle.Enemies) do
        if enemy:IsAlive() then
            enemyAlive = true
            break
        end
    end
    
    print("Enemy Alive:", enemyAlive)

    if not playerAlive then
        BattleUpdate:FireClient(battle.Player, "BattleResult", "Defeat")
        CombatService:EndBattle(battle)
    elseif not enemyAlive then
        BattleUpdate:FireClient(battle.Player, "BattleResult", "Victory")
        CombatService:EndBattle(battle)
    end
end

function CombatService:EndBattle(battle: Battle)
    ActiveBattles[battle.Player.UserId] = nil
    battle.InProgress = false
end

function CombatService:OnStart()
    --|=| SERVICE REFERENCES

    workspace.BattleNPC.ProximityPrompt.Triggered:Connect(function(player)
        if not ActiveBattles[player.UserId] then
            local playerUnits = {
                {
                    Name = "TestUnit",
                    Health = 100,
                    MaxHealth = 100,
                    Damage = 15,
                    Speed = 12,
                    AttackDelay = 2,
                    Abilties = { "Fireball", "Ice Spike" }
                },
                {
                    Name = "TestUnit",
                    Health = 80,
                    MaxHealth = 80,
                    Damage = 20,
                    Speed = 18,
                    AttackDelay = 2,
                    Abilties = { "Fireball", "Ice Spike" }
                },
            }
        
            -- Example enemies
            local enemies = {
                { Name = "TestEnemy", Health = 100, MaxHealth = 100, Damage = 10, Speed = 10, AttackDelay = 2 },
                { Name = "TestEnemy", Health = 120, MaxHealth = 120, Damage = 12, Speed = 15, AttackDelay = 2 },
            }

            CombatService:StartBattle(player, playerUnits, enemies)
        end
    end)
end

return CombatService