local Players = game:GetService("Players")

return {
	Name = "clear",
	Aliases = {"cls"},
	Description = "Clear all lines above the entry line of the Cmdr window.",
	Group = 0,
	Args = {},
	ClientRun = function()
		local player = Players.LocalPlayer
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("Cmdr")
		local frame = gui:WaitForChild("Frame")

		if gui and frame then
			for _, child in pairs(frame:GetChildren()) do
				if child.Name == "Line" and child:IsA("TextLabel") then
					child:Destroy()
				end
			end
		end
		return ""
	end
}
