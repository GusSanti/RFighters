--[[
local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Debris            = game:GetService("Debris")
local SkillStorage      = ReplicatedStorage.SkillStorage
local Assets            = ReplicatedStorage.SkillStorage.CombatTest
local Fx                = Assets.Fx

local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM) 

function module.UseSkill(char:Model)
	print("Skill")
	local Player = game.Players:GetPlayerFromCharacter(char)
	local humanoid = char.Humanoid
	local humRP = char.HumanoidRootPart
	local Head = char.Head
	local Animator = humanoid.Animator
	
	if not (humanoid and humRP and Animator) or humanoid.Health <= 0 then
		return
	end

end

return module
]]
