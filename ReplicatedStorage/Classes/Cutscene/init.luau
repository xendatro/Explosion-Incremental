-- Cutscene
-- Clean Moon Animator export player.
--
-- Usage:
--   local Cutscene = require(ReplicatedStorage.Classes.Cutscene)
--   local cs = Cutscene.new(myStringValue, workspace.Map)
--   cs:OnMarker("MyMarker", function(value) print(value) end)
--   cs.Finished.Event:Connect(function() print("done") end)
--   cs:Play()

local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Easing      = require(script.Easing)

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────────────────────────────────────

local IGNORE = {
	_RigContainer_collapsed    = true,
	_PropertyContainer_collapsed = true,
}

-- Properties that snap instead of lerp
local SNAP_PROPS = {
	Anchored = true, CastShadow = true, Enabled = true, Text = true,
	Looped   = true, Playing    = true, SoundId  = true, Font = true,
}

-- Properties that are method calls, not assignments
local CALL_PROPS = {
	Play = true, Stop = true, Pause = true, Resume = true,
	PlayOnce = true, Emit = true,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Private helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function getEaseFn(easeData: {string}?)
	if not easeData then return Easing.Linear end
	local name = (easeData[1] or "Linear") .. (easeData[2] or "")
	return Easing[name] or Easing.Linear
end

-- Read easing info out of a keyframe folder
local function readEase(kf: Folder): {string}?
	local e = kf:FindFirstChild("Eases")
	if not e then return nil end
	local e0 = e:FindFirstChild("0")
	if not e0 then return nil end
	local t = { e0.Type.Value }
	if e0:FindFirstChild("Params") then
		t[2] = e0.Params.Direction.Value
	end
	return t
end

-- Sample a keyframe table at timeElapsed.
-- Returns: nextKF {ease, value}, prevKF {ease, value}|nil, alpha
local function sample(timeElapsed: number, kfs: table)
	local frames = {}
	for k in kfs do
		if type(k) == "number" then
			table.insert(frames, k)
		end
	end
	if #frames == 0 then return nil, nil, 0 end
	table.sort(frames)

	local prevF, nextF
	for _, f in frames do
		if f <= timeElapsed then
			prevF = f
		elseif not nextF then
			nextF = f
		end
	end

	-- Past the last keyframe — hold final value
	if not nextF then
		return kfs[frames[#frames]], kfs[frames[#frames - 1]], 1
	end

	local span = nextF - (prevF or 0)
	local t = span == 0 and 1 or math.clamp((timeElapsed - (prevF or 0)) / span, 0, 1)
	local easeFn = getEaseFn(prevF and kfs[prevF] and kfs[prevF][1])
	return kfs[nextF], prevF and kfs[prevF] or nil, easeFn(t)
end

-- Lerp two values of any supported type
local function lerpValue(a: any, b: any, alpha: number): any
	if b == nil then return a end
	local t = typeof(b)
	if t == "number"  then return a ~= nil and lerp(a, b, alpha) or b end
	if t == "CFrame"  then return a ~= nil and a:Lerp(b, alpha)  or b end
	if t == "Color3"  then return a ~= nil and a:Lerp(b, alpha)  or b end
	if t == "Vector3" then return a ~= nil and a:Lerp(b, alpha)  or b end
	-- Everything else (bool, string, Enum string, sequences): snap
	return alpha >= 1 and b or a
end

-- Apply an animated C1 value to a Motor6D or Bone
local function applyJoint(joint: Motor6D | Bone, nextCF: CFrame, prevCF: CFrame, alpha: number)
	local value = lerpValue(prevCF, nextCF, alpha)
	if joint:IsA("Bone") then
		joint.Transform = value
	else
		local default = joint.Part0.CFrame * joint.C0
		local fLast   = default * (prevCF or value):Inverse()
		local fNext   = default * value:Inverse()
		joint.C1      = fLast:Lerp(fNext, alpha):Inverse() * default
	end
end

-- Apply a property value to an instance (handles camera + enums + method calls)
local function applyProperty(instance: Instance, prop: string, value: any, alpha: number)
	if CALL_PROPS[prop] then
		if alpha >= 1 then pcall(function() instance[prop](instance) end) end
		return
	end
	if prop == "Material"   then pcall(function() instance.Material    = Enum.Material[value]   end); return end
	if prop == "RollOffMode" then pcall(function() instance.RollOffMode = Enum.RollOffMode[value] end); return end
	if prop == "CFrame" then
		if instance:IsA("Camera") then
			instance.CameraType = Enum.CameraType.Scriptable
			instance.CFrame     = value
			instance.Focus      = value
		elseif instance:IsA("Model") then
			instance:PivotTo(value)
		else
			pcall(function() instance.CFrame = value end)
		end
		return
	end
	pcall(function() instance[prop] = value end)
end

-- True if any keyframe in this track stores an ObjectValue (AttachToPart, LookAtPart).
-- These referent IDs don't survive export so we skip the track entirely.
local function isObjectTrack(track: Folder): boolean
	for _, kf in track:GetChildren() do
		local values = kf:FindFirstChild("Values")
		if values then
			for _, v in values:GetChildren() do
				if v:IsA("ObjectValue") then return true end
			end
		end
	end
	return false
end

-- Resolve an instance from a Moon Animator path table
local function resolveInstance(path: table, folder: Instance?): Instance?
	if path.ItemType == "Camera" then
		return workspace.CurrentCamera
	end
	local obj: Instance = folder or game
	for i, name in path.InstanceNames do
		if i <= (folder and 2 or 1) then continue end
		local found: Instance?
		for _, child in obj:GetChildren() do
			if child.Name == name and child:IsA(path.InstanceTypes[i]) then
				found = child
				break
			end
		end
		if not found then return nil end
		obj = found
	end
	return obj
end

-- Find the Motor6D or Bone that drives a named joint hierarchy
local function findMotor(rig: Instance, hierPath: string): Motor6D | Bone | nil
	local parts = hierPath:split(".")
	local partName = parts[#parts]

	-- Motor6D lookup
	local targetPart: BasePart?
	for _, v in rig:GetDescendants() do
		if v:IsA("BasePart") and v.Name == partName then
			targetPart = v; break
		end
	end
	if targetPart then
		for _, v in rig:GetDescendants() do
			if v:IsA("Motor6D") and v.Part1 == targetPart then return v end
		end
	end

	-- Bone chain fallback
	for _, v in rig:GetDescendants() do
		if v:IsA("Bone") and v.Name == parts[1] then
			local bone: Instance = v
			for i = 2, #parts do
				bone = bone:FindFirstChild(parts[i])
				if not bone then break end
			end
			if bone then return bone :: Bone end
		end
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Cutscene class
-- ─────────────────────────────────────────────────────────────────────────────

local Cutscene = {}
Cutscene.__index = Cutscene

-- file   : the exported Moon Animator StringValue (its .Value is JSON, children are frame folders)
-- folder : optional map/model that acts as the search root for instance paths
function Cutscene.new(file: StringValue, folder: Instance?)
	local self = setmetatable({}, Cutscene)

	self._file    = file
	self._data    = HttpService:JSONDecode(file.Value)
	self._fps     = self._data.Information.FPS    or 60
	self._length  = self._data.Information.Length or 0
	self._folder  = folder

	self._instances       = {} -- [objIdx] → resolved Instance
	self._objs            = {} -- [objIdx] → parsed property/rig tables
	self._rawFolders      = {} -- [objIdx] → raw Folder (kept for Replace re-parse)
	self._offsets         = {} -- [objIdx] → CFrame offset applied to CFrame keyframes
	self._markers         = {} -- array of { frame, name, value, _fired }
	self._markerCallbacks = {} -- [markerName] → { callback, ... }

	self._playing     = false
	self._timeElapsed = 0

	self.Finished = Instance.new("BindableEvent")

	self:_resolveInstances()
	self:_parseAll()

	return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Parsing
-- ─────────────────────────────────────────────────────────────────────────────

function Cutscene:_resolveInstances()
	for i, itemData in self._data.Items do
		self._instances[i] = resolveInstance(itemData.Path, self._folder)
	end
end

function Cutscene:_parseAll()
	self._objs    = {}
	self._markers = {}
	for _, child in self._file:GetChildren() do
		local idx = tonumber(child.Name)
		if idx then self:_parseObj(idx, child) end
	end
end

function Cutscene:_parseObj(idx: number, folder: Folder)
	self._rawFolders[idx] = folder

	local obj = { Rig = {} }

	for _, track in folder:GetChildren() do
		if IGNORE[track.Name] then continue end

		-- ── Marker track ──────────────────────────────────────────────────────
		if track.Name == "MarkerTrack" then
			for _, kf in track:GetChildren() do
				local frame = tonumber(kf.Name)
				if not frame then continue end
				local kfm = kf:FindFirstChild("KFMarkers")
				if not kfm then continue end
				for _, marker in kfm:GetChildren() do
					local val = marker:FindFirstChild("Val")
					table.insert(self._markers, {
						frame  = frame,
						name   = marker.Value,
						value  = val and val.Value or nil,
						_fired = false,
					})
				end
			end
			continue
		end

		-- ── Rig / joint track ─────────────────────────────────────────────────
		if track.Name == "Rig" then
			local rig = self._instances[idx]
			for _, joint in track:GetChildren() do
				local kfsFolder = joint:FindFirstChild("_keyframes")
				if not kfsFolder or #kfsFolder:GetChildren() == 0 then continue end
				if not rig then continue end

				local motor = findMotor(rig, joint._hier.Value)
				if not motor then
					warn(string.format("Cutscene: missing joint '%s' on %s", joint._hier.Value, tostring(rig)))
					continue
				end

				local layer = #joint._hier.Value:split(".")
				obj.Rig[layer] = obj.Rig[layer] or {}

				local kfs = { default = joint.default.Value, joint = motor }
				for _, kf in kfsFolder:GetChildren() do
					local i = tonumber(kf.Name)
					if not i then continue end
					local ease = readEase(kf)
					for _, n in kf.Values:GetChildren() do
						local e = tonumber(n.Name)
						if not e then continue end
						kfs[i + e] = { ease, n.Value }
					end
				end

				obj.Rig[layer][joint._hier.Value] = kfs
			end
			continue
		end

		-- ── Skip ObjectValue-based tracks (AttachToPart, LookAtPart) ──────────
		if isObjectTrack(track) then continue end

		-- ── Regular property track ────────────────────────────────────────────
		local defaultObj = track:FindFirstChild("default")
		if not defaultObj then continue end

		local kfs = { default = defaultObj.Value }
		for _, kf in track:GetChildren() do
			local i = tonumber(kf.Name)
			if not i then continue end
			local ease = readEase(kf)
			for _, n in kf.Values:GetChildren() do
				local e = tonumber(n.Name)
				if not e then continue end
				kfs[i + e] = { ease, n.Value }
			end
		end

		obj[track.Name] = kfs
	end

	self._objs[idx] = obj
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Per-frame update
-- ─────────────────────────────────────────────────────────────────────────────

function Cutscene:_tick(timeElapsed: number)
	-- Fire any markers whose frame we've passed
	for _, marker in self._markers do
		if not marker._fired and timeElapsed >= marker.frame then
			marker._fired = true
			local cbs = self._markerCallbacks[marker.name]
			if cbs then
				for _, cb in cbs do
					task.spawn(cb, marker.value)
				end
			end
		end
	end

	-- Animate all objects
	for idx, obj in self._objs do
		local instance = self._instances[idx]
		if not instance then continue end

		-- Rig joints (ordered by hierarchy depth so parents move first)
		for _, layer in obj.Rig do
			for _, kfs in layer do
				local nxt, prv, alpha = sample(timeElapsed, kfs)
				if nxt then
					applyJoint(kfs.joint, nxt[2], prv and prv[2] or kfs.default, alpha)
				end
			end
		end

		-- Properties
		local offset = self._offsets[idx]
		for prop, kfs in obj do
			if prop == "Rig" then continue end
			local nxt, prv, alpha = sample(timeElapsed, kfs)
			if nxt then
				local value = SNAP_PROPS[prop]
					and (alpha >= 1 and nxt[2] or (prv and prv[2] or kfs.default))
					or  lerpValue(prv and prv[2] or kfs.default, nxt[2], alpha)
				-- Apply world offset for CFrame tracks when one is set
				if prop == "CFrame" and offset then
					value = offset * value
				end
				applyProperty(instance, prop, value, alpha)
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

function Cutscene:Play()
	-- Reset state for a fresh play
	self._timeElapsed = 0
	self._playing     = true
	for _, m in self._markers do m._fired = false end

	local tag = "Cutscene_" .. self._file.Name
	RunService:UnbindFromRenderStep(tag) -- safety: clear any previous binding

	RunService:BindToRenderStep(tag, Enum.RenderPriority.Camera.Value + 1, function(dt)
		self._timeElapsed += dt * self._fps
		self:_tick(self._timeElapsed)

		if self._timeElapsed >= self._length then
			self:Stop()
			self.Finished:Fire()
		end
	end)
end

function Cutscene:Stop()
	if not self._playing then return end
	self._playing = false
	RunService:UnbindFromRenderStep("Cutscene_" .. self._file.Name)
	-- Release the camera back to default script control
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

-- Returns the object index for the item whose instance name matches the given string.
-- Useful so you don't have to hardcode magic numbers when calling Replace().
--   local playerIdx = cs:Find("Player")
--   cs:Replace(playerIdx, player.Character)
-- Searches by instance name first, then by ItemType as a fallback.
-- This means cs:Find("Camera") works even though the instance is named "CurrentCamera".
function Cutscene:Find(instanceName: string): number?
	for i, itemData in self._data.Items do
		local names = itemData.Path.InstanceNames
		if names[#names] == instanceName or itemData.Path.ItemType == instanceName then
			return i
		end
	end
	warn("Cutscene:Find — no item named '" .. instanceName .. "' in this cutscene")
	return nil
end

-- Replace the resolved instance for a given object index.
-- Useful for swapping in the local player's character.
-- The object index matches the order items appear in the Moon Animator export
-- (1-based: first item = 1, second = 2, etc.)
function Cutscene:Replace(idx: number, newInstance: Instance)
	self._instances[idx] = newInstance
	-- Re-parse so rig motor references update to the new instance
	local folder = self._rawFolders[idx]
	if folder then
		self._objs[idx] = nil
		self:_parseObj(idx, folder)
	end
end

-- Set a world-space origin for an object's CFrame track.
-- Every CFrame keyframe will be played relative to this origin instead of
-- the absolute world position recorded in Moon Animator.
-- If not called, CFrame keyframes play at their raw recorded positions.
function Cutscene:SetOffset(idx: number, origin: CFrame)
	local obj = self._objs[idx]
	if not obj or not obj.CFrame then return end -- no CFrame track, nothing to do

	-- Find the first keyframe's CFrame so we can compute the delta
	local kfs = obj.CFrame
	local frames = {}
	for k in kfs do
		if type(k) == "number" then table.insert(frames, k) end
	end
	if #frames == 0 then return end
	table.sort(frames)

	local firstCF = kfs[frames[1]][2]
	self._offsets[idx] = origin * firstCF:Inverse()
end

-- Register a callback to fire when a named marker is reached.
-- Returns a disconnect function.
function Cutscene:OnMarker(name: string, callback: (value: string?) -> nil): () -> nil
	self._markerCallbacks[name] = self._markerCallbacks[name] or {}
	table.insert(self._markerCallbacks[name], callback)
	return function()
		local list = self._markerCallbacks[name]
		local i = table.find(list, callback)
		if i then table.remove(list, i) end
	end
end

function Cutscene:Destroy()
	self:Stop()
	self.Finished:Destroy()
end

return Cutscene
