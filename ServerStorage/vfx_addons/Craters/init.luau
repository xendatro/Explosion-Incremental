--[[
    @class CratersUI
    @shared
    @description 
        UI configuration and attribute binding for Craters module.
        Manages defaults, property panels, and selection sync.
]]

local api = shared.fx
local UILib, Gaem = api.ui, require(script.game)

local Defaults = Gaem.defaults
local Properties = UILib.new {
	close = false,
	name = "Craters",
	rangeToNumber = true,
	properties = Gaem.defaults,

	categories = {
		{ "MatchGround", "Count", "Lifetime", "Size", "SizeScale", "Collision", name = "Settings" },
		{ "Shape", "Radius", "Variance", "ConeAngle", "Fill", name = "Spawning" },
		{ "EmissionStart", "EmissionEnd", "Duration", name = "Timing" },
		{ "UseMesh", "MeshId", "TextureId", name = "Visuals" },
		{ "AlignSurface", "YOffset", name = "Placement" },
		{ "AngleX", "AngleY", "AngleZ", name = "Relative Rotation" },
		{ "SpawnTime", "DespawnTime", name = "Animation" },
	},
	placeholders = {
		MeshId = "rbxassetid://",
		TextureId = "rbxassetid://"
	},
	modifiers = {
		MeshId = UILib.assetIdMod,
		TextureId = UILib.assetIdMod
	},
	tooltips = {
		Variance = "Random radius offset for each part",
		Duration = "How long it takes to gradually finish effect"
	}
}

local Icon = script.icon

UILib.classify(
	UILib.button0(Icon, Properties.ui, true),
	{Part = true, MeshPart = true, Attachment = true, BasePart = true}
)()

UILib.taggify(Properties, "CraterVFX")

UILib.attributize(Properties, 0, Defaults, function(vfx)
	return vfx:HasTag("CraterVFX")
end)

do -- presets
	local presets = script.presets
	for _, v in presets:GetChildren() do
		api.save(v, v.Name:gsub("(%l)(%u)", "%1 %2"))
	end
end

return {
	api = Gaem,
	icon = Icon.Image,
	name = "Ground Craters",
	
	description = [[
	Ground debris that adapts to the surface
	- Supports [Ring, Cone, Line] shapes
	- Supports fill, and many more options
	- by @diminutives (discord)
	]]
}