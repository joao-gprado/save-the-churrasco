-- Arquivo: main.lua

-- Variáveis Globais
local background = {}
local fontTitle
local fontMenu
local menuOptions = {"Iniciar Jogo", "Configurações", "Sair"}
local selectedOption = 1
local gameState = "menu"
local volume = 0.5  -- valor inicial (50%)

-- Variáveis do Jogador
local player = {
    x = 150,
    y = 300,
    width = 48,
    height = 48,
    speed = 200,
    jumpForce = 650,
    gravity = 1500,
    velX = 0,
    velY = 0,
    onGround = false,
    spriteSheet = nil,
    direction = "right",
    animations = {},
    currentAnimation = "idle",
    animTimer = 0,
    frame = 1,
    color = {1, 0.5, 0},  -- Cor laranja para backup
    lives = 3,            -- Número de vidas
    invulnerable = false, -- Estado de invulnerabilidade após levar dano
    invulnerableTimer = 0, -- Temporizador de invulnerabilidade
    hurtState = false,    -- Estado de "tomando dano"
    hurtTimer = 0,        -- Temporizador para animação de dano
    deathState = false,   -- Estado de "morrendo"
    deathTimer = 0        -- Temporizador para animação de morte
}

-- Variáveis do Mapa
local map = {
    tileSize = 32,
    tiles = {},
    width = 100,  -- largura do mapa em tiles
    height = 20,  -- altura do mapa em tiles
    viewX = 0,    -- posição da câmera
    viewY = 0
}

-- Variáveis de Inimigos
local enemies = {}

-- Variáveis para Parallax
local parallaxLayers = {}
local parallaxScale = 0.8  -- Escala de exibição das camadas de fundo

-- Variáveis de Game Over
local gameOver = false
local gameOverTimer = 0

-- Carregar recursos e inicializar o jogo
function love.load()
    love.window.setTitle("Jogo Maneiro")
    love.window.setMode(800, 600)
    love.graphics.setDefaultFilter("nearest", "nearest")  -- para pixels nítidos
    
    -- Carregando recursos
    loadBackgrounds()
    
    fontTitle = love.graphics.newFont(40)
    fontMenu = love.graphics.newFont(24)
    
    -- Configurar áudio
    love.audio.setVolume(volume)
    
    -- Carregar sprites do jogador
    loadPlayerSprites()
    
    -- Inicializar mapa
    initializeMap()
    
    -- Inicializar inimigos
    spawnEnemies()
    
    -- Certifique-se de que o jogador esteja em uma posição visível e segura
    resetPlayer()
    
    -- Inicializar com o estado de menu
    gameState = "menu"
    
    print("Jogo inicializado. Estado atual: " .. gameState)
end

-- Função para carregar os fundos de parallax
function loadBackgrounds()
    -- Ordem das camadas do fundo (do mais distante para o mais próximo)
    local backgroundLayers = {
        "sky",
        "background",
        "city2",
        "houses1",
        "minishop & callbox",
        "road & lamps"
    }
    
    -- Carregar cada camada
    for i, layerName in ipairs(backgroundLayers) do
        local success, result = pcall(function()
            local img = love.graphics.newImage(layerName .. ".png")
            table.insert(parallaxLayers, {
                image = img,
                speed = 0.1 * i,  -- As camadas mais próximas se movem mais rápido
                width = img:getWidth(),
                height = img:getHeight()
            })
            print("Camada de fundo carregada: " .. layerName)
        end)
        
        if not success then
            print("Erro ao carregar a camada " .. layerName .. ": " .. result)
        end
    end
    
    -- Se nenhuma camada foi carregada, criar um fundo de backup
    if #parallaxLayers == 0 then
        print("Nenhuma camada de fundo carregada. Usando cor sólida.")
    end
end

-- Função para carregar sprites do jogador
function loadPlayerSprites()
    -- Carregar sprite sheet do jogador
    local success, result = pcall(function()
        player.spriteSheet = love.graphics.newImage("player_sprites.png")
        
        -- Configurar animações baseadas nas dimensões fornecidas
        -- Dimensões da sprite sheet: 288x192 (6 colunas x 4 linhas)
        player.animations = {
            idle = {
                frames = {},
                frameCount = 4,
                speed = 5
            },
            walk = {
                frames = {},
                frameCount = 6,
                speed = 10
            },
            jump = {
                frames = {},
                frameCount = 1,
                speed = 1
            },
            hurt = {
                frames = {},
                frameCount = 1,
                speed = 1
            },
            death = {
                frames = {},
                frameCount = 1,
                speed = 1
            }
        }
        
        -- Criar quads para cada frame da animação Idle (primeira linha)
        for i = 0, player.animations.idle.frameCount - 1 do
            table.insert(player.animations.idle.frames, 
                love.graphics.newQuad(i * 48, 0, 48, 48, player.spriteSheet:getDimensions()))
        end
        
        -- Criar quads para cada frame da animação Walk (segunda linha)
        for i = 0, player.animations.walk.frameCount - 1 do
            table.insert(player.animations.walk.frames, 
                love.graphics.newQuad(i * 48, 48, 48, 48, player.spriteSheet:getDimensions()))
        end
        
        -- Usar o primeiro frame da terceira linha para Jump
        player.animations.jump.frames = {love.graphics.newQuad(0, 96, 48, 48, player.spriteSheet:getDimensions())}
        
        -- Hurt animation (terceira linha, segundo frame)
        player.animations.hurt.frames = {love.graphics.newQuad(48, 96, 48, 48, player.spriteSheet:getDimensions())}
        
        -- Death animation (quarta linha, primeiro frame)
        player.animations.death.frames = {love.graphics.newQuad(0, 144, 48, 48, player.spriteSheet:getDimensions())}
        
        print("Sprites do jogador carregadas com sucesso")
    end)
    
    if not success then
        print("Erro ao carregar sprites do jogador: " .. result)
        print("Usando retângulo colorido como substituto.")
        player.spriteSheet = nil
    end
end

-- Função para inicializar o mapa
function initializeMap()
    -- Limpar as tabelas anteriores
    map.tiles = {}
    
    -- Criando um mapa mais estruturado e jogável
    for y = 1, map.height do
        map.tiles[y] = {}
        for x = 1, map.width do
            -- Criar base sólida (chão principal com buracos)
            if y == map.height - 1 then
                -- Criar alguns buracos estratégicos para desafio
                if (x > 12 and x < 15) or (x > 28 and x < 32) or (x > 45 and x < 50) or
                   (x > 60 and x < 65) or (x > 80 and x < 85) then
                    map.tiles[y][x] = 0  -- buraco
                else
                    map.tiles[y][x] = 1  -- bloco sólido (chão)
                end
            -- Criar plataformas em alturas acessíveis
            elseif (y == map.height - 5 and x >= 10 and x <= 15) or
                   (y == map.height - 4 and x >= 20 and x <= 25) or
                   (y == map.height - 6 and x >= 30 and x <= 35) or
                   (y == map.height - 5 and x >= 40 and x <= 45) or
                   (y == map.height - 7 and x >= 50 and x <= 55) or
                   (y == map.height - 6 and x >= 60 and x <= 65) or
                   (y == map.height - 5 and x >= 70 and x <= 75) or
                   (y == map.height - 4 and x >= 80 and x <= 85) then
                map.tiles[y][x] = 1
            -- Criar algumas plataformas flutuantes em alturas acessíveis
            elseif (y == map.height - 9 and x >= 15 and x <= 18) or
                   (y == map.height - 10 and x >= 25 and x <= 28) or
                   (y == map.height - 11 and x >= 35 and x <= 38) or
                   (y == map.height - 9 and x >= 45 and x <= 48) or
                   (y == map.height - 10 and x >= 55 and x <= 58) or
                   (y == map.height - 11 and x >= 65 and x <= 68) or
                   (y == map.height - 9 and x >= 75 and x <= 78) then
                map.tiles[y][x] = 1
            -- Criar limites nas bordas do mapa
            elseif x == 1 or x == map.width then
                map.tiles[y][x] = 1
            else
                map.tiles[y][x] = 0
            end
        end
    end
    
    -- Adicionar uma plataforma segura para o jogador começar
    for x = 3, 7 do
        map.tiles[map.height - 2][x] = 1
    end
    
    print("Mapa inicializado com sucesso")
end

-- Função para criar inimigos
function spawnEnemies()
    -- Limpar lista de inimigos
    enemies = {}
    
    -- Colocar inimigos em plataformas específicas, não muito próximos uns dos outros
    local enemyPositions = {
        {x = 12 * map.tileSize, y = (map.height - 6) * map.tileSize - 32},
        {x = 22 * map.tileSize, y = (map.height - 5) * map.tileSize - 32},
        {x = 32 * map.tileSize, y = (map.height - 7) * map.tileSize - 32},
        {x = 42 * map.tileSize, y = (map.height - 6) * map.tileSize - 32},
        {x = 52 * map.tileSize, y = (map.height - 8) * map.tileSize - 32},
        {x = 62 * map.tileSize, y = (map.height - 7) * map.tileSize - 32},
        {x = 72 * map.tileSize, y = (map.height - 6) * map.tileSize - 32},
        {x = 82 * map.tileSize, y = (map.height - 5) * map.tileSize - 32}
    }
    
    for _, pos in ipairs(enemyPositions) do
        table.insert(enemies, {
            x = pos.x,
            y = pos.y,
            width = 32,
            height = 32,
            speed = 50,
            direction = (math.random() < 0.5) and -1 or 1,
            type = "basic",
            platformStart = pos.x - 32 * 2,  -- Limitar movimento a 2 tiles para cada lado
            platformEnd = pos.x + 32 * 2
        })
    end
    
    print("Inimigos criados: " .. #enemies)
end

-- Atualização da lógica do jogo
function love.update(dt)
    if gameState == "jogo" then
        if gameOver then
            gameOverTimer = gameOverTimer + dt
            if gameOverTimer >= 3 then  -- Mostrar tela de game over por 3 segundos
                gameState = "menu"
                gameOver = false
                gameOverTimer = 0
            end
        else
            updatePlayer(dt)
            updateEnemies(dt)
            updateCamera()
        end
    end
end

-- Função para atualizar a posição e estado do jogador
function updatePlayer(dt)
    -- Se estiver no estado de morte, não processar movimentos
    if player.deathState then
        player.deathTimer = player.deathTimer + dt
        if player.deathTimer >= 2 then  -- Mostrar animação de morte por 2 segundos
            gameOver = true
            player.deathState = false
            player.deathTimer = 0
        end
        return
    end
    
    -- Atualizar timer de invulnerabilidade após dano
    if player.invulnerable then
        player.invulnerableTimer = player.invulnerableTimer + dt
        if player.invulnerableTimer >= 1.5 then
            player.invulnerable = false
            player.invulnerableTimer = 0
        end
    end
    
    -- Atualizar animação de dano
    if player.hurtState then
        player.hurtTimer = player.hurtTimer + dt
        if player.hurtTimer >= 0.5 then
            player.hurtState = false
            player.hurtTimer = 0
        end
        player.currentAnimation = "hurt"
    else
        -- Movimento horizontal (se não estiver no estado de dano)
        player.velX = 0
        if love.keyboard.isDown("left") then
            player.velX = -player.speed
            player.direction = "left"
            if player.onGround then
                player.currentAnimation = "walk"
            end
        elseif love.keyboard.isDown("right") then
            player.velX = player.speed
            player.direction = "right"
            if player.onGround then
                player.currentAnimation = "walk"
            end
        else
            if player.onGround then
                player.currentAnimation = "idle"
            end
        end
        
        -- Manter animação de pulo quando estiver no ar
        if not player.onGround then
            player.currentAnimation = "jump"
        end
    end
    
    -- Aplicar gravidade
    player.velY = player.velY + player.gravity * dt
    
    -- Verificar se está no chão
    player.onGround = false
    local futureY = player.y + player.velY * dt
    local tilesBelow = checkTilesAtPosition(player.x + 5, player.x + player.width - 5, futureY + player.height)
    if tilesBelow and player.velY > 0 then
        player.y = math.floor((futureY + player.height) / map.tileSize) * map.tileSize - player.height
        player.velY = 0
        player.onGround = true
    end
    
    -- Pular (apenas se não estiver no estado de dano)
    if not player.hurtState and player.onGround and love.keyboard.isDown("space") then
        player.velY = -player.jumpForce
        player.currentAnimation = "jump"
    end
    
    -- Movimento horizontal (com colisões corrigidas)
    local futureX = player.x + player.velX * dt
    local collisionBuffer = 5
    
    -- Verificação de colisão horizontal melhorada
    local tilesHorizontal = false
    if player.velX > 0 then  -- Movendo para direita
        tilesHorizontal = checkTilesAtPosition(
            futureX + player.width - collisionBuffer, 
            futureX + player.width + 1, 
            player.y + collisionBuffer, 
            player.y + player.height - collisionBuffer
        )
    elseif player.velX < 0 then  -- Movendo para esquerda
        tilesHorizontal = checkTilesAtPosition(
            futureX - 1, 
            futureX + collisionBuffer, 
            player.y + collisionBuffer, 
            player.y + player.height - collisionBuffer
        )
    end

    if not tilesHorizontal then
        player.x = futureX
    else
        -- Colisão suave com as paredes - evitar o "teleporte"
        if player.velX > 0 then
            -- Ajustar até a borda do tile, não além
            local tileX = math.floor((futureX + player.width) / map.tileSize) * map.tileSize
            player.x = tileX - player.width - 0.1 -- pequeno offset para evitar ficar preso
        else
            -- Ajustar até a borda do tile, não além
            local tileX = math.ceil(futureX / map.tileSize) * map.tileSize
            player.x = tileX + 0.1 -- pequeno offset para evitar ficar preso
        end
        player.velX = 0 -- parar o movimento ao colidir
    end
    
    -- Aplicar movimento vertical (com colisões)
    if not player.onGround then
        futureY = player.y + player.velY * dt
        local tilesAbove = checkTilesAtPosition(player.x + 5, player.x + player.width - 5, futureY)
        if tilesAbove and player.velY < 0 then
            player.y = math.ceil(futureY / map.tileSize) * map.tileSize
            player.velY = 0
        else
            player.y = futureY
        end
    end
    
    -- Atualizar animação
    updateAnimation(dt)
    
    -- Verificar se caiu para fora do mapa (void)
    if player.y > map.height * map.tileSize then
        playerDeath()
    end
    
    -- Verificar colisões com inimigos
    checkEnemyCollisions()
end

-- Função para verificar se há tiles nas coordenadas especificadas
function checkTilesAtPosition(x1, x2, y1, y2)
    if not y2 then y2 = y1 end
    
    local leftTile = math.floor(x1 / map.tileSize) + 1
    local rightTile = math.ceil(x2 / map.tileSize)
    local topTile = math.floor(y1 / map.tileSize) + 1
    local bottomTile = math.ceil(y2 / map.tileSize)
    
    -- Limitar os bounds da verificação para evitar índices inválidos
    leftTile = math.max(1, leftTile)
    rightTile = math.min(map.width, rightTile)
    topTile = math.max(1, topTile)
    bottomTile = math.min(map.height, bottomTile)
    
    for y = topTile, bottomTile do
        for x = leftTile, rightTile do
            if map.tiles[y][x] and map.tiles[y][x] > 0 then
                return true
            end
        end
    end
    
    return false
end

-- Função para atualizar a animação do jogador
function updateAnimation(dt)
    local anim = player.animations[player.currentAnimation]
    if anim then
        -- Incrementar o timer de animação
        player.animTimer = player.animTimer + dt * anim.speed
        
        -- Calcular o frame atual
        player.frame = math.floor(player.animTimer % anim.frameCount) + 1
        
        -- Reset se necessário
        if player.frame > anim.frameCount then
            player.frame = 1
            player.animTimer = 0
        end
    end
end

-- Função para atualizar inimigos
function updateEnemies(dt)
    for i, enemy in ipairs(enemies) do
        -- Movimento controlado dentro da plataforma
        enemy.x = enemy.x + enemy.speed * enemy.direction * dt
        
        -- Verificar limites da plataforma
        if enemy.x <= enemy.platformStart then
            enemy.x = enemy.platformStart
            enemy.direction = 1
        elseif enemy.x + enemy.width >= enemy.platformEnd then
            enemy.x = enemy.platformEnd - enemy.width
            enemy.direction = -1
        end
        
        -- Verificar colisões com o cenário para maior robustez
        local frontTileX = (enemy.direction > 0) and 
            math.ceil((enemy.x + enemy.width) / map.tileSize) or 
            math.floor(enemy.x / map.tileSize) + 1
        local bodyTileY = math.floor(enemy.y / map.tileSize) + 1
        
        if frontTileX >= 1 and frontTileX <= map.width and bodyTileY >= 1 and bodyTileY <= map.height then
            if map.tiles[bodyTileY][frontTileX] and map.tiles[bodyTileY][frontTileX] > 0 then
                enemy.direction = -enemy.direction
            end
        end
        
        -- Verificar se tem chão para andar
        local floorTileX = math.floor((enemy.x + enemy.width/2) / map.tileSize) + 1
        local floorTileY = math.floor((enemy.y + enemy.height + 2) / map.tileSize) + 1
        
        if floorTileY <= map.height and (floorTileX < 1 or floorTileX > map.width or
           not map.tiles[floorTileY][floorTileX] or map.tiles[floorTileY][floorTileX] == 0) then
            -- Tentar corrigir a posição
            enemy.direction = -enemy.direction
        end
    end
end

-- Função para verificar colisões com inimigos
function checkEnemyCollisions()
    -- Não verificar colisões se o jogador estiver invulnerável ou morto
    if player.invulnerable or player.deathState then return end
    
    for i, enemy in ipairs(enemies) do
        if intersect(player, enemy) then
            -- Verificar se o jogador está caindo sobre o inimigo
            if player.velY > 0 and player.y + player.height < enemy.y + enemy.height / 2 then
                -- Eliminar inimigo
                table.remove(enemies, i)
                player.velY = -player.jumpForce * 0.6  -- pequeno salto após derrotar inimigo
            else
                -- Jogador é atingido
                playerHurt()
                break
            end
        end
    end
end

-- Função para quando o jogador leva dano
function playerHurt()
    player.lives = player.lives - 1
    player.invulnerable = true
    player.invulnerableTimer = 0
    player.hurtState = true
    player.hurtTimer = 0
    player.velY = -player.jumpForce * 0.5  -- pequeno knockback vertical
    
    if player.lives <= 0 then
        playerDeath()
    else
        print("Jogador atingido! Vidas restantes: " .. player.lives)
    end
end

-- Função para morte do jogador
function playerDeath()
    player.lives = 0
    player.deathState = true
    player.deathTimer = 0
    player.currentAnimation = "death"
    print("Jogador morreu!")
end

-- Função para resetar o jogador
function resetPlayer()
    -- Posicione o jogador no início do mapa
    player.x = 150
    player.y = (map.height - 3) * map.tileSize - player.height
    player.velX = 0
    player.velY = 0
    player.lives = 3
    player.invulnerable = false
    player.invulnerableTimer = 0
    player.hurtState = false
    player.hurtTimer = 0
    player.deathState = false
    player.deathTimer = 0
    player.currentAnimation = "idle"
    
    -- Reiniciar inimigos
    spawnEnemies()
    
    -- Imprimir a posição do jogador para debugging
    print("Jogador resetado para posição: " .. player.x .. ", " .. player.y)
end

-- Função para detectar interseção entre dois retângulos
function intersect(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

-- Função para atualizar a câmera
function updateCamera()
    -- Fazer a câmera seguir o jogador
    map.viewX = player.x - love.graphics.getWidth() / 2
    map.viewY = player.y - love.graphics.getHeight() / 2
    
    -- Limitar a câmera ao mapa
    if map.viewX < 0 then map.viewX = 0 end
    if map.viewY < 0 then map.viewY = 0 end
    if map.viewX > map.width * map.tileSize - love.graphics.getWidth() then
        map.viewX = map.width * map.tileSize - love.graphics.getWidth()
    end
    if map.viewY > map.height * map.tileSize - love.graphics.getHeight() then
        map.viewY = map.height * map.tileSize - love.graphics.getHeight()
    end
end

-- Renderização do jogo
function love.draw()
    if gameState == "menu" then
        drawParallaxBackground(0.2) -- Movimento lento no menu
        drawMenu()
    elseif gameState == "jogo" then
        drawGame()
    elseif gameState == "config" then
        drawParallaxBackground(0.1) -- Movimento muito lento nas configurações
        drawConfig()
    end
end

-- Função para desenhar o fundo em paralaxe
function drawParallaxBackground(timeMultiplier)
    -- Se não temos camadas de fundo, desenhar um fundo simples
    if #parallaxLayers == 0 then
        love.graphics.setColor(0.2, 0.4, 0.8)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        return
    end
    
    -- Definir offset base para cada camada quando estamos jogando
    local baseOffsetX = 0
    if gameState == "jogo" then
        baseOffsetX = map.viewX
    else
        -- No menu ou configurações, fazer uma animação suave
        baseOffsetX = love.timer.getTime() * 50 * timeMultiplier
    end
    
    -- Desenhar cada camada com deslocamento proporcional à sua velocidade
    for i, layer in ipairs(parallaxLayers) do
        love.graphics.setColor(1, 1, 1)
        
        -- Calcular o deslocamento da camada
        local offsetX = baseOffsetX * layer.speed
        
        -- Normalizar o deslocamento para que seja repetitivo
        offsetX = offsetX % layer.width
        
        -- Desenhar a camada (possivelmente duas vezes para tela cheia)
        love.graphics.draw(layer.image, -offsetX, 0, 0, parallaxScale, parallaxScale)
        
        -- Se o offset criou um espaço vazio à direita, desenhar uma segunda instância
        if offsetX > 0 then
            love.graphics.draw(layer.image, layer.width * parallaxScale - offsetX, 0, 0, parallaxScale, parallaxScale)
        end
    end
end

-- Desenhar a interface do menu principal
function drawMenu()
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Jogo Urbano", 0, 80, love.graphics.getWidth(), "center")
    love.graphics.setFont(fontMenu)
    for i, option in ipairs(menuOptions) do
        if i == selectedOption then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, 0, 200 + i * 40, love.graphics.getWidth(), "center")
    end
end

-- Desenhar a tela de configurações
function drawConfig()
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Configurações", 0, 80, love.graphics.getWidth(), "center")
    love.graphics.setFont(fontMenu)
    love.graphics.printf("Volume: " .. math.floor(volume * 100) .. "%", 0, 250, love.graphics.getWidth(), "center")
    love.graphics.printf("← → para ajustar, Esc para voltar", 0, 300, love.graphics.getWidth(), "center")
end

-- Desenhar o jogo em si
function drawGame()
    -- Ajustar a câmera
    love.graphics.push()
    love.graphics.translate(-math.floor(map.viewX), -math.floor(map.viewY))
    
    -- Desenhar o fundo em paralaxe
    drawGameBackground()
    
    -- Desenhar mapa
    drawMap()
    
    -- Desenhar inimigos
    drawEnemies()
    
    -- Desenhar jogador
    drawPlayer()
    
    -- Restaurar transformação
    love.graphics.pop()
    
    -- Desenhar HUD (interface do usuário durante o jogo)
    drawHUD()
    
    -- Desenhar tela de Game Over se aplicável
    if gameOver then
        drawGameOver()
    end
    
    -- Adicionar informações de debug
    drawDebugInfo()
end

-- Desenhar o fundo do jogo (sem ser afetado pelo translate)
function drawGameBackground()
    -- Resetar a posição da transformação para desenhar o fundo
    love.graphics.pop()
    
    -- Desenhar o fundo em paralaxe
    drawParallaxBackground(1.0)
    
    -- Reiniciar a transformação para o resto da cena
    love.graphics.push()
    love.graphics.translate(-math.floor(map.viewX), -math.floor(map.viewY))
end

-- Continuação do arquivo main.lua

-- Desenhar a tela de Game Over
function drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 40, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(fontMenu)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Voltando ao menu em " .. math.ceil(3 - gameOverTimer) .. "...", 
                         0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
end

-- Desenhar o mapa
function drawMap()
    -- Calcular quais tiles são visíveis
    local startX = math.floor(map.viewX / map.tileSize) + 1
    local endX = math.ceil((map.viewX + love.graphics.getWidth()) / map.tileSize)
    local startY = math.floor(map.viewY / map.tileSize) + 1
    local endY = math.ceil((map.viewY + love.graphics.getHeight()) / map.tileSize)
    
    -- Limitar às dimensões do mapa
    startX = math.max(1, startX)
    endX = math.min(map.width, endX)
    startY = math.max(1, startY)
    endY = math.min(map.height, endY)
    
    -- Desenhar apenas os tiles visíveis
    for y = startY, endY do
        for x = startX, endX do
            if map.tiles[y][x] and map.tiles[y][x] > 0 then
                -- Escolher cor com base no tipo de tile
                if map.tiles[y][x] == 1 then
                    love.graphics.setColor(0.6, 0.6, 0.6)  -- Cinza para blocos padrão
                else
                    love.graphics.setColor(0.4, 0.4, 0.4)  -- Cinza escuro para outros tipos
                end
                
                love.graphics.rectangle("fill", 
                                      (x - 1) * map.tileSize, 
                                      (y - 1) * map.tileSize, 
                                      map.tileSize, 
                                      map.tileSize)
                
                -- Adicionar bordas para melhor visualização
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("line", 
                                      (x - 1) * map.tileSize, 
                                      (y - 1) * map.tileSize, 
                                      map.tileSize, 
                                      map.tileSize)
            end
        end
    end
end

-- Desenhar os inimigos
function drawEnemies()
    for _, enemy in ipairs(enemies) do
        -- Desenhar apenas inimigos visíveis na tela
        if isOnScreen(enemy.x, enemy.y, enemy.width, enemy.height) then
            -- Cor vermelha para inimigos básicos
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
            
            -- Olhos do inimigo para indicar direção
            love.graphics.setColor(1, 1, 1)
            local eyeX = enemy.x + (enemy.direction > 0 and 20 or 5)
            love.graphics.rectangle("fill", eyeX, enemy.y + 8, 8, 8)
            
            -- Contorno
            love.graphics.setColor(0.5, 0, 0)
            love.graphics.rectangle("line", enemy.x, enemy.y, enemy.width, enemy.height)
        end
    end
end

-- Desenhar o jogador
function drawPlayer()
    -- Definir a cor base (para backup se não houver sprites)
    if player.hurtState then
        love.graphics.setColor(1, 0.3, 0.3)  -- Vermelho claro quando ferido
    elseif player.invulnerable then
        -- Piscar quando invulnerável
        local alpha = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 10))
        love.graphics.setColor(player.color[1], player.color[2], player.color[3], alpha)
    else
        love.graphics.setColor(player.color)
    end
    
    -- Desenhar o jogador usando sprites se disponíveis
    if player.spriteSheet then
        love.graphics.setColor(1, 1, 1)  -- Reset para branco para sprites
        
        -- Se invulnerável, aplicar efeito de transparência
        if player.invulnerable and not player.hurtState then
            local alpha = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 10))
            love.graphics.setColor(1, 1, 1, alpha)
        end
        
        -- Obter o frame atual da animação
        local anim = player.animations[player.currentAnimation]
        local quad = anim.frames[player.frame]
        
        -- Desenhar a sprite virada para a direção correta
        local scaleX = (player.direction == "left") and -1 or 1
        local offsetX = (player.direction == "left") and player.width or 0
        
        love.graphics.draw(player.spriteSheet, quad, player.x + offsetX, player.y, 0, scaleX, 1)
    else
        -- Fallback para retângulo colorido se não houver sprites
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        
        -- Olhos para indicar direção
        love.graphics.setColor(1, 1, 1)
        local eyeX = player.x + (player.direction == "right" and player.width - 15 or 5)
        love.graphics.rectangle("fill", eyeX, player.y + 10, 10, 5)
    end
end

-- Desenhar a interface do usuário (HUD)
function drawHUD()
    love.graphics.setFont(fontMenu)
    
    -- Desenhar contador de vidas
    love.graphics.setColor(1, 0, 0)
    for i = 1, player.lives do
        love.graphics.rectangle("fill", (i-1) * 30 + 10, 10, 20, 20)
    end
    
    -- Mostrar pontuação ou outros dados relevantes
    love.graphics.setColor(1, 1, 1)
    local posText = "POS: " .. math.floor(player.x) .. "," .. math.floor(player.y)
    love.graphics.print(posText, 10, 40)
    
    -- Mostrar instruções básicas
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("← → para mover, SPACE para pular, ESC para menu", 10, love.graphics.getHeight() - 30)
end

-- Função para verificar se um objeto está visível na tela
function isOnScreen(x, y, width, height)
    return x + width > map.viewX and 
           x < map.viewX + love.graphics.getWidth() and
           y + height > map.viewY and
           y < map.viewY + love.graphics.getHeight()
end

-- Informações de debug (remover na versão final)
function drawDebugInfo()
    if love.keyboard.isDown("f1") then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 10, 70, 200, 100)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 80)
        love.graphics.print("Jogador: " .. player.x .. ", " .. player.y, 20, 100)
        love.graphics.print("Câmera: " .. map.viewX .. ", " .. map.viewY, 20, 120)
        love.graphics.print("Inimigos: " .. #enemies, 20, 140)
    end
end

-- Verificar teclado para menu e configurações
function love.keypressed(key)
    if gameState == "menu" then
        -- Controles do menu
        if key == "up" then
            selectedOption = selectedOption - 1
            if selectedOption < 1 then selectedOption = #menuOptions end
        elseif key == "down" then
            selectedOption = selectedOption + 1
            if selectedOption > #menuOptions then selectedOption = 1 end
        elseif key == "return" or key == "space" then
            handleMenuSelection()
        end
    elseif gameState == "jogo" then
        -- Controles durante o jogo
        if key == "escape" then
            gameState = "menu"
        elseif key == "space" and player.onGround and not player.hurtState then
            -- Pular (o movimento é tratado em updatePlayer)
        elseif key == "r" then
            -- Tecla de reinício rápido
            resetPlayer()
        end
    elseif gameState == "config" then
        -- Controles de configuração
        if key == "escape" then
            gameState = "menu"
        elseif key == "left" then
            volume = math.max(0, volume - 0.1)
            love.audio.setVolume(volume)
        elseif key == "right" then
            volume = math.min(1, volume + 0.1)
            love.audio.setVolume(volume)
        end
    end
end

-- Lidar com a seleção do menu
function handleMenuSelection()
    if selectedOption == 1 then
        -- Iniciar jogo
        gameState = "jogo"
        resetPlayer()
    elseif selectedOption == 2 then
        -- Configurações
        gameState = "config"
    elseif selectedOption == 3 then
        -- Sair
        love.event.quit()
    end
end

-- Melhorar a detecção de plataformas
function checkPlatformBelow()
    -- Verificar se há uma plataforma abaixo do jogador
    local tileY = math.floor((player.y + player.height + 1) / map.tileSize) + 1
    local tileX1 = math.floor((player.x + 5) / map.tileSize) + 1
    local tileX2 = math.floor((player.x + player.width - 5) / map.tileSize) + 1
    
    for x = tileX1, tileX2 do
        if x >= 1 and x <= map.width and tileY >= 1 and tileY <= map.height then
            if map.tiles[tileY][x] and map.tiles[tileY][x] > 0 then
                return true
            end
        end
    end
    
    return false
end

-- Ajustar a posição do jogador acima da plataforma corretamente
function adjustPlayerOnPlatform(tileY)
    player.y = (tileY - 1) * map.tileSize - player.height
    player.velY = 0
    player.onGround = true
end

-- Verificar se o jogador completou o nível (pode ser expandido no futuro)
function checkLevelCompletion()
    -- Por exemplo, se o jogador chegou ao final do mapa
    if player.x >= (map.width - 5) * map.tileSize then
        -- Implementar lógica de conclusão de nível
        -- Por enquanto, apenas retorna ao menu com mensagem
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(0, 1, 0)
        love.graphics.printf("NÍVEL COMPLETO!", 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        
        -- Após alguns segundos, voltar ao menu
        -- Isso pode ser implementado com um timer similar ao gameOverTimer
    end
end