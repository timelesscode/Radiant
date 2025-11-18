-- main.lua - Fantasy Action Fighting Game for LÖVE2D
-- Enhanced with Interactive Tutorial System

function love.load()
	love.window.setTitle("Fantasy Action Fighter")
	love.window.setMode(1200, 800, {resizable = true})

	-- Game state
	gameState = "menu" -- menu, tutorial, battle, shooter, victory, defeat

	-- Tutorial state
	tutorialStep = 0 -- 0 = not started, 1-6 = different training stages
	currentEnemy = nil
	canInteract = false
	showInteractPrompt = false
	
	-- Sensei dialogue for each step
	senseiDialogue = {
		[0] = "Greetings, young warrior! I am Master Chen. Press E to speak with me when you're ready to begin your training.",
		[1] = "Welcome to your training! First, let's practice movement. Use A and D (or arrow keys) to move left and right. Try moving around, then come back and press E.",
		[2] = "Good! Now let's learn to jump. Press SPACE or W to jump. Practice jumping a few times, then return to me.",
		[3] = "Excellent! Now for combat. I've summoned a training dummy. Press J to attack it. Defeat the dummy and return to me.",
		[4] = "Well done! Now try your special ability. Press K to use your class ability on the next dummy. Each class has unique powers!",
		[5] = "Impressive! You've mastered the basics. Now face this stronger enemy. Use everything you've learned - movement, attacks, and abilities!",
		[6] = "Magnificent! You are ready for real combat. But first, let me teach you ranged combat. Press ENTER to begin the SHOOTER training module!",
	}
	currentDialogue = senseiDialogue[0]
	
	-- Player
	player = {
		class = "knight",
		x = 200,
		y = 400,
		width = 50,
		height = 60,
		vx = 0,
		vy = 0,
		onGround = false,
		facingRight = true,
		hp = 120,
		maxHp = 120,
		attackDamage = 25,
		defense = 30,
		speed = 250,
		jumpPower = 450,

		-- Combat
		isAttacking = false,
		attackCooldown = 0,
		attackRange = 80,
		attackDuration = 0.3,
		attackTimer = 0,

		-- Ability
		abilityReady = true,
		abilityCooldown = 0,
		abilityMaxCooldown = 5,

		-- Animation
		animTimer = 0,
		frame = 0,
		
		-- Progression
		level = 1,
		experience = 0,
		
		-- Tutorial flags
		hasMoved = false,
		hasJumped = false,
		hasAttacked = false,
		hasUsedAbility = false,
	}

	-- Training enemies for tutorial
	trainingEnemies = {}

	-- Enemies for battle mode
	enemies = {}
	spawnTimer = 0
	spawnInterval = 4
	enemiesDefeated = 0
	wave = 1
	maxEnemiesOnScreen = 3

	-- Ground
	ground = 650
	gravity = 1500

	-- Sensei NPC
	sensei = {
		x = 900,
		y = ground - 70,
		width = 60,
		height = 70,
		interactRange = 100,
	}

	-- Classes data
	classes = {
		knight = {
			name = "Knight",
			hp = 120,
			damage = 25,
			defense = 30,
			speed = 250,
			ability = "Shield Bash",
			color = { 0.3, 0.5, 1 },
		},
		mage = {
			name = "Mage",
			hp = 80,
			damage = 40,
			defense = 10,
			speed = 200,
			ability = "Fireball",
			color = { 0.7, 0.3, 1 },
		},
		rogue = {
			name = "Rogue",
			hp = 90,
			damage = 35,
			defense = 15,
			speed = 300,
			ability = "Dash Strike",
			color = { 0.5, 0.5, 0.5 },
		},
	}

	selectedClass = "knight"
	
	-- Window scale factor
	scaleX = 1
	scaleY = 1
end

function love.resize(w, h)
	scaleX = w / 1200
	scaleY = h / 800
end

function love.update(dt)
	if gameState == "menu" then
		updateMenu(dt)
	elseif gameState == "tutorial" then
		updateTutorial(dt)
	elseif gameState == "battle" then
		updateBattle(dt)
	elseif gameState == "shooter" then
		updateShooter(dt)
	end
end

function love.draw()
	-- Apply scaling for resizable window
	love.graphics.push()
	love.graphics.scale(scaleX, scaleY)
	
	if gameState == "menu" then
		drawMenu()
	elseif gameState == "tutorial" then
		drawTutorial()
	elseif gameState == "battle" then
		drawBattle()
	elseif gameState == "shooter" then
		drawShooter()
	elseif gameState == "victory" then
		drawVictory()
	elseif gameState == "defeat" then
		drawDefeat()
	end
	
	love.graphics.pop()
end

function updateMenu(dt)
	-- Nothing special to update in menu
end

function updateTutorial(dt)
	-- Update player
	updatePlayer(dt)
	
	-- Check for movement (step 1)
	if tutorialStep == 1 then
		if love.keyboard.isDown("a") or love.keyboard.isDown("d") or 
		   love.keyboard.isDown("left") or love.keyboard.isDown("right") then
			player.hasMoved = true
		end
	end
	
	-- Check for jumping (step 2)
	if tutorialStep == 2 then
		if not player.onGround then
			player.hasJumped = true
		end
	end
	
	-- Update training enemies
	for i = #trainingEnemies, 1, -1 do
		local enemy = trainingEnemies[i]
		
		-- Simple idle animation
		enemy.animTimer = enemy.animTimer + dt
		if enemy.animTimer >= 0.2 then
			enemy.animTimer = 0
			enemy.frame = (enemy.frame + 1) % 4
		end
		
		-- Remove dead enemies
		if enemy.hp <= 0 then
			if tutorialStep == 3 then
				player.hasAttacked = true
			elseif tutorialStep == 4 then
				player.hasUsedAbility = true
			elseif tutorialStep == 5 then
				-- Final enemy defeated, ready for shooter
				tutorialStep = 6
				currentDialogue = senseiDialogue[6]
			end
			table.remove(trainingEnemies, i)
		end
	end
	
	-- Check if player is near sensei
	local distanceToSensei = math.abs(player.x - sensei.x)
	canInteract = distanceToSensei < sensei.interactRange and #trainingEnemies == 0
	showInteractPrompt = canInteract
end

function updateBattle(dt)
	-- Update player
	updatePlayer(dt)

	-- Update enemies
	for i = #enemies, 1, -1 do
		updateEnemy(enemies[i], dt)

		-- Remove dead enemies
		if enemies[i].hp <= 0 then
			enemiesDefeated = enemiesDefeated + 1
			player.experience = player.experience + 10
			table.remove(enemies, i)
		end
	end

	-- Spawn enemies (with limit)
	spawnTimer = spawnTimer + dt
	if spawnTimer >= spawnInterval and #enemies < maxEnemiesOnScreen then
		spawnTimer = 0
		spawnEnemy()

		-- Increase difficulty gradually
		if enemiesDefeated > 0 and enemiesDefeated % 5 == 0 then
			wave = math.floor(enemiesDefeated / 5) + 1
			spawnInterval = math.max(2.5, 4 - wave * 0.3)
			maxEnemiesOnScreen = math.min(5, 3 + math.floor(wave / 2))
		end
	end

	-- Check game over
	if player.hp <= 0 then
		gameState = "defeat"
	end

	-- Check victory (survive 15 enemies)
	if enemiesDefeated >= 15 then
		gameState = "victory"
	end
end

function updateShooter(dt)
	-- This is a placeholder - we'll integrate the shooter module
	-- For now, just update player
	updatePlayer(dt)
end

function updatePlayer(dt)
	local classData = classes[player.class]

	-- Movement
	player.vx = 0
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		player.vx = -player.speed
		player.facingRight = false
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		player.vx = player.speed
		player.facingRight = true
	end

	-- Jump
	if (love.keyboard.isDown("w") or love.keyboard.isDown("space") or love.keyboard.isDown("up")) and player.onGround then
		player.vy = -player.jumpPower
		player.onGround = false
	end

	-- Apply gravity
	if not player.onGround then
		player.vy = player.vy + gravity * dt
	end

	-- Update position
	player.x = player.x + player.vx * dt
	player.y = player.y + player.vy * dt

	-- Ground collision
	if player.y + player.height >= ground then
		player.y = ground - player.height
		player.vy = 0
		player.onGround = true
	end

	-- Screen bounds
	player.x = math.max(0, math.min(player.x, 1200 - player.width))

	-- Attack cooldown
	if player.attackCooldown > 0 then
		player.attackCooldown = player.attackCooldown - dt
	end

	-- Attack timer
	if player.isAttacking then
		player.attackTimer = player.attackTimer + dt
		if player.attackTimer >= player.attackDuration then
			player.isAttacking = false
			player.attackTimer = 0
		end
	end

	-- Ability cooldown
	if not player.abilityReady then
		player.abilityCooldown = player.abilityCooldown - dt
		if player.abilityCooldown <= 0 then
			player.abilityReady = true
		end
	end

	-- Animation
	player.animTimer = player.animTimer + dt
	if player.animTimer >= 0.15 then
		player.animTimer = 0
		player.frame = (player.frame + 1) % 4
	end
end

function updateEnemy(enemy, dt)
	-- Simple AI - move towards player
	local dx = player.x - enemy.x
	local distance = math.abs(dx)

	if distance > 60 then
		if dx > 0 then
			enemy.x = enemy.x + enemy.speed * dt
			enemy.facingRight = true
		else
			enemy.x = enemy.x - enemy.speed * dt
			enemy.facingRight = false
		end
	else
		-- Attack player
		enemy.attackCooldown = enemy.attackCooldown - dt
		if enemy.attackCooldown <= 0 then
			enemy.attackCooldown = 1.5
			enemy.isAttacking = true

			-- Deal damage to player
			local damage = math.max(enemy.damage - player.defense / 3, 5)
			player.hp = math.max(0, player.hp - damage)
		end
	end

	-- Attack animation
	if enemy.isAttacking then
		enemy.attackTimer = enemy.attackTimer + dt
		if enemy.attackTimer >= 0.3 then
			enemy.isAttacking = false
			enemy.attackTimer = 0
		end
	end

	-- Animation
	enemy.animTimer = enemy.animTimer + dt
	if enemy.animTimer >= 0.2 then
		enemy.animTimer = 0
		enemy.frame = (enemy.frame + 1) % 4
	end
end

function spawnTrainingEnemy(difficulty)
	difficulty = difficulty or "easy"
	
	local enemy = {
		x = 500,
		y = ground - 50,
		width = 45,
		height = 50,
		hp = 50,
		maxHp = 50,
		color = { 0.7, 0.6, 0.4 },
		animTimer = 0,
		frame = 0,
		type = "dummy",
	}
	
	if difficulty == "medium" then
		enemy.hp = 80
		enemy.maxHp = 80
		enemy.color = { 0.8, 0.5, 0.3 }
	elseif difficulty == "hard" then
		enemy.hp = 120
		enemy.maxHp = 120
		enemy.color = { 0.9, 0.3, 0.3 }
		enemy.type = "training_boss"
	end
	
	table.insert(trainingEnemies, enemy)
end

function spawnEnemy()
	local types = { "goblin", "orc", "skeleton" }
	local enemyType = types[math.random(#types)]

	local enemy = {
		type = enemyType,
		x = math.random() > 0.5 and 1200 or -50,
		y = ground - 50,
		width = 45,
		height = 50,
		hp = 40 + wave * 8,
		maxHp = 40 + wave * 8,
		damage = 12 + wave * 2,
		speed = 70 + wave * 4,
		facingRight = true,
		isAttacking = false,
		attackCooldown = 0,
		attackTimer = 0,
		animTimer = 0,
		frame = 0,
	}

	if enemyType == "orc" then
		enemy.hp = enemy.hp * 1.5
		enemy.maxHp = enemy.maxHp * 1.5
		enemy.damage = enemy.damage * 1.3
		enemy.speed = enemy.speed * 0.8
		enemy.color = { 0.3, 0.7, 0.3 }
	elseif enemyType == "skeleton" then
		enemy.speed = enemy.speed * 1.3
		enemy.color = { 0.9, 0.9, 0.9 }
	else
		enemy.color = { 0.6, 0.8, 0.3 }
	end

	table.insert(enemies, enemy)
end

function love.keypressed(key)
	-- ESC to quit from any state
	if key == "escape" then
		love.event.quit()
	end
	
	if gameState == "menu" then
		if key == "return" or key == "space" then
			startTutorial()
		elseif key == "t" then
			startGame() -- Skip to battle
		elseif key == "1" then
			selectedClass = "knight"
		elseif key == "2" then
			selectedClass = "mage"
		elseif key == "3" then
			selectedClass = "rogue"
		end
	elseif gameState == "tutorial" then
		-- Interact with sensei
		if key == "e" and canInteract then
			interactWithSensei()
		end
		
		-- Combat controls
		if key == "j" or key == "z" then
			playerAttackTutorial()
		elseif key == "k" or key == "x" then
			playerAbility()
		end
		
		-- Advance to shooter from final step
		if key == "return" and tutorialStep == 6 then
			startShooter()
		end
	elseif gameState == "battle" then
		if key == "j" or key == "z" then
			playerAttack()
		elseif key == "k" or key == "x" then
			playerAbility()
		end
	elseif gameState == "shooter" then
		-- Shooter controls will be handled by the shooter module
		if key == "return" then
			-- Complete tutorial and go to battle
			startGame()
		end
	elseif gameState == "victory" or gameState == "defeat" then
		if key == "return" or key == "space" then
			gameState = "menu"
		end
	end
end

function interactWithSensei()
	if tutorialStep == 0 then
		-- Start tutorial
		tutorialStep = 1
		currentDialogue = senseiDialogue[1]
	elseif tutorialStep == 1 and player.hasMoved then
		-- Progress to jump training
		tutorialStep = 2
		currentDialogue = senseiDialogue[2]
		player.hasJumped = false
	elseif tutorialStep == 2 and player.hasJumped then
		-- Progress to attack training
		tutorialStep = 3
		currentDialogue = senseiDialogue[3]
		spawnTrainingEnemy("easy")
	elseif tutorialStep == 3 and player.hasAttacked then
		-- Progress to ability training
		tutorialStep = 4
		currentDialogue = senseiDialogue[4]
		player.abilityReady = true
		player.abilityCooldown = 0
		spawnTrainingEnemy("medium")
	elseif tutorialStep == 4 and player.hasUsedAbility then
		-- Progress to final challenge
		tutorialStep = 5
		currentDialogue = senseiDialogue[5]
		player.hp = player.maxHp -- Heal player
		player.abilityReady = true
		spawnTrainingEnemy("hard")
	end
end

function playerAttackTutorial()
	if player.attackCooldown <= 0 and not player.isAttacking then
		player.isAttacking = true
		player.attackCooldown = 0.5

		-- Check collision with training enemies
		for _, enemy in ipairs(trainingEnemies) do
			local dx = enemy.x - player.x
			local distance = math.abs(dx)

			if distance < player.attackRange and 
			   ((player.facingRight and dx > 0) or (not player.facingRight and dx < 0)) then
				enemy.hp = enemy.hp - player.attackDamage
			end
		end
	end
end

function playerAttack()
	if player.attackCooldown <= 0 and not player.isAttacking then
		player.isAttacking = true
		player.attackCooldown = 0.5

		-- Check collision with enemies
		for _, enemy in ipairs(enemies) do
			local dx = enemy.x - player.x
			local distance = math.abs(dx)

			if distance < player.attackRange and 
			   ((player.facingRight and dx > 0) or (not player.facingRight and dx < 0)) then
				local damage = math.max(player.attackDamage - enemy.maxHp * 0.1, 10)
				enemy.hp = enemy.hp - damage
			end
		end
	end
end

function playerAbility()
	if player.abilityReady then
		player.abilityReady = false
		player.abilityCooldown = player.abilityMaxCooldown

		local targets = (gameState == "tutorial") and trainingEnemies or enemies

		if player.class == "knight" then
			-- Shield Bash - stun and damage nearby enemies
			for _, target in ipairs(targets) do
				local distance = math.abs(target.x - player.x)
				if distance < 120 then
					target.hp = target.hp - player.attackDamage * 1.5
					if target.speed then
						target.speed = target.speed * 0.5
					end
				end
			end
		elseif player.class == "mage" then
			-- Fireball - ranged AOE attack
			local direction = player.facingRight and 1 or -1
			local fireballX = player.x + direction * 200

			for _, target in ipairs(targets) do
				local distance = math.abs(target.x - fireballX)
				if distance < 100 then
					target.hp = target.hp - player.attackDamage * 2
				end
			end
		elseif player.class == "rogue" then
			-- Dash Strike - quick dash with damage
			local direction = player.facingRight and 1 or -1
			player.x = player.x + direction * 200

			for _, target in ipairs(targets) do
				local distance = math.abs(target.x - player.x)
				if distance < 80 then
					target.hp = target.hp - player.attackDamage * 2.5
				end
			end
		end
	end
end

function startTutorial()
	gameState = "tutorial"
	
	-- Initialize player with selected class
	local classData = classes[selectedClass]
	player.class = selectedClass
	player.hp = classData.hp
	player.maxHp = classData.hp
	player.attackDamage = classData.damage
	player.defense = classData.defense
	player.speed = classData.speed
	player.x = 200
	player.y = ground - player.height
	player.abilityReady = true
	player.abilityCooldown = 0
	player.level = 1
	
	-- Reset tutorial state
	tutorialStep = 0
	trainingEnemies = {}
	currentDialogue = senseiDialogue[0]
	player.hasMoved = false
	player.hasJumped = false
	player.hasAttacked = false
	player.hasUsedAbility = false
end

function startShooter()
	gameState = "shooter"
	-- Initialize shooter module (placeholder for now)
	currentDialogue = "SHOOTER MODULE: Press ENTER when ready to begin your quest!"
end

function startGame()
	gameState = "battle"

	-- Initialize player with enhanced stats (post-training)
	local classData = classes[selectedClass]
	player.class = selectedClass
	player.hp = classData.hp * 1.2 -- 20% bonus from training
	player.maxHp = classData.hp * 1.2
	player.attackDamage = classData.damage * 1.2
	player.defense = classData.defense * 1.2
	player.speed = classData.speed
	player.x = 200
	player.y = ground - player.height
	player.abilityReady = true
	player.abilityCooldown = 0
	player.level = 2
	player.experience = 0

	-- Reset game state
	enemies = {}
	enemiesDefeated = 0
	wave = 1
	spawnTimer = 0
	spawnInterval = 4
	maxEnemiesOnScreen = 3
end

function drawMenu()
	love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

	-- Title
	love.graphics.setColor(1, 0.8, 0.2)
	love.graphics.printf("⚔️ FANTASY ACTION FIGHTER ⚔️", 0, 80, 1200, "center")

	-- Instructions
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Choose Your Class (Press 1, 2, or 3)", 0, 180, 1200, "center")

	-- Classes
	local startX = 200
	local i = 1
	for key, class in pairs(classes) do
		local x = startX + (i - 1) * 300

		-- Highlight selected
		if selectedClass == key then
			love.graphics.setColor(1, 1, 0.3, 0.3)
			love.graphics.rectangle("fill", x - 10, 260, 220, 300)
		end

		love.graphics.setColor(class.color)
		love.graphics.rectangle("fill", x, 280, 200, 150)

		love.graphics.setColor(0, 0, 0)
		love.graphics.printf(i .. ". " .. class.name, x, 290, 200, "center")
		love.graphics.printf("HP: " .. class.hp, x, 330, 200, "center")
		love.graphics.printf("DMG: " .. class.damage, x, 350, 200, "center")
		love.graphics.printf("DEF: " .. class.defense, x, 370, 200, "center")
		love.graphics.printf("SPD: " .. class.speed, x, 390, 200, "center")

		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Ability:", x, 450, 200, "center")
		love.graphics.printf(class.ability, x, 470, 200, "center")

		i = i + 1
	end

	-- Start buttons
	love.graphics.setColor(0.3, 1, 0.3)
	love.graphics.printf("Press ENTER to Start Interactive Tutorial", 0, 620, 1200, "center")
	
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.printf("(Press T to skip tutorial)", 0, 650, 1200, "center")

	-- Controls
	love.graphics.setColor(0.6, 0.6, 0.6)
	love.graphics.printf("Controls: WASD=Move | J=Attack | K=Ability | E=Interact | ESC=Quit", 0, 730, 1200, "center")
end

function drawTutorial()
	love.graphics.setBackgroundColor(0.2, 0.25, 0.3)

	-- Draw ground
	love.graphics.setColor(0.4, 0.5, 0.4)
	love.graphics.rectangle("fill", 0, ground, 1200, 150)

	-- Draw sensei
	love.graphics.setColor(0.9, 0.8, 0.4)
	love.graphics.rectangle("fill", sensei.x, sensei.y, sensei.width, sensei.height)
	
	-- Sensei face details
	love.graphics.setColor(0, 0, 0)
	love.graphics.circle("fill", sensei.x + 20, sensei.y + 20, 3) -- eyes
	love.graphics.circle("fill", sensei.x + 40, sensei.y + 20, 3)
	love.graphics.arc("line", "open", sensei.x + 30, sensei.y + 35, 10, 0.2, 2.9) -- smile
	
	-- Sensei label
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("MASTER CHEN", sensei.x - 20, sensei.y - 25, sensei.width + 40, "center")

	-- Interact prompt
	if showInteractPrompt then
		love.graphics.setColor(0.3, 1, 0.3)
		love.graphics.printf("[E] Talk", sensei.x - 20, sensei.y - 45, sensei.width + 40, "center")
	end

	-- Draw player
	drawPlayer()

	-- Draw training enemies
	for _, enemy in ipairs(trainingEnemies) do
		love.graphics.setColor(enemy.color)
		love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
		
		-- HP bar
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", enemy.x - 3, enemy.y - 12, enemy.width + 6, 6)
		love.graphics.setColor(1, 0, 0)
		local hpWidth = (enemy.hp / enemy.maxHp) * enemy.width
		love.graphics.rectangle("fill", enemy.x, enemy.y - 10, hpWidth, 2)
		
		-- Label
		love.graphics.setColor(1, 1, 1)
		if enemy.type == "training_boss" then
			love.graphics.printf("BOSS", enemy.x - 10, enemy.y + 10, enemy.width + 20, "center")
		else
			love.graphics.printf("DUMMY", enemy.x - 10, enemy.y + 10, enemy.width + 20, "center")
		end
	end

	-- Draw dialogue box
	love.graphics.setColor(0, 0, 0, 0.85)
	love.graphics.rectangle("fill", 50, 30, 1100, 100)
	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle("line", 50, 30, 1100, 100)
	
	love.graphics.setColor(1, 0.9, 0.4)
	love.graphics.printf("Master Chen:", 70, 45, 1060, "left")
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(currentDialogue, 70, 70, 1060, "left")

	-- Tutorial progress
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.print("Tutorial Step: " .. tutorialStep .. " / 6", 20, 150)
	
	-- Player HP
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("HP: " .. math.floor(player.hp) .. " / " .. player.maxHp, 20, 180)
	
	-- Ability status
	if player.abilityReady then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print("Ability: READY", 20, 210)
	else
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.print("Ability: " .. string.format("%.1fs", player.abilityCooldown), 20, 210)
	end
end

function drawBattle()
	love.graphics.setBackgroundColor(0.15, 0.15, 0.2)

	-- Draw ground
	love.graphics.setColor(0.3, 0.5, 0.3)
	love.graphics.rectangle("fill", 0, ground, 1200, 150)

	-- Draw player
	drawPlayer()

	-- Draw enemies
	for _, enemy in ipairs(enemies) do
		drawEnemy(enemy)
	end

	-- Draw UI
	drawUI()
end

function drawShooter()
	love.graphics.setBackgroundColor(0.1, 0.15, 0.2)
	
	-- Placeholder for shooter module
	love.graphics.setColor(1, 1, 0)
	love.graphics.printf("🎯 SHOOTER TRAINING MODULE 🎯", 0, 200, 1200, "center")
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Master Chen: Now learn the art of ranged combat!", 0, 300, 1200, "center")
	love.graphics.printf("(This will integrate your LÖVE2D shooter module)", 0, 350, 1200, "center")
	
	love.graphics.setColor(0.3, 1, 0.3)
	love.graphics.printf("Press ENTER to complete training and begin your quest!", 0, 500, 1200, "center")
	
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.printf("ESC to quit", 0, 730, 1200, "center")
end

function drawPlayer()
	local classData = classes[player.class]
	love.graphics.setColor(classData.color)

	-- Body
	love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)

	-- Direction indicator
	love.graphics.setColor(1, 1, 1)
	if player.facingRight then
		love.graphics.polygon("fill",
			player.x + player.width, player.y + player.height / 2,
			player.x + player.width + 10, player.y + player.height / 2 - 5,
			player.x + player.width + 10, player.y + player.height / 2 + 5)
	else
		love.graphics.polygon("fill",
			player.x, player.y + player.height / 2,
			player.x - 10, player.y + player.height / 2 - 5,
			player.x - 10, player.y + player.height / 2 + 5)
	end

	-- Attack indicator
	if player.isAttacking then
		love.graphics.setColor(1, 1, 0, 0.5)
		local attackX = player.facingRight and player.x + player.width or player.x - player.attackRange
		love.graphics.rectangle("fill", attackX, player.y, player.attackRange, player.height)
	end

	-- HP bar
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", player.x - 5, player.y - 15, player.width + 10, 8)
	love.graphics.setColor(0, 1, 0)
	local hpWidth = (player.hp / player.maxHp) * player.width
	love.graphics.rectangle("fill", player.x, player.y - 13, hpWidth, 4)
end

function drawEnemy(enemy)
	love.graphics.setColor(enemy.color or { 1, 0.3, 0.3 })

	-- Body
	love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)

	-- Direction
	love.graphics.setColor(0.8, 0.8, 0.8)
	if enemy.facingRight then
		love.graphics.polygon("fill",
			enemy.x + enemy.width, enemy.y + enemy.height / 2,
			enemy.x + enemy.width + 8, enemy.y + enemy.height / 2 - 4,
			enemy.x + enemy.width + 8, enemy.y + enemy.height / 2 + 4)
	else
		love.graphics.polygon("fill",
			enemy.x, enemy.y + enemy.height / 2,
			enemy.x - 8, enemy.y + enemy.height / 2 - 4,
			enemy.x - 8, enemy.y + enemy.height / 2 + 4)
	end

	-- Attack indicator
	if enemy.isAttacking then
		love.graphics.setColor(1, 0, 0, 0.5)
		love.graphics.circle("fill", enemy.x + enemy.width / 2, enemy.y + enemy.height / 2, 40)
	end

	-- HP bar
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", enemy.x - 3, enemy.y - 12, enemy.width + 6, 6)
	love.graphics.setColor(1, 0, 0)
	local hpWidth = (enemy.hp / enemy.maxHp) * enemy.width
	love.graphics.rectangle("fill", enemy.x, enemy.y - 10, hpWidth, 2)
end

function drawUI()
	-- Player HP
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Level " .. player.level .. " " .. classes[player.class].name, 20, 20)
	love.graphics.print("HP: " .. math.floor(player.hp) .. " / " .. player.maxHp, 20, 45)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 20, 70, 210, 25)
	love.graphics.setColor(0, 1, 0)
	local hpBarWidth = (player.hp / player.maxHp) * 200
	love.graphics.rectangle("fill", 25, 75, hpBarWidth, 15)

	-- Ability cooldown
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Ability: " .. classes[player.class].ability, 20, 110)
	if player.abilityReady then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print("READY! (Press K)", 20, 130)
	else
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.print(string.format("Cooldown: %.1fs", player.abilityCooldown), 20, 130)
	end

	-- Wave and score
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Wave: " .. wave, 1050, 20)
	love.graphics.print("Defeated: " .. enemiesDefeated .. " / 15", 1000, 45)
	love.graphics.print("Enemies: " .. #enemies .. " / " .. maxEnemiesOnScreen, 1000, 70)

	-- Controls reminder
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.print("Move: WASD | Attack: J | Ability: K | Quit: ESC", 420, 760)
end

function drawVictory()
	love.graphics.setBackgroundColor(0.1, 0.3, 0.1)
	love.graphics.setColor(1, 1, 0)
	love.graphics.printf("🎉 VICTORY! 🎉", 0, 250, 1200, "center")
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Congratulations, Warrior!", 0, 350, 1200, "center")
	love.graphics.printf("You have completed your training and defeated " .. enemiesDefeated .. " enemies!", 0, 400, 1200, "center")
	love.graphics.printf("Master Chen would be proud.", 0, 450, 1200, "center")
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.printf("Press ENTER to return to menu | ESC to quit", 0, 550, 1200, "center")
end

function drawDefeat()
	love.graphics.setBackgroundColor(0.3, 0.1, 0.1)
	love.graphics.setColor(1, 0.3, 0.3)
	love.graphics.printf("💀 DEFEAT 💀", 0, 250, 1200, "center")
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("You have fallen in battle...", 0, 350, 1200, "center")
	love.graphics.printf("You defeated " .. enemiesDefeated .. " enemies", 0, 400, 1200, "center")
	love.graphics.printf("Train harder and try again!", 0, 450, 1200, "center")
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.printf("Press ENTER to return to menu | ESC to quit", 0, 550, 1200, "center")
end