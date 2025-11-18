-- ASTRAL ASCENDANT - Space Shooter Enhanced
-- Vampire Survivors auto-shoot + Ikaruga polarity + Radiant Silvergun patterns
-- Now with auto-targeting and power-up drops

-- ==============================================
-- ENTITY SYSTEM
-- ==============================================

local Entity = {}
Entity.__index = Entity

function Entity:new(x, y, type)
	local e = {
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		type = type,
		alive = true,
		radius = 8,
		color = { 1, 1, 1 },
		hp = 1,
		maxHp = 3,
		polarity = "blue",
		timer = 0,
		angle = 0,
		damage = 1,
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

-- ==============================================
-- GAME STATE MANAGER
-- ==============================================

local GameState = {
	current = "menu",
	states = {},
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
-- PLAYER DATA
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
	stats = {
		speed = 250,
		fireRate = 0.12,
		damage = 1,
		projectileSpeed = 450,
		range = 600,
	},
	upgrades = {
		maxHp = 3,
		autoAim = true,
		piercing = false,
		multiShot = 1,
		polarityBonus = 1.5,
	},
}

local GameData = {
	wave = 1,
	enemiesKilled = 0,
	totalScore = 0,
}

-- ==============================================
-- GAME ENTITIES
-- ==============================================

local Entities = {
	player = {},
	enemies = {},
	bullets = {},
	enemyBullets = {},
	powerups = {},
	exporbs = {},
	particles = {},
}

-- ==============================================
-- BULLET PATTERNS
-- ==============================================

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
		b.color = b.polarity == "blue" and { 0.3, 0.6, 1 } or { 1, 0.3, 0.3 }
		table.insert(bullets, b)
	end
	return bullets
end

function BulletPatterns.aimed(x, y, targetX, targetY, speed, spread)
	local bullets = {}
	spread = spread or 1
	for i = 1, spread do
		local angle = math.atan2(targetY - y, targetX - x) + (i - spread / 2 - 0.5) * 0.3
		local b = Entity:new(x, y, "enemyBullet")
		b.vx = math.cos(angle) * speed
		b.vy = math.sin(angle) * speed
		b.radius = 4
		b.polarity = (i % 2 == 0) and "blue" or "red"
		b.color = b.polarity == "blue" and { 0.3, 0.6, 1 } or { 1, 0.3, 0.3 }
		table.insert(bullets, b)
	end
	return bullets
end

-- ==============================================
-- POWER-UP FUNCTIONS
-- ==============================================

local function spawnPowerUp(x, y, ptype)
	local types = {"health", "damage", "speed", "firerate", "multishot"}
	local weights = {30, 25, 20, 15, 10}
	
	-- Random type selection if not specified
	if not ptype then
		local total = 0
		for _, w in ipairs(weights) do
			total = total + w
		end
		
		local roll = love.math.random() * total
		local sum = 0
		for i, w in ipairs(weights) do
			sum = sum + w
			if roll <= sum then
				ptype = types[i]
				break
			end
		end
	end
	
	local powerup = {
		x = x,
		y = y,
		type = ptype,
		radius = 10,
		timer = 0,
		lifetime = 10,
		magnetRange = 120,
	}
	
	if powerup.type == "health" then
		powerup.color = {0, 1, 0.3}
		powerup.effect = function()
			Player.ship.hp = math.min(Player.ship.hp + 1, Player.ship.maxHp)
		end
	elseif powerup.type == "damage" then
		powerup.color = {1, 0.5, 0}
		powerup.effect = function()
			Player.stats.damage = Player.stats.damage + 0.5
		end
	elseif powerup.type == "speed" then
		powerup.color = {0.5, 1, 1}
		powerup.effect = function()
			Player.stats.speed = Player.stats.speed + 20
		end
	elseif powerup.type == "firerate" then
		powerup.color = {1, 1, 0}
		powerup.effect = function()
			Player.stats.fireRate = Player.stats.fireRate * 0.9
		end
	elseif powerup.type == "multishot" then
		powerup.color = {1, 0, 1}
		powerup.effect = function()
			Player.upgrades.multiShot = Player.upgrades.multiShot + 1
		end
	end
	
	table.insert(Entities.powerups, powerup)
end

local function updatePowerUps(dt)
	for i = #Entities.powerups, 1, -1 do
		local p = Entities.powerups[i]
		p.timer = p.timer + dt
		
		if p.timer >= p.lifetime then
			table.remove(Entities.powerups, i)
		else
			local dx = Player.ship.x - p.x
			local dy = Player.ship.y - p.y
			local dist = math.sqrt(dx * dx + dy * dy)
			
			if dist < p.magnetRange then
				local pullSpeed = 200
				p.x = p.x + (dx / dist) * pullSpeed * dt
				p.y = p.y + (dy / dist) * pullSpeed * dt
			end
			
			if dist < Player.ship.radius + p.radius then
				p.effect()
				table.remove(Entities.powerups, i)
				spawnParticles(p.x, p.y, p.color, 10)
			end
		end
	end
end

local function drawPowerUps()
	for _, p in ipairs(Entities.powerups) do
		local pulse = 1 + math.sin(p.timer * 8) * 0.2
		love.graphics.setColor(p.color)
		love.graphics.circle("fill", p.x, p.y, p.radius * pulse)
		love.graphics.setColor(1, 1, 1)
		love.graphics.circle("line", p.x, p.y, p.radius * pulse + 2)
		
		if p.timer > p.lifetime - 2 then
			local alpha = math.abs(math.sin(p.timer * 10))
			love.graphics.setColor(1, 1, 1, alpha)
			love.graphics.circle("line", p.x, p.y, p.radius + 5)
		end
	end
end

-- ==============================================
-- EXPERIENCE ORB FUNCTIONS
-- ==============================================

local function spawnExpOrb(x, y, value)
	value = value or 10
	local orb = {
		x = x,
		y = y,
		value = value,
		radius = 5 + (value / 20),
		timer = 0,
		magnetRange = 150,
	}
	table.insert(Entities.exporbs, orb)
end

local function updateExpOrbs(dt)
	for i = #Entities.exporbs, 1, -1 do
		local orb = Entities.exporbs[i]
		orb.timer = orb.timer + dt
		
		local dx = Player.ship.x - orb.x
		local dy = Player.ship.y - orb.y
		local dist = math.sqrt(dx * dx + dy * dy)
		
		if dist < orb.magnetRange then
			local pullSpeed = 300
			orb.x = orb.x + (dx / dist) * pullSpeed * dt
			orb.y = orb.y + (dy / dist) * pullSpeed * dt
		end
		
		if dist < Player.ship.radius + orb.radius then
			Player.exp = Player.exp + orb.value
			Player.score = Player.score + orb.value
			table.remove(Entities.exporbs, i)
			spawnParticles(orb.x, orb.y, {0, 1, 0.5}, 6)
			
			if Player.exp >= Player.expToNext then
				Player.exp = Player.exp - Player.expToNext
				Player.level = Player.level + 1
				Player.expToNext = math.floor(Player.expToNext * 1.2)
				Player.ship.hp = math.min(Player.ship.hp + 1, Player.ship.maxHp)
				spawnParticles(Player.ship.x, Player.ship.y, {1, 1, 0}, 20)
			end
		end
	end
end

local function drawExpOrbs()
	for _, orb in ipairs(Entities.exporbs) do
		local pulse = 1 + math.sin(orb.timer * 6) * 0.15
		love.graphics.setColor(0.2, 1, 0.5)
		love.graphics.circle("fill", orb.x, orb.y, orb.radius * pulse)
		love.graphics.setColor(1, 1, 1)
		love.graphics.circle("line", orb.x, orb.y, orb.radius * pulse + 1)
	end
end

-- ==============================================
-- PARTICLE FUNCTIONS
-- ==============================================

function spawnParticles(x, y, color, count)
	count = count or 8
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local speed = love.math.random(50, 150)
		local p = {
			x = x,
			y = y,
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			life = 0.5,
			maxLife = 0.5,
			color = color or { 1, 1, 1 },
			size = love.math.random(2, 4),
		}
		table.insert(Entities.particles, p)
	end
end

local function updateParticles(dt)
	for i = #Entities.particles, 1, -1 do
		local p = Entities.particles[i]
		p.x = p.x + p.vx * dt
		p.y = p.y + p.vy * dt
		p.life = p.life - dt
		p.vx = p.vx * 0.95
		p.vy = p.vy * 0.95
		if p.life <= 0 then
			table.remove(Entities.particles, i)
		end
	end
end

local function drawParticles()
	for _, p in ipairs(Entities.particles) do
		local alpha = p.life / p.maxLife
		love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
		love.graphics.circle("fill", p.x, p.y, p.size)
	end
end

-- ==============================================
-- AUTO-AIM HELPER
-- ==============================================

local function findClosestEnemy()
	local closest = nil
	local closestDist = math.huge
	
	for _, e in ipairs(Entities.enemies) do
		local dx = e.x - Player.ship.x
		local dy = e.y - Player.ship.y
		local dist = math.sqrt(dx * dx + dy * dy)
		
		if dist < closestDist and dist < Player.stats.range then
			closestDist = dist
			closest = e
		end
	end
	
	return closest, closestDist
end

-- ==============================================
-- MENU STATE
-- ==============================================

GameState.states.menu = {
	enter = function()
		Player.level = 1
		Player.exp = 0
		Player.expToNext = 100
		Player.score = 0
		Player.chain = 0
		Player.stats.damage = 1
		Player.stats.speed = 250
		Player.stats.fireRate = 0.12
		Player.upgrades.multiShot = 1
		GameData.wave = 1
		GameData.enemiesKilled = 0
	end,
	
	update = function(dt)
		if love.keyboard.isDown("space") or love.keyboard.isDown("return") then
			GameState:switch("game")
		end
	end,
	
	draw = function()
		love.graphics.setBackgroundColor(0.05, 0.05, 0.15)
		love.graphics.setColor(0.3, 0.7, 1)
		love.graphics.printf("⭐ ASTRAL ASCENDANT ⭐", 0, 150, 800, "center")
		
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Vampire Survivors meets Ikaruga", 0, 200, 800, "center")
		love.graphics.printf("Roguelike Bullet Hell", 0, 230, 800, "center")
		
		love.graphics.setColor(0.5, 1, 0.5)
		love.graphics.printf("Press SPACE to Start", 0, 350, 800, "center")
		
		love.graphics.setColor(0.7, 0.7, 0.7)
		love.graphics.printf("Arrow Keys: Move", 0, 450, 800, "center")
		love.graphics.printf("X: Switch Polarity (Ikaruga Style)", 0, 480, 800, "center")
		love.graphics.printf("Auto-shoots at closest enemy!", 0, 510, 800, "center")
		love.graphics.printf("Collect EXP orbs and power-ups to grow stronger", 0, 540, 800, "center")
	end,
}

-- ==============================================
-- GAME STATE
-- ==============================================

GameState.states.game = {
	shootTimer = 0,
	enemySpawnTimer = 0,

	enter = function()
		Player.ship = Entity:new(400, 500, "player")
		Player.ship.radius = 12
		Player.ship.hp = Player.upgrades.maxHp
		Player.ship.maxHp = Player.upgrades.maxHp
		Player.ship.color = { 0.3, 0.7, 1 }
		Player.polarity = "blue"
		Player.chain = 0

		Entities.player = Player.ship
		Entities.enemies = {}
		Entities.bullets = {}
		Entities.enemyBullets = {}
		Entities.powerups = {}
		Entities.exporbs = {}
		Entities.particles = {}
	end,

	update = function(dt)
		local state = GameState.states.game
		local p = Player.ship

		p.vx = 0
		p.vy = 0
		
		if love.keyboard.isDown("left") then
			p.vx = -Player.stats.speed
		end
		if love.keyboard.isDown("right") then
			p.vx = Player.stats.speed
		end
		if love.keyboard.isDown("up") then
			p.vy = -Player.stats.speed
		end
		if love.keyboard.isDown("down") then
			p.vy = Player.stats.speed
		end

		if p.vx ~= 0 and p.vy ~= 0 then
			p.vx = p.vx * 0.707
			p.vy = p.vy * 0.707
		end

		p:update(dt)

		p.x = math.max(20, math.min(780, p.x))
		p.y = math.max(20, math.min(580, p.y))

		-- AUTO-SHOOTING
		state.shootTimer = state.shootTimer + dt
		if state.shootTimer >= Player.stats.fireRate then
			state.shootTimer = 0
			
			local target = findClosestEnemy()
			if target then
				for i = 1, Player.upgrades.multiShot do
					local angle = math.atan2(target.y - p.y, target.x - p.x)
					
					if Player.upgrades.multiShot > 1 then
						angle = angle + (i - (Player.upgrades.multiShot + 1) / 2) * 0.15
					end
					
					local b = Entity:new(p.x, p.y, "playerBullet")
					b.vx = math.cos(angle) * Player.stats.projectileSpeed
					b.vy = math.sin(angle) * Player.stats.projectileSpeed
					b.radius = 5
					b.color = Player.polarity == "blue" and { 0.3, 0.8, 1 } or { 1, 0.3, 0.5 }
					b.polarity = Player.polarity
					b.damage = Player.stats.damage
					table.insert(Entities.bullets, b)
				end
			end
		end

		-- Enemy spawning
		state.enemySpawnTimer = state.enemySpawnTimer + dt
		local spawnRate = math.max(0.5, 2 - (GameData.wave * 0.1))
		if state.enemySpawnTimer > spawnRate then
			state.enemySpawnTimer = 0
			local e = Entity:new(love.math.random(100, 700), -20, "enemy")
			e.hp = 3 + GameData.wave
			e.maxHp = e.hp
			e.vy = 50 + GameData.wave * 5
			e.radius = 15
			e.polarity = love.math.random() > 0.5 and "blue" or "red"
			e.color = e.polarity == "blue" and { 0.4, 0.6, 1 } or { 1, 0.4, 0.4 }
			e.shootTimer = 0
			e.expValue = 5 + GameData.wave * 2
			table.insert(Entities.enemies, e)
		end

		-- Update enemies
		for i = #Entities.enemies, 1, -1 do
			local e = Entities.enemies[i]
			e:update(dt)
			e.shootTimer = e.shootTimer + dt

			if e.shootTimer > 2 then
				e.shootTimer = 0
				local pattern = BulletPatterns.aimed(e.x, e.y, p.x, p.y, 150, 3)
				for _, b in ipairs(pattern) do
					table.insert(Entities.enemyBullets, b)
				end
			end

			if e.y > 650 or e.hp <= 0 then
				if e.hp <= 0 then
					spawnParticles(e.x, e.y, e.color, 12)
					spawnExpOrb(e.x, e.y, e.expValue)
					
					if love.math.random() < 0.15 then
						spawnPowerUp(e.x, e.y)
					end
					
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
			if b.y < -10 or b.x < -10 or b.x > 810 or b.y > 610 then
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

		-- Collision: Player bullets vs Enemies
		for i = #Entities.bullets, 1, -1 do
			local b = Entities.bullets[i]
			local hit = false
			for j = #Entities.enemies, 1, -1 do
				local e = Entities.enemies[j]
				local dist = math.sqrt((b.x - e.x) ^ 2 + (b.y - e.y) ^ 2)
				if dist < b.radius + e.radius then
					local dmg = b.damage
					
					if b.polarity == e.polarity then
						dmg = dmg * Player.upgrades.polarityBonus
						Player.score = Player.score + 5
					end
					
					e.hp = e.hp - dmg
					if not Player.upgrades.piercing then
						hit = true
					end
					spawnParticles(b.x, b.y, b.color, 4)
					if hit then break end
				end
			end
			if hit then
				table.remove(Entities.bullets, i)
			end
		end

		-- Collision: Enemy bullets vs Player
		for i = #Entities.enemyBullets, 1, -1 do
			local b = Entities.enemyBullets[i]
			local dist = math.sqrt((b.x - p.x) ^ 2 + (b.y - p.y) ^ 2)
			if dist < b.radius + p.radius then
				if b.polarity ~= Player.polarity then
					p.hp = p.hp - 1
					spawnParticles(p.x, p.y, { 1, 0.5, 0 }, 8)
					Player.chain = 0
					if p.hp <= 0 then
						GameState:switch("gameover")
					end
				else
					Player.score = Player.score + 5
					spawnParticles(b.x, b.y, b.color, 6)
				end
				table.remove(Entities.enemyBullets, i)
			end
		end

		updateParticles(dt)
		updateExpOrbs(dt)
		updatePowerUps(dt)

		if GameData.enemiesKilled >= GameData.wave * 15 then
			GameData.wave = GameData.wave + 1
		end
	end,

	draw = function()
		love.graphics.setColor(0.05, 0.05, 0.15)
		love.graphics.rectangle("fill", 0, 0, 800, 600)

		if Entities.player.alive then
			love.graphics.setColor(Player.polarity == "blue" and { 0.3, 0.7, 1 } or { 1, 0.3, 0.5 })
			love.graphics.circle("fill", Entities.player.x, Entities.player.y, Entities.player.radius)
			love.graphics.setColor(1, 1, 1)
			love.graphics.circle("line", Entities.player.x, Entities.player.y, Entities.player.radius + 3)
			
			local target = findClosestEnemy()
			if target then
				love.graphics.setColor(1, 1, 0, 0.3)
				love.graphics.line(Entities.player.x, Entities.player.y, target.x, target.y)
				love.graphics.circle("line", target.x, target.y, target.radius + 5)
			end
		end

		for _, e in ipairs(Entities.enemies) do
			e:draw()
			love.graphics.setColor(1, 0, 0)
			love.graphics.rectangle("fill", e.x - 15, e.y - 25, 30, 3)
			love.graphics.setColor(0, 1, 0)
			love.graphics.rectangle("fill", e.x - 15, e.y - 25, 30 * (e.hp / e.maxHp), 3)
		end

		for _, b in ipairs(Entities.bullets) do
			b:draw()
		end
		for _, b in ipairs(Entities.enemyBullets) do
			b:draw()
		end

		drawExpOrbs()
		drawPowerUps()
		drawParticles()

		love.graphics.setColor(1, 1, 1)
		love.graphics.print("HP: " .. Player.ship.hp .. "/" .. Player.ship.maxHp, 10, 10)
		love.graphics.print("Level: " .. Player.level, 10, 30)
		love.graphics.print("EXP: " .. Player.exp .. "/" .. Player.expToNext, 10, 50)
		love.graphics.print("Score: " .. Player.score, 10, 70)
		love.graphics.print("Chain: " .. Player.chain, 10, 90)
		love.graphics.print("Wave: " .. GameData.wave, 10, 110)
		love.graphics.setColor(Player.polarity == "blue" and { 0.3, 0.7, 1 } or { 1, 0.3, 0.5 })
		love.graphics.print("Polarity: " .. Player.polarity:upper(), 10, 130)
		
		love.graphics.setColor(0.7, 0.7, 0.7)
		love.graphics.print("DMG: " .. string.format("%.1f", Player.stats.damage), 700, 10)
		love.graphics.print("SPD: " .. string.format("%.0f", Player.stats.speed), 700, 30)
		love.graphics.print("Multi: x" .. Player.upgrades.multiShot, 700, 50)
	end,

	keypressed = function(key)
		if key == "x" then
			Player.polarity = Player.polarity == "blue" and "red" or "blue"
		elseif key == "escape" then
			GameState:switch("menu")
		end
	end,
}

-- ==============================================
-- GAME OVER STATE
-- ==============================================

GameState.states.gameover = {
	draw = function()
		love.graphics.setColor(1, 0, 0)
		love.graphics.printf("💀 GAME OVER 💀", 0, 200, 800, "center")
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Final Score: " .. Player.score, 0, 260, 800, "center")
		love.graphics.printf("Level Reached: " .. Player.level, 0, 290, 800, "center")
		love.graphics.printf("Waves Survived: " .. GameData.wave, 0, 320, 800, "center")
		love.graphics.printf("Max Chain: " .. Player.chain, 0, 350, 800, "center")
		love.graphics.setColor(0.7, 0.7, 0.7)
		love.graphics.printf("Press SPACE to return to menu", 0, 420, 800, "center")
	end,
	
	keypressed = function(key)
		if key == "space" or key == "return" then
			GameState:switch("menu")
		end
	end,
}

-- ==============================================
-- LOVE2D CALLBACKS
-- ==============================================

function love.load()
	love.window.setTitle("Astral Ascendant - Vampire Survivors meets Ikaruga")
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

	love.graphics.setColor(0.5, 0.5, 0.5)
	love.graphics.print("State: " .. GameState.current, 680, 580)
	love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 580)
end

function love.keypressed(key)
	local state = GameState.states[GameState.current]
	if state and state.keypressed then
		state.keypressed(key)
	end
	
	if key == "escape" and GameState.current == "menu" then
		love.event.quit()
	end
end