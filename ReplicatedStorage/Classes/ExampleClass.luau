local ExampleClass = {} --hello
ExampleClass.__index = ExampleClass

local function setUpConnections(self)
	self.Connections = {}
	self.Part.Touched:Connect(function(hit)
		self:Touched(hit)
	end)
end

function ExampleClass.new(part: BasePart)
	local self = setmetatable({}, ExampleClass)
	
	self.Part = part
	print(self.Part)
	
	setUpConnections(self)
	
	return self
end

function ExampleClass:Touched(hit)
	print(hit)
end

function ExampleClass:Destroy()
	self.Part:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
end

return ExampleClass