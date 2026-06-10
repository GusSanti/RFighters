local RunService = game:GetService("RunService")
local proxy1 = newproxy()
local proxy2 = newproxy()
local cleanupMethods = table.freeze({
	"Destroy", 
	"Disconnect", 
	"destroy", 
	"disconnect"
})

local function getObjectCleanupFunction(object, fallback)
	local objectType = typeof(object)
	if objectType == "function" then
		return proxy1
	elseif objectType == "thread" then
		return proxy2
	elseif fallback then
		return fallback
	elseif objectType == "Instance" then
		return "Destroy"
	elseif objectType == "RBXScriptConnection" then
		return "Disconnect"
	elseif objectType == "table" then
		for _, method in cleanupMethods do
			if typeof(object[method]) == "function" then
				return method
			end
		end
	end
	error(("Failed to get cleanup function for object %*: %*"):format(objectType, object), 3)
end

local function assertPromiseLike(promise)
	if typeof(promise) ~= "table" or typeof(promise.getStatus) ~= "function" or typeof(promise.finally) ~= "function" or typeof(promise.cancel) ~= "function" then
		error("Did not receive a promise as an argument", 3)
	end
end

local Trove = {}
Trove.__index = Trove

Trove.new = function()
	local self = setmetatable({}, Trove)
	self._objects = {}
	self._cleaning = false
	return self
end

Trove.Add = function(self, object, cleanupMethod)
	if self._cleaning then
		error("Cannot call trove:Add() while cleaning", 2)
	end
	local cleanup = getObjectCleanupFunction(object, cleanupMethod)
	table.insert(self._objects, {object, cleanup})
	return object
end

Trove.Clone = function(self, object)
	if self._cleaning then
		error("Cannot call trove:Clone() while cleaning", 2)
	end
	return self:Add(object:Clone())
end

Trove.Construct = function(self, constructor, ...)
	if self._cleaning then
		error("Cannot call trove:Construct() while cleaning", 2)
	end
	local newObject
	if type(constructor) == "table" then
		newObject = constructor.new(...)
	elseif type(constructor) == "function" then
		newObject = constructor(...)
	end
	return self:Add(newObject)
end

Trove.Connect = function(self, object, func)
	if self._cleaning then
		error("Cannot call trove:Connect() while cleaning", 2)
	end
	return self:Add(object:Connect(func))
end

Trove.BindToRenderStep = function(self, name, priority, func)
	if self._cleaning then
		error("Cannot call trove:BindToRenderStep() while cleaning", 2)
	end
	RunService:BindToRenderStep(name, priority, func)
	self:Add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

Trove.AddPromise = function(self, promise)
	if self._cleaning then
		error("Cannot call trove:AddPromise() while cleaning", 2)
	end
	assertPromiseLike(promise)
	if promise:getStatus() == "Started" then
		promise:finally(function()
			if self._cleaning then
				return
			else
				self:_findAndRemoveFromObjects(promise, false)
			end
		end)
		self:Add(promise, "cancel")
	end
	return promise
end

Trove.Remove = function(self, object)
	if self._cleaning then
		error("Cannot call trove:Remove() while cleaning", 2)
	end
	return self:_findAndRemoveFromObjects(object, true)
end

Trove.Extend = function(self)
	if self._cleaning then
		error("Cannot call trove:Extend() while cleaning", 2)
	end
	return self:Construct(Trove)
end

Trove.Clean = function(self)
	if self._cleaning then
		return
	else
		self._cleaning = true
		for _, object in self._objects do
			self:_cleanupObject(object[1], object[2])
		end
		table.clear(self._objects)
		self._cleaning = false
		return
	end
end

Trove.WrapClean = function(self)
	return function()
		self:Clean()
	end
end

Trove._findAndRemoveFromObjects = function(self, object, cleanup)
	local objects = self._objects
	for index, item in objects do
		if item[1] == object then
			local lastIndex = #objects
			objects[index] = objects[lastIndex]
			objects[lastIndex] = nil
			if cleanup then
				self:_cleanupObject(item[1], item[2])
			end
			return true
		end
	end
	return false
end

Trove._cleanupObject = function(self, object, cleanupMethod)
	if cleanupMethod == proxy1 then
		pcall(object)
	elseif cleanupMethod == proxy2 then
		pcall(task.cancel, object)
	else
		object[cleanupMethod](object)
	end
end

Trove.AttachToInstance = function(self, instance)
	if self._cleaning then
		error("Cannot call trove:AttachToInstance() while cleaning", 2)
	elseif not instance:IsDescendantOf(game) then
		error("Instance is not a descendant of the game hierarchy", 2)
	end
	return self:Add(instance.AncestryChanged:Once(function()
		self:Destroy()
	end))
end

Trove.Destroy = function(self)
	self:Clean()
end

return {
	new = Trove.new
}
