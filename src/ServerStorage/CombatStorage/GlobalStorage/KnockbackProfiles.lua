local KnockbackProfiles = {}

--[[
	Tipos de knockback:
	
	None = true
		→ não executa nada
	
	IsSelfImpulse = true
		→ usa LinearVelocity (não trava posição, respeita movimento atual)
		→ ideal para: DoubleJump, ataques Self que não devem travar o personagem
	
	Padrão (sem flags especiais)
		→ usa Tween de CFrame (posição absoluta)
		→ ideal para: knockback de vítimas, launchers, slides
	
	Campos comuns:
		Offset         = CFrame   — X=lateral, Y=altura, Z=profundidade (neg=frente)
		Duration       = number   — duração em segundos
		Style          = Enum.EasingStyle   (só Tween)
		Ease           = Enum.EasingDirection (só Tween)
		RelativeToLook = bool     — usa direção do atacante
		SmartPosition  = bool     — prediz posição pelo momentum (só Tween)
		WallCheck      = bool     — evita atravessar paredes (só Tween)
--]]

-- ═══════════════════ AIR UP ═══════════════════

KnockbackProfiles.AirCombatUpKnockback = {
	Offset         = CFrame.new(0, 14, -1),
	Duration       = 0.80,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatAttackerUpKnockback = {
	Offset         = CFrame.new(0, 12, -1),
	Duration       = 0.80,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

-- ═══════════════════ AIR ═══════════════════

KnockbackProfiles.AirCombatMaintainAirKnockback = {
	Offset         = CFrame.new(0, 0, -1),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Linear,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackPushFront = {
	Offset         = CFrame.new(0, 0, -7),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontUp = {
	Offset         = CFrame.new(0, 5, -7),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontDown = {
	Offset         = CFrame.new(0, -5, -7),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

-- ═══════════════════ EXTENDED AIR ═══════════════════

KnockbackProfiles.AirCombatMaintainAirKnockbackExtended = {
	Offset         = CFrame.new(0, 0, -1),
	Duration       = 0.55,
	Style          = Enum.EasingStyle.Linear,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFront = {
	Offset         = CFrame.new(0, 0, -7),
	Duration       = 0.55,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFrontUp = {
	Offset         = CFrame.new(0, 5, -7),
	Duration       = 0.55,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFrontDown = {
	Offset         = CFrame.new(0, -5, -7),
	Duration       = 0.55,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

-- ═══════════════════ LAUNCHERS ═══════════════════

KnockbackProfiles.LauncherLight = {
	Offset         = CFrame.new(0, 12, -17),
	Duration       = 0.52,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.LauncherDown = {
	Offset         = CFrame.new(0, 0, -15),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.LauncherUp = {
	Offset         = CFrame.new(0, 12, -2.5),
	Duration       = 0.42,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.LauncherHeavy = {
	Offset         = CFrame.new(0, 17, -25),
	Duration       = 0.65,
	Style          = Enum.EasingStyle.Quart,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

-- ═══════════════════ HIT ═══════════════════

KnockbackProfiles.HitPush = {
	Offset         = CFrame.new(0, 0, -1.75),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.HitPull = {
	Offset         = CFrame.new(0, 0, 1.75),
	Duration       = 0.35,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.SlidePopUp = {
	Offset         = CFrame.new(0, 22, -30),
	Duration       = 0.28,
	Style          = Enum.EasingStyle.Quart,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.SlideForward = {
	Offset         = CFrame.new(0, 0, -12),
	Duration       = 0.40,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.SlideForwardEnemy = {
	Offset         = CFrame.new(0, 0, -13.5),
	Duration       = 0.40,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

-- ═══════════════════ MISC ═══════════════════

-- IsSelfImpulse: usa LinearVelocity, não trava posição, respeita movimento atual
KnockbackProfiles.DoubleJump = {
	Offset         = CFrame.new(0, 6, 0),
	Duration       = 0.22,
	RelativeToLook = true,
	IsSelfImpulse  = true,
}

KnockbackProfiles.WakeUpBackKnockback = {
	Offset         = CFrame.new(0, 0, 10),
	Duration       = 0.40,
	Style          = Enum.EasingStyle.Quad,
	Ease           = Enum.EasingDirection.Out,
	RelativeToLook = true,
	SmartPosition  = true,
	WallCheck      = true,
}

KnockbackProfiles.None = {
	None = true,
}

return KnockbackProfiles