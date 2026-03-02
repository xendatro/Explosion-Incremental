local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TagService = require(ReplicatedStorage.Services.TagService)
local ServerStorage = game:GetService("ServerStorage")

local Plot            = require(ServerStorage.Classes.Plot)
local PlotService     = require(ServerStorage.Services.PlotService)

local Item            = require(ServerStorage.Classes.Item)
local ItemSpawnService = require(ServerStorage.Services.ItemSpawnService)

local WorkerNPCClass  = require(ServerStorage.Classes.WorkerNPCClass)

return function()

	TagService:Listen("Plot", function(model)
		local plot = Plot.new(model)
		PlotService:_register(plot)
		return plot
	end, function(_model, plot)
		PlotService:_unregister(plot)
		plot:Destroy()
	end, workspace)

	TagService:Listen("Item", function(model)
		-- SpawnItem creates and registers the Item before AddTag fires, so the
		-- Tagger callback (which runs deferred) must not create a duplicate.
		local existing = ItemSpawnService:GetItemForModel(model)
		if existing then return existing end
		-- Fallback: manually tagged item (e.g. a Studio test model).
		local item = Item.new(model)
		ItemSpawnService:_register(item)
		return item
	end, function(_model, item)
		ItemSpawnService:_unregister(item)
		item:Destroy()
	end, workspace)

	TagService:Listen("BiomeZone", function(part)
		ItemSpawnService:_registerZone(part)
		return part
	end, function(part, _)
		ItemSpawnService:_unregisterZone(part)
	end, workspace)

	TagService:Listen("WorkerNPC", function(model)
		return WorkerNPCClass.new(model :: Model)
	end, function(_model, npcClass)
		if npcClass then npcClass:Destroy() end
	end, workspace)

end