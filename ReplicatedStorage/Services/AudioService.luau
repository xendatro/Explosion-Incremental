local AudioService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SoundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local WorkspaceSounds = Workspace:WaitForChild("Sounds")
local SFXGroup = WorkspaceSounds:WaitForChild("SFX")
local AmbienceGroup = WorkspaceSounds:WaitForChild("Ambience")

-- Play a 2D sound in a sound group
function AudioService:Play2D(keyName: string, group: "SFX" | "Ambience"?): Sound
	local soundTemplate = SoundsFolder:FindFirstChild(keyName)
	
	if not soundTemplate or not soundTemplate:IsA("Sound") then
		warn("Sound '" .. keyName .. "' not found in ReplicatedStorage.Sounds")
		return nil
	end
	
	-- Default to SFX if no group specified
	local targetGroup = SFXGroup
	if group == "Ambience" then
		targetGroup = AmbienceGroup
	end
	
	-- Clone the sound
	local sound = soundTemplate:Clone()
	sound.SoundGroup = targetGroup
	sound.Parent = targetGroup
	
	-- Play and destroy when finished
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	return sound
end

-- Play a 3D sound at a part
function AudioService:Play3D(keyName: string, part: BasePart): Sound
	local soundTemplate = SoundsFolder:FindFirstChild(keyName)
	
	if not soundTemplate or not soundTemplate:IsA("Sound") then
		warn("Sound '" .. keyName .. "' not found in ReplicatedStorage.Sounds")
		return nil
	end
	
	if not part or not part:IsA("BasePart") then
		warn("Invalid part provided for 3D sound")
		return nil
	end
	
	-- Clone the sound
	local sound = soundTemplate:Clone()
	sound.Parent = part
	
	-- Play and destroy when finished
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	return sound
end

return AudioService
