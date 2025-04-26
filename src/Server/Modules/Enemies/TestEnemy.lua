local BaseEnemy = require(script.Parent.BaseEnemy)

local TestEnemy = setmetatable({}, {__index = BaseEnemy})
TestEnemy.__index = TestEnemy

function TestEnemy.new(...)
    local args = {...}
	local self = setmetatable(BaseEnemy.new(), TestEnemy)

	self.Health = 20
    self.MaxHealth = 20
	self.Damage = 3.5
    self.Name = "TestEnemy"

	return self
end

return TestEnemy