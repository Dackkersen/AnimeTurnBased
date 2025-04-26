local TweenService = game:GetService("TweenService")
local TestUnit = {}

function TestUnit:Attack(target: Model, attacker: Model, targetData: Part, attackerData: Part)
    local humanoid = attacker:FindFirstChild("Humanoid")
    local hrp = attacker:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    local originalPosition = hrp.Position
    local originalOrientation = hrp.Orientation
    print("Original Position:", originalPosition)
    print("Original Rotation:", originalOrientation)

    local targetPosition = target.HumanoidRootPart.Position + target.HumanoidRootPart.CFrame.LookVector * 2

    -- Calculate goal CFrame to face the target (same Y height)
    local lookAtCFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPosition.X, hrp.Position.Y, targetPosition.Z))

    -- Tween to face the target
    local faceTargetTweenInfo = TweenInfo.new(
        0.5, -- Duration
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    local faceTargetTween = TweenService:Create(hrp, faceTargetTweenInfo, {CFrame = lookAtCFrame})
    faceTargetTween:Play()

    -- Wait for rotation tween to finish before moving
    faceTargetTween.Completed:Wait()

    humanoid:MoveTo(targetPosition)

    local firstConnection
    firstConnection = humanoid.MoveToFinished:Connect(function()
        if firstConnection then
            firstConnection:Disconnect()
            firstConnection = nil
        end

        task.wait(1) -- Wait after reaching the target

        humanoid:MoveTo(originalPosition)

        local secondConnection
        secondConnection = humanoid.MoveToFinished:Connect(function()
            if secondConnection then
                secondConnection:Disconnect()
                secondConnection = nil
            end

            -- After walking back, tween back to original rotation
            local currentPosition = hrp.Position
            local originalRotationCFrame = CFrame.new(currentPosition) * CFrame.Angles(
                math.rad(originalOrientation.X),
                math.rad(originalOrientation.Y),
                math.rad(originalOrientation.Z)
            )

            local returnRotationTweenInfo = TweenInfo.new(
                0.5, -- Duration
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
            local returnRotationTween = TweenService:Create(hrp, returnRotationTweenInfo, {CFrame = originalRotationCFrame})
            returnRotationTween:Play()
        end)
    end)
end

return TestUnit