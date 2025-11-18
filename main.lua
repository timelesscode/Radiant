-- ASTRAL ASCENDANT - Space Shooter Prototype
-- A roguelike bullet hell with narrative progression
-- Inspired by Radiant Silvergun + Ikaruga

-- ==============================================
-- CORE SYSTEMS - Reusable Architecture
-- ==============================================

-- Entity System
local Entity = {}
Entity.__index = Entity

function Entity:new(x, y, type)
    local e = {
        x = x, y = y,
        vx = 0, vy = 0,
        type = type,
        alive = true,
        radius = 8,
        color = {1, 1, 1},
        hp = 1,
        maxHp = 3,
        polarity = "blue", -- blue or red
        timer = 0,
        angle = 0,
        damage = 1
    }
    setmetatable(e, self)
    return e
end

function Entity:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.timer = self.timer + dt
end

function Entity:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
end

-- Game State Manager
local GameState = {
    current = "menu", -- menu, game, dialogue, upgrade, gameover
    states = {}
}

function GameState:switch(state)
    if self.states[self.current] and self.states[self.current].exit then
        self.states[self.current].exit()
    end
    self.current = state
    if self.states[state] and self.states[state].enter then
        self.states[state].enter()
    end
end

-- ==============================================
-- GAME DATA & PROGRESSION
-- ==============================================

local Player = {
    ship = nil,
    level = 1,
    exp = 0,
    expToNext = 100,
    score = 0,
    chain = 0,
    maxChain = 0,
    polarity = "blue",
    weapons = {
        spread = {level = 1, unlocked = true},
        laser = {level = 0, unlocked = false},
        homing = {level = 0, unlocked = false}
    },
    stats = {
        speed = 200,
        fireRate = 0.15,
        damage = 1
    },
    upgrades = {
        maxHp = 3,
        shield = 0,
        polarityBonus = 1.5
    }
}

local GameData = {
    wave = 1,
    enemiesKilled = 0,
    totalScore = 0,
    runNumber = 1,
    dialogueIndex = 1
}

-- Bullet Pattern Library
local BulletPatterns = {}

function BulletPatterns.spiral(x, y, count, speed, offset)
    local bullets = {}
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + offset
        local b = Entity:new(x, y, "enemyBullet")
        b.vx = math.cos(angle) * speed
        b.vy = math.sin(angle) * speed
        b.radius = 4
        b.polarity = (i % 2 == 0) and "blue" or "red"
        b.color = b.polarity == "blue" and {0.3, 0.6, 1} or {1, 0.3, 0.3}
        table.insert(bullets, b)
    end
    return bullets
end

function BulletPatterns.aimed(x, y, targetX, targetY, speed, spread)
    local bullets = {}
    spread = spread or 1
    for i = 1, spread do
        local angle = math.atan2(targetY - y, targetX - x) + (i - spread/2 - 0.5) * 0.3
        local b = Entity:new(x, y, "enemyBullet")
        b.vx = math.cos(angle) * speed
        b.vy = math.sin(angle) * speed
        b.radius = 4
        b.polarity = (i % 2 == 0) and "blue" or "red"
        b.color = b.polarity == "blue" and {0.3, 0.6, 1} or {1, 0.3, 0.3}
        table.insert(bullets, b)
    end
    return bullets
end

function BulletPatterns.wave(x, y, direction, speed)
    local bullets = {}
    for i = 1, 5 do
        local b = Entity:new(x, y, "enemyBullet")
        local angle = direction + math.sin(i * 0.5) * 0.5
        b.vx = math.cos(angle) * speed
        b.vy = math.sin(angle) * speed
        b.radius = 4
        b.polarity = (i % 2 == 0) and "blue" or "red"
        b.color = b.polarity == "blue" and {0.3, 0.6, 1} or {1, 0.3, 0.3}
        table.insert(bullets, b)
    end
    return bullets
end

-- ==============================================
-- DIALOGUE SYSTEM
-- ==============================================

local DialogueSystem = {
    dialogues = {
        {
            speaker = "PILOT",
            text = "Systems online. First wave detected ahead.",
            choices = {
                {text = "Engage weapons", action = "start"},
                {text = "Upgrade ship first", action = "upgrade"}
            }
        },
        {
            speaker = "AI CORE",
            text = "Wave cleared. Enhanced polarity matrix available.",
            choices = {
                {text = "Install upgrade", action = "upgrade"},
                {text = "Continue assault", action = "start"}
            }
        },
        {
            speaker = "COMMANDER",
            text = "You're adapting well. The enemy grows stronger...",
            choices = {
                {text = "I'm ready", action = "start"}
            }
        }
    },
    current = nil,
    selectedChoice = 1
}

function DialogueSystem:show(index)
    self.current = self.dialogues[index] or self.dialogues[1]
    self.selectedChoice = 1
    GameState:switch("dialogue")
end

-- ==============================================
-- UPGRADE SYSTEM
-- ==============================================

local UpgradeSystem = {
    availableUpgrades = {},
    selectedIndex = 1
}

function UpgradeSystem:generate()
    self.availableUpgrades = {
        {
            name = "Speed Boost",
            desc = "+20% movement speed",
            cost = 50,
            apply = function()
                Player.stats.speed = Player.stats.speed * 1.2
            end
        },
        {
            name = "Fire Rate",
            desc = "Faster shooting",
            cost = 75,
            apply = function()
                Player.stats.fireRate = Player.stats.fireRate * 0.85
            end
        },
        {
            name = "Max HP +1",
            desc = "Increase durability",
            cost = 100,
            apply = function()
                Player.upgrades.maxHp = Player.upgrades.maxHp + 1
                Player.ship.maxHp = Player.upgrades.maxHp
                Player.ship.hp = Player.ship.maxHp
            end
        },
        {
            name = "Unlock Laser",
            desc = "Piercing beam weapon",
            cost = 150,
            apply = function()
                Player.weapons.laser.unlocked = true
                Player.weapons.laser.level = 1
            end
        }
    }
    self.selectedIndex = 1
end

-- ==============================================
-- PARTICLE SYSTEM
-- ==============================================

local Particles = {}

function Particles:add(x, y, color, count)
    count = count or 8
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local speed = love.math.random(50, 150)
        local p = {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.5,
            maxLife = 0.5,
            color = color or {1, 1, 1},
            size = love.math.random(2, 4)
        }
        table.insert(self, p)
    end
end

function Particles:update(dt)
    for i = #self, 1, -1 do
        local p = self[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        p.vx = p.vx * 0.95
        p.vy = p.vy * 0.95
        if p.life <= 0 then
            table.remove(self, i)
        end
    end
end

function Particles:draw()
    for _, p in ipairs(self) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
end

-- ==============================================
-- GAME STATE IMPLEMENTATIONS
-- ==============================================

local Entities = {
    player = {},
    enemies = {},
    bullets = {},
    enemyBullets = {}
}

-- Menu State
GameState.states.menu = {
    enter = function()
        -- Initialize
    end,
    update = function(dt)
        if love.keyboard.isDown("space") then
            DialogueSystem:show(1)
        end
    end,
    draw = function()
        love.graphics.setColor(0.2, 0.5, 0.8)
        love.graphics.printf("ASTRAL ASCENDANT", 0, 200, 800, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("A Roguelike Bullet Hell", 0, 250, 800, "center")
        love.graphics.printf("Press SPACE to start", 0, 400, 800, "center")
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Arrow Keys: Move | Z: Shoot | X: Switch Polarity", 0, 500, 800, "center")
    end
}

-- Dialogue State
GameState.states.dialogue = {
    update = function(dt)
        -- Handle choice selection
    end,
    draw = function()
        local d = DialogueSystem.current
        if not d then return end
        
        -- Dialogue box
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 50, 450, 700, 130)
        
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.printf(d.speaker, 60, 460, 680, "left")
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(d.text, 60, 490, 680, "left")
        
        -- Choices
        for i, choice in ipairs(d.choices) do
            local y = 550 + (i - 1) * 25
            if i == DialogueSystem.selectedChoice then
                love.graphics.setColor(1, 1, 0)
                love.graphics.print("> " .. choice.text, 70, y)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print("  " .. choice.text, 70, y)
            end
        end
    end,
    keypressed = function(key)
        local d = DialogueSystem.current
        if key == "down" then
            DialogueSystem.selectedChoice = math.min(DialogueSystem.selectedChoice + 1, #d.choices)
        elseif key == "up" then
            DialogueSystem.selectedChoice = math.max(DialogueSystem.selectedChoice - 1, 1)
        elseif key == "space" or key == "return" then
            local action = d.choices[DialogueSystem.selectedChoice].action
            if action == "start" then
                GameState:switch("game")
            elseif action == "upgrade" then
                UpgradeSystem:generate()
                GameState:switch("upgrade")
            end
        end
    end
}

-- Upgrade State
GameState.states.upgrade = {
    draw = function()
        love.graphics.setColor(0.1, 0.1, 0.2)
        love.graphics.rectangle("fill", 100, 100, 600, 400)
        
        love.graphics.setColor(0.3, 0.8, 0.9)
        love.graphics.printf("UPGRADE TERMINAL", 100, 120, 600, "center")
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Score: " .. Player.score, 120, 150, 560, "left")
        
        for i, upgrade in ipairs(UpgradeSystem.availableUpgrades) do
            local y = 200 + (i - 1) * 70
            local selected = i == UpgradeSystem.selectedIndex
            
            if selected then
                love.graphics.setColor(0.3, 0.3, 0.5)
                love.graphics.rectangle("fill", 110, y - 5, 580, 60)
            end
            
            love.graphics.setColor(selected and {1, 1, 0} or {1, 1, 1})
            love.graphics.print(upgrade.name .. " - " .. upgrade.cost .. " pts", 120, y)
            
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(upgrade.desc, 120, y + 20)
        end
        
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("SPACE: Purchase | ESC: Skip", 100, 520, 600, "center")
    end,
    keypressed = function(key)
        if key == "down" then
            UpgradeSystem.selectedIndex = math.min(UpgradeSystem.selectedIndex + 1, #UpgradeSystem.availableUpgrades)
        elseif key == "up" then
            UpgradeSystem.selectedIndex = math.max(UpgradeSystem.selectedIndex - 1, 1)
        elseif key == "space" then
            local upgrade = UpgradeSystem.availableUpgrades[UpgradeSystem.selectedIndex]
            if Player.score >= upgrade.cost then
                Player.score = Player.score - upgrade.cost
                upgrade.apply()
            end
        elseif key == "escape" then
            GameState:switch("game")
        end
    end
}

-- Game State
GameState.states.game = {
    shootTimer = 0,
    enemySpawnTimer = 0,
    
    enter = function()
        -- Create player
        Player.ship = Entity:new(400, 500, "player")
        Player.ship.radius = 12
        Player.ship.hp = Player.upgrades.maxHp
        Player.ship.maxHp = Player.upgrades.maxHp
        Player.ship.color = {0.3, 0.7, 1}
        Player.polarity = "blue"
        
        Entities.player = Player.ship
        Entities.enemies = {}
        Entities.bullets = {}
        Entities.enemyBullets = {}
    end,
    
    update = function(dt)
        local state = GameState.states.game
        
        -- Player movement
        local p = Player.ship
        if love.keyboard.isDown("left") then p.vx = -Player.stats.speed end
        if love.keyboard.isDown("right") then p.vx = Player.stats.speed end
        if love.keyboard.isDown("up") then p.vy = -Player.stats.speed end
        if love.keyboard.isDown("down") then p.vy = Player.stats.speed end
        
        p:update(dt)
        p.vx = p.vx * 0.8
        p.vy = p.vy * 0.8
        
        -- Keep player in bounds
        p.x = math.max(20, math.min(780, p.x))
        p.y = math.max(20, math.min(580, p.y))
        
        -- Shooting
        if love.keyboard.isDown("z") then
            state.shootTimer = state.shootTimer + dt
            if state.shootTimer >= Player.stats.fireRate then
                state.shootTimer = 0
                local b = Entity:new(p.x, p.y - 20, "playerBullet")
                b.vy = -400
                b.radius = 5
                b.color = Player.polarity == "blue" and {0.3, 0.8, 1} or {1, 0.3, 0.5}
                b.polarity = Player.polarity
                b.damage = Player.stats.damage
                table.insert(Entities.bullets, b)
            end
        end
        
        -- Enemy spawning
        state.enemySpawnTimer = state.enemySpawnTimer + dt
        if state.enemySpawnTimer > 2 then
            state.enemySpawnTimer = 0
            local e = Entity:new(love.math.random(100, 700), -20, "enemy")
            e.hp = 3 + GameData.wave
            e.maxHp = e.hp
            e.vy = 50
            e.radius = 15
            e.polarity = love.math.random() > 0.5 and "blue" or "red"
            e.color = e.polarity == "blue" and {0.4, 0.6, 1} or {1, 0.4, 0.4}
            e.shootTimer = 0
            table.insert(Entities.enemies, e)
        end
        
        -- Update enemies
        for i = #Entities.enemies, 1, -1 do
            local e = Entities.enemies[i]
            e:update(dt)
            e.shootTimer = e.shootTimer + dt
            
            -- Enemy shooting
            if e.shootTimer > 2 then
                e.shootTimer = 0
                local pattern = BulletPatterns.aimed(e.x, e.y, p.x, p.y, 150, 3)
                for _, b in ipairs(pattern) do
                    table.insert(Entities.enemyBullets, b)
                end
            end
            
            if e.y > 650 or e.hp <= 0 then
                if e.hp <= 0 then
                    Particles:add(e.x, e.y, e.color, 12)
                    Player.score = Player.score + 10
                    Player.chain = Player.chain + 1
                    GameData.enemiesKilled = GameData.enemiesKilled + 1
                end
                table.remove(Entities.enemies, i)
            end
        end
        
        -- Update bullets
        for i = #Entities.bullets, 1, -1 do
            local b = Entities.bullets[i]
            b:update(dt)
            if b.y < -10 then
                table.remove(Entities.bullets, i)
            end
        end
        
        for i = #Entities.enemyBullets, 1, -1 do
            local b = Entities.enemyBullets[i]
            b:update(dt)
            if b.y > 610 or b.x < -10 or b.x > 810 then
                table.remove(Entities.enemyBullets, i)
            end
        end
        
        -- Collision detection
        for i = #Entities.bullets, 1, -1 do
            local b = Entities.bullets[i]
            for j = #Entities.enemies, 1, -1 do
                local e = Entities.enemies[j]
                local dist = math.sqrt((b.x - e.x)^2 + (b.y - e.y)^2)
                if dist < b.radius + e.radius then
                    local dmg = b.damage
                    if b.polarity == e.polarity then
                        dmg = dmg * Player.upgrades.polarityBonus
                    end
                    e.hp = e.hp - dmg
                    table.remove(Entities.bullets, i)
                    Particles:add(b.x, b.y, b.color, 4)
                    break
                end
            end
        end
        
        -- Player collision with enemy bullets
        for i = #Entities.enemyBullets, 1, -1 do
            local b = Entities.enemyBullets[i]
            local dist = math.sqrt((b.x - p.x)^2 + (b.y - p.y)^2)
            if dist < b.radius + p.radius then
                if b.polarity ~= Player.polarity then
                    p.hp = p.hp - 1
                    Particles:add(p.x, p.y, {1, 0.5, 0}, 8)
                    if p.hp <= 0 then
                        GameState:switch("gameover")
                    end
                else
                    Player.score = Player.score + 5
                end
                table.remove(Entities.enemyBullets, i)
            end
        end
        
        Particles:update(dt)
        
        -- Wave progression
        if GameData.enemiesKilled >= GameData.wave * 10 then
            GameData.wave = GameData.wave + 1
            DialogueSystem:show(math.min(GameData.wave, #DialogueSystem.dialogues))
        end
    end,
    
    draw = function()
        -- Background
        love.graphics.setColor(0.05, 0.05, 0.15)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        
        -- Draw entities
        if Entities.player.alive then
            love.graphics.setColor(Player.polarity == "blue" and {0.3, 0.7, 1} or {1, 0.3, 0.5})
            love.graphics.circle("fill", Entities.player.x, Entities.player.y, Entities.player.radius)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", Entities.player.x, Entities.player.y, Entities.player.radius + 3)
        end
        
        for _, e in ipairs(Entities.enemies) do
            e:draw()
            -- HP bar
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", e.x - 15, e.y - 25, 30, 3)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("fill", e.x - 15, e.y - 25, 30 * (e.hp / e.maxHp), 3)
        end
        
        for _, b in ipairs(Entities.bullets) do b:draw() end
        for _, b in ipairs(Entities.enemyBullets) do b:draw() end
        
        Particles:draw()
        
        -- UI
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("HP: " .. Player.ship.hp .. "/" .. Player.ship.maxHp, 10, 10)
        love.graphics.print("Score: " .. Player.score, 10, 30)
        love.graphics.print("Chain: " .. Player.chain, 10, 50)
        love.graphics.print("Wave: " .. GameData.wave, 10, 70)
        love.graphics.print("Polarity: " .. Player.polarity:upper(), 10, 90)
    end,
    
    keypressed = function(key)
        if key == "x" then
            Player.polarity = Player.polarity == "blue" and "red" or "blue"
        elseif key == "escape" then
            GameState:switch("menu")
        end
    end
}

-- Game Over State
GameState.states.gameover = {
    draw = function()
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER", 0, 250, 800, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Final Score: " .. Player.score, 0, 300, 800, "center")
        love.graphics.printf("Press SPACE to restart", 0, 350, 800, "center")
    end,
    keypressed = function(key)
        if key == "space" then
            GameState:switch("menu")
        end
    end
}

-- ==============================================
-- LOVE2D CALLBACKS
-- ==============================================

function love.load()
    love.window.setTitle("Astral Ascendant")
    love.window.setMode(800, 600)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2)
    math.randomseed(os.time())
end

function love.update(dt)
    local state = GameState.states[GameState.current]
    if state and state.update then
        state.update(dt)
    end
end

function love.draw()
    local state = GameState.states[GameState.current]
    if state and state.draw then
        state.draw()
    end
    
    -- Debug
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("State: " .. GameState.current, 700, 10)
end

function love.keypressed(key)
    local state = GameState.states[GameState.current]
    if state and state.keypressed then
        state.keypressed(key)
    end
end