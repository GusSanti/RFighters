local Settings = {};

--{{NUMBERS}} : FADE TIMES AND MORE.
Settings.RandomOffset = {-4, 4}
Settings.FadeOutTime = 1;
Settings.FadeInTime = 1;
Settings.IndicatorLength = 0.5;

--{{TWEEN VALUES}} : EASING STYLES.
Settings.FadeOutInfo = {EasingStyle = Enum.EasingStyle.Quint, EasingDirection = Enum.EasingDirection.Out}
Settings.FadeInInfo = {EasingStyle = Enum.EasingStyle.Quad, EasingDirection = Enum.EasingDirection.In}

--{{TYPES}} : COLORS, SIZES, AND MORE!
Settings.Colors = {
	["1"] = Color3.fromRGB(255, 0, 0); -- {{DAMAGED}}
	["2"] = Color3.fromRGB(0, 255, 0); -- {{HEALED}}
}

Settings.Sizes = {
	Small = UDim2.new(1.8, 0, 1.8, 0); -- {{SMALL SIZE, IM SURE IT HAS A GOOD PERSONALITY THOUGH}}
}

return Settings