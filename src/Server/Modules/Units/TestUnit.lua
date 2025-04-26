local BaseUnit = require(script.Parent.BaseUnit)

local TestUnit = setmetatable({}, {__index = BaseUnit})
TestUnit.__index = TestUnit

function TestUnit.new(...)
    local args = {...}
	local self = setmetatable(BaseUnit.new(), TestUnit)

	self.Health = 20
    self.MaxHealth = 20
	self.Damage = 3.5
    self.Name = "TestUnit"

	return self
end

return TestUnit