-- Arquivo: main.lua

-- Variáveis Globais..
local background = {}
local fontTitle
local fontMenu
local menuOptions = {"Iniciar Jogo", "Configurações", "Sair"}
local selectedOption = 1
local gameState = "menu"
local volume = 0.5  -- valor inicial (50%)

local debugMode = true


-- Fator de escala para tamanho do jogador e inimigos
local scaleFactor = 1.5

-- Variáveis do Jogador
local player = {
    x = 150,
    y = 300,
    width = 48 * scaleFactor,
    height = 48 * scaleFactor,
    speed = 200,
    jumpForce = 950 / scaleFactor,  -- Ajustado para o novo tamanho
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
    deathTimer = 0,        -- Temporizador para animação de morte
    score = 0
}

-- Variáveis do Mapa
local map = {
    tileSize = 32,
    tiles = {},
    width = 100,  -- largura do mapa em tiles
    height = 20,  -- altura do mapa em tiles
    viewX = 0,    -- posição da câmera
    viewY = 0,
    platformSprite = nil  -- Nova variável para a sprite da plataforma
}

-- Variáveis de Inimigos
local enemies = {}

-- Variáveis de Coletáveis
local collectibles = {}
local collectibleSprite = nil

-- Variáveis para Parallax
local parallaxLayers = {}
local parallaxScale = 0.8  -- Escala de exibição das camadas de fundo

-- Variáveis de Game Over
local gameOver = false
local gameOverTimer = 0

-- Variáveis para sprites e animações dos inimigos
local enemySprites = {
    idle = nil,
    walk = nil,
    animations = {
        idle = { frames = {}, frameCount = 4, speed = 5 },
        walk = { frames = {}, frameCount = 6, speed = 10 }
    }
}

-- Carregar recursos e inicializar o jogo
function love.load()
    love.window.setTitle("Jogo Maneiro")
    love.window.setMode(800, 600)
    love.graphics.setDefaultFilter("nearest", "nearest")  -- para pixels nítidos
    
    -- Carregar a sprite da plataforma
    local success, result = pcall(function()
        map.platformSprite = love.graphics.newImage("plataforma.png")  -- Substitua pelo nome da sua imagem
    end)

    if not success then
        print("Erro ao carregar a sprite da plataforma: " .. result)
    end

    -- Carregar outros recursos
    loadBackgrounds()
    
    fontTitle = love.graphics.newFont(40)
    fontMenu = love.graphics.newFont(24)
    
    -- Configurar áudio
    love.audio.setVolume(volume)
    
    -- Carregar sprites do jogador
    loadPlayerSprites()
    
    -- Carregar sprites dos inimigos
    loadEnemySprites()
    
    -- Inicializar mapa
    initializeMap()
    
    -- Inicializar inimigos
    spawnEnemies()
    
    collectibleSprite = love.graphics.newImage("coletavel.png") -- sua imagem de coletável
    spawnCollectibles()
    
    -- Certifique-se que o jogador esteja em uma posição visível e segura
    resetPlayer()
    
    -- Inicializar com o estado de menu
    gameState = "menu"
    
    print("Jogo inicializado. Estado atual: " .. gameState)
end

-- Função para carregar os fundos de parallax
function loadBackgrounds()
    local backgroundLayers = {
        "sky",
        "background",
        "city2",
        "houses1",
        "minishop & callbox",
        "road & lamps"
    }
    
    for i, layerName in ipairs(backgroundLayers) do
        local success, result = pcall(function()
            local img = love.graphics.newImage(layerName .. ".png")
            table.insert(parallaxLayers, {
                image = img,
                speed = 0.1 * i,  
                width = img:getWidth(),
                height = img:getHeight()
            })
            print("Camada de fundo carregada: " .. layerName)
        end)
        
        if not success then
            print("Erro ao carregar a camada " .. layerName .. ": " .. result)
        end
    end
    
    if #parallaxLayers == 0 then
        print("Nenhuma camada de fundo carregada. Usando cor sólida.")
    end
end

-- Função para carregar sprites do jogador
function loadPlayerSprites()
    local success, result = pcall(function()
        player.spriteSheet = love.graphics.newImage("player_sprites.png")
        
        player.animations = {
            idle = { frames = {}, frameCount = 4, speed = 5 },
            walk = { frames = {}, frameCount = 6, speed = 10 },
            jump = { frames = {}, frameCount = 1, speed = 1 },
            hurt = { frames = {}, frameCount = 1, speed = 1 },
            death = { frames = {}, frameCount = 3, speed = 1 }
        }
        
        for i = 0, player.animations.idle.frameCount - 1 do
            table.insert(player.animations.idle.frames, 
                love.graphics.newQuad(i * 48, 0, 48, 48, player.spriteSheet:getDimensions()))
        end

        for i = 0, player.animations.walk.frameCount - 1 do
            table.insert(player.animations.walk.frames, 
                love.graphics.newQuad(i * 48, 48, 48, 48, player.spriteSheet:getDimensions()))
        end
        
        player.animations.jump.frames = {love.graphics.newQuad(0, 96, 48, 48, player.spriteSheet:getDimensions())}
        player.animations.hurt.frames = {love.graphics.newQuad(48, 96, 48, 48, player.spriteSheet:getDimensions())}
        player.animations.death.frames = {love.graphics.newQuad(0, 144, 48, 48, player.spriteSheet:getDimensions())}
        
        print("Sprites do jogador carregadas com sucesso")
    end)
    
    if not success then
        print("Erro ao carregar sprites do jogador: " .. result)
        player.spriteSheet = nil
    end
end

-- Função para carregar sprites dos inimigos
function loadEnemySprites()
    local success, result = pcall(function()
        enemySprites.idle = love.graphics.newImage("enemy_idle.png")  -- Substitua pelo nome da sua imagem
        enemySprites.walk = love.graphics.newImage("enemy_walk.png")  -- Substitua pelo nome da sua imagem
        
        -- Carregar quadros de animação de idle
        for i = 0, enemySprites.animations.idle.frameCount - 1 do
            table.insert(enemySprites.animations.idle.frames, 
                love.graphics.newQuad(i * 48, 0, 48, 48, enemySprites.idle:getDimensions()))
        end
        
        -- Carregar quadros de animação de walk
        for i = 0, enemySprites.animations.walk.frameCount - 1 do
            table.insert(enemySprites.animations.walk.frames, 
                love.graphics.newQuad(i * 48, 0, 48, 48, enemySprites.walk:getDimensions()))
        end
        
        print("Sprites dos inimigos carregadas com sucesso")
    end)
    
    if not success then
        print("Erro ao carregar sprites dos inimigos: " .. result)
        enemySprites.idle = nil
        enemySprites.walk = nil
    end
end

-- Função para inicializar o mapa
-- Função para inicializar o mapa com plataformas maiores e menos numerosas
-- Função para inicializar o mapa com plataformas variadas após a posição 2027
function initializeMap()
    map.width = 170
    map.tiles = {}

    for y = 1, map.height do
        map.tiles[y] = {}
        for x = 1, map.width do
            -- Chão principal até a posição x=72 (2027px)
            if y == map.height - 1 then
                if x < 72 and ((x > 15 and x < 20) or (x > 40 and x < 45)) then
                    map.tiles[y][x] = 0
                elseif x >= 72 then
                    -- Segmentar o chão após x=72 em plataformas menores
                    if (x >= 74 and x <= 79) or 
                       (x >= 86 and x <= 91) or 
                       (x >= 98 and x <= 103) or 
                       (x >= 110 and x <= 115) or 
                       (x >= 122 and x <= 127) or 
                       (x >= 134 and x <= 139) or 
                       (x >= 146 and x <= 151) or 
                       (x >= 158 and x <= 163) then
                        map.tiles[y][x] = 1
                    else
                        map.tiles[y][x] = 0
                    end
                else
                    map.tiles[y][x] = 1
                end
            -- Plataforma de ajuda na posição ~1692 (x=53)
            elseif y == map.height - 4 and x >= 52 and x <= 56 then
                map.tiles[y][x] = 1

            -- Plataformas principais antes da área infinita
            elseif (y == map.height - 5 and x >= 10 and x <= 15) or    -- 1
                   (y == map.height - 6 and x >= 22 and x <= 27) or     -- 2
                   (y == map.height - 5 and x >= 34 and x <= 39) or     -- 3
                   (y == map.height - 7 and x >= 46 and x <= 51) or     -- 4
                   (y == map.height - 6 and x >= 58 and x <= 63) then   -- 5
                map.tiles[y][x] = 1

            -- Plataformas altas
            elseif (y == map.height - 9 and x >= 30 and x <= 33) or     -- Alta 1
                   (y == map.height - 10 and x >= 50 and x <= 53) then  -- Alta 2
                map.tiles[y][x] = 1
                
            -- Novas plataformas após a posição x=72 (2027px), seguindo o layout original
            elseif (y == map.height - 5 and x >= 74 and x <= 79) or     -- Nova 1
                   (y == map.height - 6 and x >= 86 and x <= 91) or     -- Nova 2
                   (y == map.height - 5 and x >= 98 and x <= 103) or    -- Nova 3
                   (y == map.height - 7 and x >= 110 and x <= 115) or   -- Nova 4
                   (y == map.height - 6 and x >= 122 and x <= 127) or   -- Nova 5
                   (y == map.height - 5 and x >= 134 and x <= 139) or   -- Nova 6
                   (y == map.height - 7 and x >= 146 and x <= 151) or   -- Nova 7
                   (y == map.height - 6 and x >= 158 and x <= 163) then -- Nova 8
                map.tiles[y][x] = 1
                
            -- Plataformas altas após a posição x=72 (2027px)
            elseif (y == map.height - 9 and x >= 90 and x <= 93) or     -- Nova Alta 1
                   (y == map.height - 10 and x >= 130 and x <= 133) then -- Nova Alta 2
                map.tiles[y][x] = 1
                
            -- Plataforma final pequena para transição
            elseif y == map.height - 3 and x >= 167 and x <= 170 then
                map.tiles[y][x] = 1
                
            else
                map.tiles[y][x] = 0
            end
        end
    end

    -- Plataforma inicial (spawn)
    for x = 3, 8 do
        map.tiles[map.height - 2][x] = 1
    end

    -- Remoção correta da plataforma acima do spawn
    for x = 3, 8 do
        map.tiles[map.height - 3][x] = 0
    end
end

function spawnEnemies()
    enemies = {
        -- Inimigos nas plataformas principais (mantidos do código original)
        {x = 14 * map.tileSize, y = (map.height - 6) * map.tileSize - 48 * scaleFactor, platformStart = 12 * map.tileSize, platformEnd = 16 * map.tileSize},
        {x = 24 * map.tileSize, y = (map.height - 7) * map.tileSize - 48 * scaleFactor, platformStart = 22 * map.tileSize, platformEnd = 26 * map.tileSize},
        {x = 36 * map.tileSize, y = (map.height - 6) * map.tileSize - 48 * scaleFactor, platformStart = 34 * map.tileSize, platformEnd = 38 * map.tileSize},
        {x = 48 * map.tileSize, y = (map.height - 8) * map.tileSize - 48 * scaleFactor, platformStart = 46 * map.tileSize, platformEnd = 50 * map.tileSize},
        {x = 60 * map.tileSize, y = (map.height - 7) * map.tileSize - 48 * scaleFactor, platformStart = 58 * map.tileSize, platformEnd = 62 * map.tileSize},
        
        -- Inimigos nas plataformas altas (mantidos do código original)
        {x = 32 * map.tileSize, y = (map.height - 10) * map.tileSize - 48 * scaleFactor, platformStart = 30 * map.tileSize, platformEnd = 34 * map.tileSize},
        {x = 52 * map.tileSize, y = (map.height - 11) * map.tileSize - 48 * scaleFactor, platformStart = 50 * map.tileSize, platformEnd = 54 * map.tileSize},
        
        -- Novos inimigos nas plataformas após 2027px (seguindo o padrão original)
        {x = 76 * map.tileSize, y = (map.height - 6) * map.tileSize - 48 * scaleFactor, platformStart = 74 * map.tileSize, platformEnd = 79 * map.tileSize},
        {x = 88 * map.tileSize, y = (map.height - 7) * map.tileSize - 48 * scaleFactor, platformStart = 86 * map.tileSize, platformEnd = 91 * map.tileSize},
        {x = 100 * map.tileSize, y = (map.height - 6) * map.tileSize - 48 * scaleFactor, platformStart = 98 * map.tileSize, platformEnd = 103 * map.tileSize},
        {x = 112 * map.tileSize, y = (map.height - 8) * map.tileSize - 48 * scaleFactor, platformStart = 110 * map.tileSize, platformEnd = 115 * map.tileSize},
        {x = 124 * map.tileSize, y = (map.height - 7) * map.tileSize - 48 * scaleFactor, platformStart = 122 * map.tileSize, platformEnd = 127 * map.tileSize},
        {x = 136 * map.tileSize, y = (map.height - 6) * map.tileSize - 48 * scaleFactor, platformStart = 134 * map.tileSize, platformEnd = 139 * map.tileSize},
        {x = 148 * map.tileSize, y = (map.height - 8) * map.tileSize - 48 * scaleFactor, platformStart = 146 * map.tileSize, platformEnd = 151 * map.tileSize},
        {x = 160 * map.tileSize, y = (map.height - 7) * map.tileSize - 48 * scaleFactor, platformStart = 158 * map.tileSize, platformEnd = 163 * map.tileSize},
        
        -- Inimigos nas plataformas altas após 2027px
        {x = 92 * map.tileSize, y = (map.height - 10) * map.tileSize - 48 * scaleFactor, platformStart = 90 * map.tileSize, platformEnd = 94 * map.tileSize},
        {x = 132 * map.tileSize, y = (map.height - 11) * map.tileSize - 48 * scaleFactor, platformStart = 130 * map.tileSize, platformEnd = 134 * map.tileSize}
        
        -- Inimigo na plataforma final removido conforme solicitado
    }
    
    -- Configuração comum para todos inimigos
    for _, enemy in ipairs(enemies) do
        enemy.width = 48 * scaleFactor
        enemy.height = 48 * scaleFactor
        enemy.speed = 60  -- Velocidade aumentada
        enemy.direction = (math.random() < 0.5) and -1 or 1
        enemy.type = "basic"
        enemy.currentAnimation = "idle"
        enemy.animTimer = 0
        enemy.frame = 1
    end
end

function spawnCollectibles()
    collectibles = {
        -- Coletáveis em plataformas com inimigos (mantidos do código original)
        {x = 13 * map.tileSize, y = (map.height - 7) * map.tileSize - 32},  -- Plataforma 1
        {x = 25 * map.tileSize, y = (map.height - 8) * map.tileSize - 32},  -- Plataforma 2
        {x = 37 * map.tileSize, y = (map.height - 7) * map.tileSize - 32},  -- Plataforma 3
        {x = 49 * map.tileSize, y = (map.height - 9) * map.tileSize - 32},  -- Plataforma 4
        {x = 61 * map.tileSize, y = (map.height - 8) * map.tileSize - 32},  -- Plataforma 5
        {x = 31 * map.tileSize, y = (map.height - 11) * map.tileSize - 32}, -- Alta 1
        {x = 51 * map.tileSize, y = (map.height - 12) * map.tileSize - 32}, -- Alta 2
        
        -- Coletáveis em plataformas sem inimigos (mantidos do código original)
        {x = 20 * map.tileSize, y = (map.height - 6) * map.tileSize - 32},  -- Plataforma auxiliar
        {x = 55 * map.tileSize, y = (map.height - 5) * map.tileSize - 32},  -- Plataforma auxiliar
        
        -- Novos coletáveis nas plataformas após 2027px (seguindo o padrão original)
        {x = 77 * map.tileSize, y = (map.height - 7) * map.tileSize - 32},  -- Nova 1
        {x = 89 * map.tileSize, y = (map.height - 8) * map.tileSize - 32},  -- Nova 2
        {x = 101 * map.tileSize, y = (map.height - 7) * map.tileSize - 32}, -- Nova 3
        {x = 113 * map.tileSize, y = (map.height - 9) * map.tileSize - 32}, -- Nova 4
        {x = 125 * map.tileSize, y = (map.height - 8) * map.tileSize - 32}, -- Nova 5
        {x = 137 * map.tileSize, y = (map.height - 7) * map.tileSize - 32}, -- Nova 6
        {x = 149 * map.tileSize, y = (map.height - 9) * map.tileSize - 32}, -- Nova 7
        {x = 161 * map.tileSize, y = (map.height - 8) * map.tileSize - 32}, -- Nova 8
        
        -- Coletáveis nas plataformas altas após 2027px
        {x = 91 * map.tileSize, y = (map.height - 11) * map.tileSize - 32}, -- Nova Alta 1
        {x = 131 * map.tileSize, y = (map.height - 12) * map.tileSize - 32} -- Nova Alta 2
        
        -- Coletável na plataforma final removido conforme solicitado
    }
    
    -- Configuração comum para todos coletáveis
    for _, item in ipairs(collectibles) do
        item.width = 16
        item.height = 16
        item.collected = false
    end
end

-- Função para atualizar a lógica do jogo
-- Função para atualizar a lógica do jogo
function love.update(dt)
    if gameState == "jogo" then
        if gameOver then
            gameOverTimer = gameOverTimer + dt
            if gameOverTimer >= 3 then
                gameState = "menu"
                gameOver = false
                gameOverTimer = 0
            end
        else
            updatePlayer(dt)
            updateEnemies(dt)
            updateEnemyAnimations(dt)
            updateCamera()
        end
    end
end

-- Função para atualizar a posição e estado do jogador
-- Função para atualizar a posição e estado do jogador com colisão horizontal melhorada e suave
function updatePlayer(dt)
    if player.deathState then
        player.deathTimer = player.deathTimer + dt
        if player.deathTimer >= 2 then
            gameOver = true
            player.deathState = false
            player.deathTimer = 0
        end
        return
    end

    if player.invulnerable then
        player.invulnerableTimer = player.invulnerableTimer + dt
        if player.invulnerableTimer >= 1.5 then
            player.invulnerable = false
            player.invulnerableTimer = 0
        end
    end

    if player.hurtState then
        player.hurtTimer = player.hurtTimer + dt
        if player.hurtTimer >= 0.5 then
            player.hurtState = false
            player.hurtTimer = 0
        end
        player.currentAnimation = "hurt"
    else
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

        if not player.onGround then
            player.currentAnimation = "jump"
        end
    end

    player.velY = player.velY + player.gravity * dt
    player.onGround = false

    local futureY = player.y + player.velY * dt
    local wantsToDrop = love.keyboard.isDown("down")
    local bottomY = futureY + player.height
    local tileY = math.floor(bottomY / map.tileSize) + 1
    local tileX1 = math.floor((player.x + 5) / map.tileSize) + 1
    local tileX2 = math.floor((player.x + player.width - 5) / map.tileSize) + 1
    local landed = false

    if player.velY > 0 and not wantsToDrop then
        for x = tileX1, tileX2 do
            if x >= 1 and x <= map.width and tileY >= 1 and tileY <= map.height then
                if map.tiles[tileY][x] and map.tiles[tileY][x] > 0 then
                    local platformTop = (tileY - 1) * map.tileSize
                    -- Só colide se o jogador estiver acima da plataforma
                    if player.y + player.height <= platformTop + 5 then
                        player.y = platformTop - player.height
                        player.velY = 0
                        player.onGround = true
                        landed = true
                        break
                    end
                end
            end
        end
    end

    if not landed then
        player.y = futureY
    end

    -- Pulo
    if not player.hurtState and player.onGround and love.keyboard.isDown("space") then
        player.velY = -player.jumpForce
        player.currentAnimation = "jump"
    end

    -- Movimento horizontal (sem colisão lateral com plataformas)
    local futureX = player.x + player.velX * dt

    if futureX < 0 then
        futureX = 0
    elseif futureX + player.width > map.width * map.tileSize then
        futureX = map.width * map.tileSize - player.width
    end

    player.x = futureX

    updateAnimation(dt)

    if player.y > map.height * map.tileSize then
        playerDeath()
    end

    checkEnemyCollisions()
    checkCollectibleCollisions()
end


-- Função para atualizar animação dos inimigos
-- Função para atualizar animação dos inimigos
function updateEnemyAnimations(dt)
    for _, enemy in ipairs(enemies) do
        local anim = enemySprites.animations[enemy.currentAnimation]
        if anim then
            enemy.animTimer = enemy.animTimer + dt * anim.speed
            enemy.frame = math.floor(enemy.animTimer % anim.frameCount) + 1

            if enemy.frame > anim.frameCount then
                enemy.frame = 1
                enemy.animTimer = 0
            end
        end
        
        if enemy.speed * enemy.direction ~= 0 then
            enemy.currentAnimation = "walk"
        else
            enemy.currentAnimation = "idle"
        end
    end
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
-- Atualizar inimigos
-- Atualizar inimigos
function updateEnemies(dt)
    for i, enemy in ipairs(enemies) do
        enemy.x = enemy.x + enemy.speed * enemy.direction * dt
        
        if enemy.x <= enemy.platformStart then
            enemy.x = enemy.platformStart
            enemy.direction = 1
        elseif enemy.x + enemy.width >= enemy.platformEnd then
            enemy.x = enemy.platformEnd - enemy.width
            enemy.direction = -1
        end
        
        local frontTileX = (enemy.direction > 0) and 
            math.ceil((enemy.x + enemy.width) / map.tileSize) or 
            math.floor(enemy.x / map.tileSize) + 1
        local bodyTileY = math.floor(enemy.y / map.tileSize) + 1
        
        if frontTileX >= 1 and frontTileX <= map.width and bodyTileY >= 1 and bodyTileY <= map.height then
            if map.tiles[bodyTileY][frontTileX] and map.tiles[bodyTileY][frontTileX] > 0 then
                enemy.direction = -enemy.direction
            end
        end
        
        local floorTileX = math.floor((enemy.x + enemy.width/2) / map.tileSize) + 1
        local floorTileY = math.floor((enemy.y + enemy.height + 2) / map.tileSize) + 1
        
        if floorTileY <= map.height and (floorTileX < 1 or floorTileX > map.width or
           not map.tiles[floorTileY][floorTileX] or map.tiles[floorTileY][floorTileX] == 0) then
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
                player.score = player.score + 10
                print("Inimigo derrotado! Pontuação: " .. player.score)

            else
                -- Jogador é atingido
                playerHurt()
                break
            end
        end
    end
end

function checkCollectibleCollisions()
    for _, item in ipairs(collectibles) do
        if not item.collected then
            local itemBox = {x = item.x, y = item.y, width = 16, height = 16}
            if intersect(player, itemBox) then
                item.collected = true
                player.score = player.score + 10
                print("Pegou coletável! Score: " .. player.score)
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
    -- Posicione o jogador no início do mapa (centralizado na plataforma inicial)
    player.x = 3 * map.tileSize  -- Posiciona na primeira tile da plataforma inicial
    player.y = (map.height - 2) * map.tileSize - player.height  -- Em cima da plataforma inicial
    player.velX = 0
    player.velY = 0
    player.lives = 3
    player.invulnerable = false
    player.invulnerableTimer = 0
    player.hurtState = false
    player.score = 0
    player.hurtTimer = 0
    player.deathState = false
    player.deathTimer = 0
    player.currentAnimation = "idle"
    
    -- Reiniciar os coletáveis
    spawnCollectibles()
    
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
    love.graphics.printf("Save The Churrasco", 0, 80, love.graphics.getWidth(), "center")
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
    
    -- Desenhar coletáveis
    drawCollectibles()

    
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

    -- Desenhar plataformas como objetos contínuos
    for y = startY, endY do
        local platformStart = nil
        local platformWidth = 0
        
        for x = startX, endX + 1 do  -- +1 para garantir que processe o último tile
            -- Verificar se é um tile de plataforma
            local isTile = (x <= endX) and map.tiles[y][x] and map.tiles[y][x] == 1
            
            if isTile and platformStart == nil then
                -- Início de uma nova plataforma
                platformStart = x
                platformWidth = 1
            elseif isTile and platformStart ~= nil then
                -- Continuação da plataforma atual
                platformWidth = platformWidth + 1
            elseif not isTile and platformStart ~= nil then
                -- Fim da plataforma, desenhar como uma única unidade
                if map.platformSprite then
                    -- Calcular a posição e escala da plataforma
                    local px = (platformStart - 1) * map.tileSize
                    local py = (y - 1) * map.tileSize
                    local scaleX = (platformWidth * map.tileSize) / map.platformSprite:getWidth()
                    local scaleY = map.tileSize / map.platformSprite:getHeight()
                    
                    -- Desenhar a plataforma como uma única sprite esticada
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(map.platformSprite, px, py, 0, scaleX, scaleY)
                end
                
                -- Resetar para a próxima plataforma
                platformStart = nil
                platformWidth = 0
            end
        end
    end
    
    if debugMode then
      for y = startY, endY do
          for x = startX, endX do
              if map.tiles[y][x] == 1 then
                  local tileX = (x - 1) * map.tileSize
                  local tileY = (y - 1) * map.tileSize
                  love.graphics.setColor(0, 1, 0, 0.5) -- Verde com transparência
                  love.graphics.setLineWidth(2)
                  love.graphics.rectangle("line", tileX, tileY, map.tileSize, map.tileSize)
              end
          end
      end
    end
end

-- Desenhar os inimigos usando sprites
-- Função para desenhar os inimigos usando sprites
function drawEnemies()
    for _, enemy in ipairs(enemies) do
        if isOnScreen(enemy.x, enemy.y, enemy.width, enemy.height) then
            local animName = enemy.currentAnimation or "idle"
            local anim = enemySprites.animations[animName]
            local spriteSheet = enemySprites[animName]
            if anim and spriteSheet then
                local quad = anim.frames[enemy.frame]
                if quad then
                    local scaleX = enemy.direction == -1 and -1 or 1
                    local offsetX = enemy.direction == -1 and enemy.width or 0
                    
                    love.graphics.setColor(1,1,1)
                    love.graphics.draw(spriteSheet, quad, enemy.x + offsetX, enemy.y, 0, scaleX * scaleFactor, scaleFactor)

                    if debugMode then
                        love.graphics.setColor(1, 0, 0)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", enemy.x, enemy.y, enemy.width, enemy.height)
                    end
                end
            end
        end
    end
end

function drawCollectibles()
    for _, item in ipairs(collectibles) do
        if not item.collected and isOnScreen(item.x, item.y, 16, 16) then
            love.graphics.setColor(1, 1, 1)
            if collectibleSprite then
                love.graphics.draw(collectibleSprite, item.x, item.y)
            else
                love.graphics.setColor(1, 1, 0)
                love.graphics.rectangle("fill", item.x, item.y, 16, 16)
            end
        end
    end
end

-- Desenhar o jogador
-- Função para desenhar o jogador
function drawPlayer()
    if player.hurtState then
        love.graphics.setColor(1, 0.3, 0.3)
    elseif player.invulnerable then
        local alpha = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 10))
        love.graphics.setColor(player.color[1], player.color[2], player.color[3], alpha)
    else
        love.graphics.setColor(player.color)
    end
    
    if player.spriteSheet then
        love.graphics.setColor(1, 1, 1)
        
        if player.invulnerable and not player.hurtState then
            local alpha = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 10))
            love.graphics.setColor(1, 1, 1, alpha)
        end
        
        local anim = player.animations[player.currentAnimation]
        local quad = anim.frames[player.frame]
        
        local scaleX = (player.direction == "left") and -1 or 1
        local offsetX = (player.direction == "left") and player.width or 0
        
        love.graphics.draw(player.spriteSheet, quad, player.x + offsetX, player.y, 0, scaleX * scaleFactor, scaleFactor)
        if debugMode then
            love.graphics.setColor(0, 1, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", player.x, player.y, player.width, player.height)
        end
    else
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        -- Caixa de colisão do jogador (modo debug)
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
    
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Pontuação: " .. player.score, 10, 65)
    
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

function drawCollectibles()
    for _, item in ipairs(collectibles) do
        if not item.collected and isOnScreen(item.x, item.y, 16, 16) then
            if collectibleSprite then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(collectibleSprite, item.x, item.y)
            else
                love.graphics.setColor(1, 1, 0)
                love.graphics.rectangle("fill", item.x, item.y, 16, 16)
            end

            if debugMode then
                love.graphics.setColor(1, 0, 0)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", item.x, item.y, 16, 16)
            end
        end
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
            gameOver = false
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
    if key == "down" then
    -- Posição atual do jogador
      local jogadorBottom = player.y + player.height
      local colunaX1 = math.floor((player.x + 5) / map.tileSize) + 1
      local colunaX2 = math.floor((player.x + player.width - 5) / map.tileSize) + 1

      -- Encontra a próxima plataforma abaixo do jogador
      local plataformaMaisBaixa = nil

      for y = math.floor(jogadorBottom / map.tileSize) + 1, map.height do
          for x = colunaX1, colunaX2 do
              if map.tiles[y] and map.tiles[y][x] and map.tiles[y][x] > 0 then
                  plataformaMaisBaixa = y
                  break
              end
          end
          if plataformaMaisBaixa then break end
      end

    -- Verifica se há plataforma abaixo da atual
      if plataformaMaisBaixa then
          -- Só desce se NÃO estiver já nessa plataforma
          local yPlataforma = (plataformaMaisBaixa - 1) * map.tileSize
          if player.y + player.height <= yPlataforma then
              player.y = player.y + 5
              player.onGround = false
          else
              print("Já está na plataforma mais baixa.")
          end
      else
          print("Nenhuma plataforma abaixo. Não pode descer.")
      end
    end

    if key == "f2" then
      debugMode = not debugMode
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