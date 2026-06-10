--// Services //--
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService('HttpService')

--//Variables //--
local PlaybackState = Enum.PlaybackState
local Module = {
	ImpactFrames = {}
}

--// Functions //--

function ChangeInstances(_Instances:{Instance}?,ToNormal:{Yes:boolean?,Default:{[any]:any}?},Settings:{Color:Color3,Highlight:boolean?}?): any
	local DefaultSettings = {}

	if ToNormal.Yes and ToNormal.Default then
		for _Instance, Property in ToNormal.Default do
			if _Instance:IsA('BasePart') then
				_Instance.Material = Property.Material
				_Instance.Color = Property.Color
			elseif _Instance:IsA('Decal') then
				_Instance.Transparency = Property.Transparency
			end
			if _Instance:FindFirstChild('Highlight') then
				_Instance.Highlight:Destroy()
			end
		end
		return
	end
	
	if not _Instances or not Settings then return end
	local function ApplyToBasePart(BasePart:BasePart)
		DefaultSettings[BasePart] = {}
		DefaultSettings[BasePart].Material = BasePart.Material
		DefaultSettings[BasePart].Color = BasePart.Color
		BasePart.Material = Enum.Material.Neon
		BasePart.Color = Settings.Color
	end
	
	for _, InstanceToSearch in _Instances do
		for _, _Instance in InstanceToSearch:GetDescendants() do
			if _Instance:IsA('BasePart') then
				ApplyToBasePart(_Instance)
			elseif _Instance:IsA('Decal') then
				DefaultSettings[_Instance] = {Transparency = _Instance.Transparency}
				_Instance.Transparency = 1
			end
			if Settings.Highlight then
				local Highlight = Instance.new('Highlight')
				Highlight.FillTransparency = 0
				Highlight.OutlineTransparency = 0
				Highlight.OutlineColor = Settings.Color
				Highlight.Parent = _Instance
			end
		end
	end
	return DefaultSettings
end

function Module:Create(Settings:{HitType:"White"|"Black"|"Custom",HitList:{Instance},CustomProperties:{TintColor:Color3?,Saturation:number?,Contrast:number?}?},Duration:number?,PlayOnce:boolean?): any
	local UniqueID = HttpService:GenerateGUID(false)
	local TimeStamps = {Started = 0,Ended = 0}
	local Defaults
	local ImpactFrame
	
	ImpactFrame = {State = PlaybackState.Paused,UniqueID=UniqueID}
	
	--//[ Effect Setup ] \\--
	local EffectSettings = {}
	if Settings.HitType == 'White' then
		EffectSettings = {
			Saturation = -1,
			Contrast = 25000,
			TintColor = Color3.new(0.639216, 0.635294, 0.647059),
		}
	elseif Settings.HitType == 'Black' then
		EffectSettings = {
			Saturation = -1,
			Contrast = -25000,
			TintColor = Color3.new(0.639216, 0.635294, 0.647059),
		}
	elseif Settings.HitType == 'Custom' and Settings.CustomProperties then
		EffectSettings = {
			Saturation = Settings.CustomProperties.Saturation or -1,
			Contrast = Settings.CustomProperties.Contrast or 25000,
			TintColor = Settings.CustomProperties.TintColor or Color3.new(1,1,1),
		}
	end
	Duration = Duration or 0.1

	--//[ ColorCorrection Instancing ] \\--
	local ColorCorrectionEffect = Instance.new('ColorCorrectionEffect')
	ColorCorrectionEffect.Name = `ImpactEffect | {UniqueID}`
	for Property, Value in EffectSettings do
		ColorCorrectionEffect[Property] = Value
	end
	ImpactFrame.Instance = ColorCorrectionEffect

	--//[ Effects Functions ] \\--
	function ImpactFrame:Play(Destoy)
		if ImpactFrame.State == PlaybackState.Playing then return '[ERROR]: Already Playing' end
		ImpactFrame.State = PlaybackState.Playing
		ColorCorrectionEffect.Parent = Lighting
		TimeStamps.Started = os.clock()
		Defaults = ChangeInstances(Settings.HitList,{},{Color = EffectSettings.TintColor})
		task.delay(Duration,function()
			if ImpactFrame.State == PlaybackState.Playing then  
				ChangeInstances({},{Yes=true,Default=Defaults})
				if Destoy then
					ColorCorrectionEffect:Destroy()
					table.clear(ImpactFrame)
					table.clear(Defaults)
					Defaults = nil
					ImpactFrame = nil
					return
				end
				ColorCorrectionEffect.Parent = nil
				ImpactFrame.State = PlaybackState.Completed
			end
		end)
		return 'Played'
	end
	if PlayOnce then ImpactFrame:Play(true) return end
	
	function ImpactFrame:Stop()
		if ImpactFrame.State ~= PlaybackState.Playing then return '[ERROR]: Not currently Playing' end
		ColorCorrectionEffect.Parent = nil
		ImpactFrame.State = PlaybackState.Cancelled
		ChangeInstances({},{Yes=true,Default=Defaults})
	end
	function ImpactFrame:Destroy()
		ImpactFrame:Stop()
		ColorCorrectionEffect:Destroy()
		table.clear(ImpactFrame)
		table.clear(Defaults)
		Defaults = nil
		ImpactFrame = nil
	end

	--// 2nd states //--
	function ImpactFrame:Pause()
		if ImpactFrame.State ~= PlaybackState.Playing then return '[ERROR]: Not currently Playing' end
		ImpactFrame.State = PlaybackState.Paused
		TimeStamps.Ended = os.clock()
		return 'Paused'
	end
	function ImpactFrame:Resume()
		if ImpactFrame.State ~= PlaybackState.Paused then return '[ERROR]: Not currently Paused' end
		ImpactFrame.State = PlaybackState.Playing
		local RemainingTime = Duration - (TimeStamps.Ended - TimeStamps.Started)
		ColorCorrectionEffect.Parent = Lighting
		task.delay(RemainingTime, function()
			if ImpactFrame.State == PlaybackState.Playing then  
				ColorCorrectionEffect.Parent = nil
				ImpactFrame.State = PlaybackState.Completed
			end
		end)
		return 'Resumed'
	end

	--//[ Result ] \\--
	table.insert(Module.ImpactFrames,ImpactFrame)
	return ImpactFrame
end

return Module
