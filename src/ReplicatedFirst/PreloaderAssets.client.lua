local cp = game:GetService("ContentProvider")
local replicatedStorage = game:GetService("ReplicatedStorage")

local BATCH_SIZE = 50
local Debug = false

local function startPreload()
	local timeout = 5
	local elapsed = 0
	while #replicatedStorage:GetDescendants() < 10 and elapsed < timeout do
		elapsed = elapsed + task.wait(0.5)
	end
	
	if Debug then
		warn("========== INICIANDO PRELOAD ==========")
	end

	local allDescendants = replicatedStorage:GetDescendants()
	local animationsToLoad = {}

	for _, obj in ipairs(allDescendants) do
		if obj:IsA("Animation") then
			table.insert(animationsToLoad, obj)
		end
	end

	local totalAnims = #animationsToLoad

	if totalAnims == 0 then
		if Debug then
			warn("Nenhum 'Animation' encontrado. Verifique se elas estão no ReplicatedStorage e se são do tipo Animation.")
			print("Itens encontrados no RS:", #allDescendants)
		end
		return
	end
	
	if Debug then
		warn(string.format("%d animações encontradas. Carregando...", totalAnims))
	end

	for i = 1, totalAnims, BATCH_SIZE do
		local batch = {}
		for j = i, math.min(i + BATCH_SIZE - 1, totalAnims) do
			table.insert(batch, animationsToLoad[j])
		end

		local success, err = pcall(function()
			cp:PreloadAsync(batch)
		end)

		if success then
			if Debug then
				print(string.format("✅ Lote [%d/%d] carregado.", math.min(i + BATCH_SIZE - 1, totalAnims), totalAnims))
			end
		else
			warn("Erro no lote:", err)
		end
		task.wait()
	end

	warn("========== ✅PRELOAD CONCLUÍDO ==========")
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

task.spawn(startPreload)