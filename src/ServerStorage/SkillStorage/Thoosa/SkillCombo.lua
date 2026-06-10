local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillStorage      = ReplicatedStorage.SkillStorage
local Assets            = ReplicatedStorage.SkillStorage.Shiro
local Fx                = Assets.FX

local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM) 

function module.UseSkill(char:Model)
	print("SKILL COMBO")
end

return module