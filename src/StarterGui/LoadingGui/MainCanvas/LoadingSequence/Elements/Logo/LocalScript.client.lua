local ImageLabel = script.Parent -- Assume que o script está dentro do ImageLabel

-- Configurações
local tempoEspera = 3 -- Tempo de espera em segundos antes do efeito começar
local duracaoTween = 0.7 -- Duração do efeito de escala em segundos
local estiloEasing = Enum.EasingStyle.Quad -- Estilo da animação (pode alterar)

-- Salva o tamanho original
local tamanhoOriginal = ImageLabel.Size

-- Define o tamanho inicial (pequeno)
ImageLabel.Size = UDim2.new(0, 0, 0, 0)

-- Espera o tempo definido
wait(tempoEspera)

-- Cria e executa o Tween
local tweenInfo = TweenInfo.new(
	duracaoTween,
	estiloEasing,
	Enum.EasingDirection.Out
)

local tween = game:GetService("TweenService"):Create(
	ImageLabel,
	tweenInfo,
	{Size = tamanhoOriginal}
)

tween:Play()