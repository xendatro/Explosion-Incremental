local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TagService = require(ReplicatedStorage.Services.TagService)

local Classes = ReplicatedStorage:WaitForChild("Classes")

local UpgradeBoardClass        = require(Classes.UpgradeBoardClass)
local BiomeWallBoardClass      = require(Classes.BiomeWallBoardClass)
local WorkerBoardClass         = require(Classes.WorkerBoardClass)
local WorkerUpgradeBoardClass  = require(Classes.WorkerUpgradeBoardClass)

return function()
	TagService:Listen("UpgradeBoard", function(board: Instance)
		task.spawn(UpgradeBoardClass.new, board :: Model)
	end, function() end, workspace)

	TagService:Listen("BiomeWallBoard", function(board: Instance)
		task.spawn(BiomeWallBoardClass.new, board :: Model)
	end, function() end, workspace)

	TagService:Listen("WorkerBoard", function(board: Instance)
		task.spawn(WorkerBoardClass.new, board :: Model)
	end, function() end, workspace)

	TagService:Listen("WorkerUpgradeBoard", function(board: Instance)
		task.spawn(WorkerUpgradeBoardClass.new, board :: Model)
	end, function() end, workspace)
end