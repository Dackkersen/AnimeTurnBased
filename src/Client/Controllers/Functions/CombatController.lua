--|=| Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--|=| Core
local Cardinal = require(ReplicatedStorage.Packages.Cardinal)
local CombatController = {}

--|=| Dependencies
local ProfileService = Cardinal.GetService("ProfileService")
local Replicator = require(script.Parent.Parent.Parent.Modules.CharacterAnimations.Replicator)

--|=| Constants
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BattleUpdate = Remotes:WaitForChild("BattleUpdate")

local Characters = ReplicatedStorage:WaitForChild("Characters")

local Arena = workspace:WaitForChild("Arena")
local EnemyPoints = Arena:WaitForChild("EnemyPoints")
local PlayerPoints = Arena:WaitForChild("PlayerPoints")

--|=| Variables
local player = Cardinal.Player
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local BattleUI = playerGui:WaitForChild("BattleUI")
local BattleLog = BattleUI:WaitForChild("BattleLog")

local connections = {}
local selected = nil
local selectedAction = "Attack"

--|=| Functions
local function findCharacterById(id: string, visual: boolean): Model?
    if visual then
        for _, character in Arena.CharactersVisual:GetDescendants() do
            if character.Name == id then
                return character
            end
        end

        return nil
    end

    for _, character in Arena.Characters:GetDescendants() do
        if character.Name == id then
            return character
        end
    end

    return nil
end

local function UpdateHealth(targetNPC: Model, health: number, maxHealth: number)
    targetNPC:SetAttribute("Health", health)
      
    local targetHealthBar = targetNPC.Head:FindFirstChild("HealthBar")

    if targetHealthBar then
        targetHealthBar.Back.HealthAmount.Text = "(" ..tostring(health) .. "/" .. tostring(maxHealth) .. ")"
        TweenService:Create(targetHealthBar.Back.Progress, TweenInfo.new(0.5), {Size = UDim2.new(health / maxHealth, 0, 1, 0)}):Play()
    end
end

function CombatController:StartPlayerActionMenu()
    for _, child in BattleUI:GetChildren() do
        if child:IsA("TextButton") and child.Name == selectedAction then
            TweenService:Create(child.UIStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
        end
    end

    BattleUI.Attack.Visible = true
    BattleUI.Ability1.Visible = true
    BattleUI.Ability2.Visible = true

    BattleUI.Attack.Activated:Connect(function()
        selectedAction = "Attack"
        TweenService:Create(BattleUI.Attack.UIStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
    end)

    BattleUI.Ability1.Activated:Connect(function()
        selectedAction = "Ability1"
        TweenService:Create(BattleUI.Ability1.UIStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
    end)

    BattleUI.Ability2.Activated:Connect(function()
        selectedAction = "Ability2"
        TweenService:Create(BattleUI.Ability2.UIStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
    end)
end

function CombatController:OnTargetClicked(targetId)
    self.EnableClicking = false

    BattleUI.Attack.Visible = false
    BattleUI.Ability1.Visible = false
    BattleUI.Ability2.Visible = false

    Remotes.BattleUpdate:FireServer("Attack", {
        attackerId = self.CurrentAttacker,
        targetId = targetId
    })
end

function CombatController:StartPlayerTurn(fighterId: string)
    self.CurrentAttacker = fighterId
    self.EnableClicking = true

    -- disconnect any existing click handlers
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end

    for _, enemyModel in Arena.CharactersVisual.Enemy:GetChildren() do
        -- Setup click handlers
        connections[enemyModel.Name .. "CLICK"] = enemyModel.Hitbox.ClickDetector.MouseClick:Connect(function()
            if enemyModel:GetAttribute("Health") <= 0 then
                return -- Ignore if the enemy is dead
            end

            if self.EnableClicking then
                if selected == enemyModel.Name then
                    self:OnTargetClicked(enemyModel.Name)
                    self.EnableClicking = false
                    selected = nil

                    connections[enemyModel.Name .. "CLICK"]:Disconnect()
                    connections[enemyModel.Name .. "HOVERENTER"]:Disconnect()
                    connections[enemyModel.Name .. "HOVERLEAVE"]:Disconnect()

                    local highlight = enemyModel:FindFirstChild("HoverHighlight")
                    if highlight then
                        highlight:Destroy()
                    end

                    return
                end

                selected = enemyModel.Name

                TweenService:Create(camera, TweenInfo.new(0.5), {CFrame = CFrame.lookAt(camera.CFrame.Position, enemyModel.HumanoidRootPart.Position) }):Play()
            end
        end)

        connections[enemyModel.Name .. "HOVERENTER"] = enemyModel.Hitbox.ClickDetector.MouseHoverEnter:Connect(function()
            -- Show hover effect or highlight
            local highlight = Instance.new("Highlight")
            highlight.Name = "HoverHighlight"
            highlight.FillTransparency = 1
            highlight.Parent = enemyModel
        end)

        connections[enemyModel.Name .. "HOVERLEAVE"] = enemyModel.Hitbox.ClickDetector.MouseHoverLeave:Connect(function()
            -- Remove hover effect or highlight
            local highlight = enemyModel:FindFirstChild("HoverHighlight")
            if highlight then
                highlight:Destroy()
            end
        end)
    end
end

function CombatController:OnStart()
    --|=| SERVICE & CONTROLLER REFERENCES
    Replicator:Load()

    BattleUpdate.OnClientEvent:Connect(function(action, ...)
        if action == "SpawnUnit" then
            local args = {...}

            local data: table = args[1]
            local spot: number = args[2]
            local IsEnemy: boolean = args[3]

            if not Characters:FindFirstChild(data.Name) then
                warn("Character not found in ReplicatedStorage")
                return -- No character found
            end

            local character = Characters[data.Name]:Clone()
            character:PivotTo(IsEnemy and EnemyPoints[spot].CFrame or PlayerPoints[spot].CFrame)
            character.Name = data.UniqueId
            character.Humanoid.AutoRotate = false
            character.Parent = IsEnemy and Arena.CharactersVisual.Enemy or Arena.CharactersVisual.Player

            character:SetAttribute("Health", data.Health)

            -- create an invisible hitbox for the character the size of the character
            local hitbox = Instance.new("Part")
            hitbox.Size = character:GetExtentsSize()
            hitbox.Transparency = 1
            hitbox.CanCollide = false
            hitbox.Massless = true
            hitbox.CFrame = character.HumanoidRootPart.CFrame
            hitbox.Name = "Hitbox"
            hitbox.Parent = character
            
            local weld = Instance.new("WeldConstraint")
            weld.Name = "HitboxWeld"
            weld.Part0 = hitbox
            weld.Part1 = character.HumanoidRootPart
            weld.Parent = hitbox

            local clickDetector = Instance.new("ClickDetector")
            clickDetector.Parent = hitbox
            clickDetector.MaxActivationDistance = 100

            local HealthBar = Characters:WaitForChild("HealthBar"):Clone()
            HealthBar.Parent = character:WaitForChild("Head")

            HealthBar.Back.HealthAmount.Text = "(" ..tostring(data.Health) .. "/" .. tostring(data.MaxHealth) .. ")"
        elseif action == "YourTurn" then
            -- Show move selection UI for the unit with ID data
            local attackerId = ...
            self:StartPlayerTurn(attackerId)
            BattleLog.Text = "Your turn! Select a target."

            local attackerNPC = findCharacterById(attackerId, true)
            if not attackerNPC then
                warn("Attacker not found")
                return
            end

            TweenService:Create(camera, TweenInfo.new(0.5), {CFrame = attackerNPC.Head.CFrame * CFrame.new(5, 2, 4) * CFrame.Angles(0, math.rad(25), 0)}):Play()
        elseif action == "EnemyTurn" then
            BattleLog.Text = "Enemy's turn!"
            TweenService:Create(camera, TweenInfo.new(0.5), {CFrame = Arena.CameraPosition.CFrame}):Play()
        elseif action == "Attack" then
            -- Play attack animation between attacker and target
            local args = ...

            local attackerNPCData = findCharacterById(args.attackerId, false)
            local targetNPCData = findCharacterById(args.targetId, false)
            local targetNPC = findCharacterById(args.targetId, true)
            local attackerNPC = findCharacterById(args.attackerId, true)

            if not attackerNPCData or not targetNPCData then
                warn("Attacker or Target Data not found")
                return
            end

            Replicator:ReplicateAnimation(
                attackerNPCData:GetAttribute("Name"), 
                player,
                "Attack",
                targetNPC,
                attackerNPC,
                attackerNPCData,
                targetNPCData
            )

            if attackerNPCData:GetAttribute("AttackDelay") then
                task.delay((attackerNPCData:GetAttribute("AttackDelay") + 0.25), function()
                    UpdateHealth(targetNPC, targetNPCData:GetAttribute("Health"), targetNPCData:GetAttribute("MaxHealth"))
                end)
                
                return
            end

            UpdateHealth(targetNPC, targetNPCData:GetAttribute("Health"), targetNPCData:GetAttribute("MaxHealth"))
        elseif action == "BattleResult" then
            if ... == "Victory" then
                -- Show victory screen
                print("Victory!")
            else
                -- Show defeat screen
                print("Defeat!")
            end
        elseif action == "GameState" then
            if ... == true then
                camera.CameraType = Enum.CameraType.Scriptable
                camera.CFrame = Arena.CameraPosition.CFrame
            else
                
            end
        end
    end)
end

return CombatController