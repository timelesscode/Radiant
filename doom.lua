-- Doom-style Raycaster for LÖVE2D
-- WASD to move, mouse to look, left click to shoot

function love.load()
    love.mouse.setRelativeMode(true)
    
    -- Player
    player = {
        x = 3,
        y = 3,
        angle = 0,
        fov = math.pi / 3,
        speed = 3,
        rotSpeed = 0.003
    }
    
    -- Screen
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
    
    -- Map (1 = wall, 0 = empty)
    map = {
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,1,1,0,0,0,0,1,1,1,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
        {1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
        {1,0,0,1,1,1,0,0,0,0,1,1,1,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
    }
    
    -- Enemies
    enemies = {
        {x = 7, y = 7, alive = true, health = 3},
        {x = 10, y = 4, alive = true, health = 3},
        {x = 5, y = 12, alive = true, health = 3},
        {x = 12, y = 10, alive = true, health = 3}
    }
    
    -- Weapon
    weapon = {
        shooting = false,
        shootTime = 0,
        shootDuration = 0.1
    }
    
    -- Particles for shooting
    particles = {}
end

function love.update(dt)
    -- Movement
    local moveX, moveY = 0, 0
    
    if love.keyboard.isDown('w') then
        moveX = moveX + math.cos(player.angle) * player.speed * dt
        moveY = moveY + math.sin(player.angle) * player.speed * dt
    end
    if love.keyboard.isDown('s') then
        moveX = moveX - math.cos(player.angle) * player.speed * dt
        moveY = moveY - math.sin(player.angle) * player.speed * dt
    end
    if love.keyboard.isDown('a') then
        moveX = moveX + math.cos(player.angle - math.pi/2) * player.speed * dt
        moveY = moveY + math.sin(player.angle - math.pi/2) * player.speed * dt
    end
    if love.keyboard.isDown('d') then
        moveX = moveX + math.cos(player.angle + math.pi/2) * player.speed * dt
        moveY = moveY + math.sin(player.angle + math.pi/2) * player.speed * dt
    end
    
    -- Collision detection
    local newX = player.x + moveX
    local newY = player.y + moveY
    
    if map[math.floor(newY)][math.floor(newX)] == 0 then
        player.x = newX
        player.y = newY
    end
    
    -- Update weapon
    if weapon.shooting then
        weapon.shootTime = weapon.shootTime + dt
        if weapon.shootTime >= weapon.shootDuration then
            weapon.shooting = false
            weapon.shootTime = 0
        end
    end
    
    -- Update particles
    for i = #particles, 1, -1 do
        particles[i].life = particles[i].life - dt
        if particles[i].life <= 0 then
            table.remove(particles, i)
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    player.angle = player.angle + dx * player.rotSpeed
end

function love.mousepressed(x, y, button)
    if button == 1 and not weapon.shooting then
        weapon.shooting = true
        weapon.shootTime = 0
        
        -- Check if we hit an enemy
        local hitEnemy = checkShot()
        if hitEnemy then
            -- Create hit particles
            for i = 1, 10 do
                table.insert(particles, {
                    x = math.random(screenWidth/2 - 50, screenWidth/2 + 50),
                    y = math.random(screenHeight/2 - 50, screenHeight/2 + 50),
                    vx = math.random(-100, 100),
                    vy = math.random(-100, 100),
                    life = 0.3
                })
            end
        end
    end
end

function checkShot()
    -- Simple raycast to check if we hit an enemy in crosshair
    local closestDist = math.huge
    local hitEnemy = nil
    
    for i, enemy in ipairs(enemies) do
        if enemy.alive then
            local dx = enemy.x - player.x
            local dy = enemy.y - player.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            local angleToEnemy = math.atan2(dy, dx)
            local angleDiff = math.abs(normalizeAngle(angleToEnemy - player.angle))
            
            if angleDiff < 0.1 and dist < closestDist then
                closestDist = dist
                hitEnemy = enemy
            end
        end
    end
    
    if hitEnemy then
        hitEnemy.health = hitEnemy.health - 1
        if hitEnemy.health <= 0 then
            hitEnemy.alive = false
        end
        return true
    end
    return false
end

function normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2*math.pi end
    while angle < -math.pi do angle = angle + 2*math.pi end
    return angle
end

function love.draw()
    -- Draw ceiling
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle('fill', 0, 0, screenWidth, screenHeight/2)
    
    -- Draw floor
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle('fill', 0, screenHeight/2, screenWidth, screenHeight/2)
    
    -- Raycasting
    local numRays = 120
    local rayAngleStep = player.fov / numRays
    
    for i = 0, numRays - 1 do
        local rayAngle = player.angle - player.fov/2 + i * rayAngleStep
        local hit, distance, side = castRay(rayAngle)
        
        if hit then
            -- Fix fish-eye effect
            distance = distance * math.cos(rayAngle - player.angle)
            
            local wallHeight = (screenHeight / distance) * 0.5
            local wallTop = screenHeight/2 - wallHeight/2
            
            -- Color based on side
            if side == 'horizontal' then
                love.graphics.setColor(0.6, 0.6, 0.7)
            else
                love.graphics.setColor(0.4, 0.4, 0.5)
            end
            
            local stripWidth = screenWidth / numRays
            love.graphics.rectangle('fill', i * stripWidth, wallTop, stripWidth + 1, wallHeight)
        end
    end
    
    -- Draw enemies
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            drawEnemy(enemy)
        end
    end
    
    -- Draw weapon
    drawWeapon()
    
    -- Draw particles
    love.graphics.setColor(1, 1, 0)
    for _, p in ipairs(particles) do
        love.graphics.circle('fill', p.x, p.y, 3)
    end
    
    -- Draw crosshair
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('line', screenWidth/2, screenHeight/2, 5)
    love.graphics.line(screenWidth/2 - 10, screenHeight/2, screenWidth/2 + 10, screenHeight/2)
    love.graphics.line(screenWidth/2, screenHeight/2 - 10, screenWidth/2, screenHeight/2 + 10)
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD to move, Mouse to look, Click to shoot", 10, 10)
    love.graphics.print("Enemies alive: " .. countAliveEnemies(), 10, 30)
end

function castRay(angle)
    local rayX = player.x
    local rayY = player.y
    local rayDirX = math.cos(angle)
    local rayDirY = math.sin(angle)
    
    local stepSize = 0.02
    local maxDist = 20
    
    for i = 1, maxDist/stepSize do
        rayX = rayX + rayDirX * stepSize
        rayY = rayY + rayDirY * stepSize
        
        local mapX = math.floor(rayX)
        local mapY = math.floor(rayY)
        
        if mapY >= 1 and mapY <= #map and mapX >= 1 and mapX <= #map[1] then
            if map[mapY][mapX] == 1 then
                local distance = math.sqrt((rayX - player.x)^2 + (rayY - player.y)^2)
                
                -- Determine which side was hit
                local side = 'horizontal'
                if math.abs(rayX - mapX - 0.5) < math.abs(rayY - mapY - 0.5) then
                    side = 'vertical'
                end
                
                return true, distance, side
            end
        end
    end
    
    return false, maxDist, 'none'
end

function drawEnemy(enemy)
    local dx = enemy.x - player.x
    local dy = enemy.y - player.y
    local distance = math.sqrt(dx*dx + dy*dy)
    
    local angleToEnemy = math.atan2(dy, dx)
    local angleDiff = normalizeAngle(angleToEnemy - player.angle)
    
    -- Check if enemy is in front of player
    if math.abs(angleDiff) < player.fov/2 + 0.5 then
        -- Check if enemy is behind a wall
        local visible = true
        local hit, hitDist = castRay(angleToEnemy)
        if hit and hitDist < distance then
            visible = false
        end
        
        if visible then
            local screenX = screenWidth/2 + (angleDiff / player.fov) * screenWidth
            local size = (screenHeight / distance) * 0.3
            
            -- Draw enemy sprite
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.circle('fill', screenX, screenHeight/2, size/2)
            love.graphics.setColor(0.6, 0.1, 0.1)
            love.graphics.circle('fill', screenX - size/4, screenHeight/2 - size/4, size/6)
            love.graphics.circle('fill', screenX + size/4, screenHeight/2 - size/4, size/6)
        end
    end
end

function drawWeapon()
    local baseY = screenHeight - 100
    local offsetY = weapon.shooting and -20 or 0
    
    -- Gun body
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle('fill', screenWidth/2 - 30, baseY + offsetY, 60, 80)
    
    -- Gun barrel
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('fill', screenWidth/2 - 15, baseY + offsetY - 40, 30, 40)
    
    -- Muzzle flash
    if weapon.shooting then
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.circle('fill', screenWidth/2, baseY + offsetY - 40, 20)
        love.graphics.setColor(1, 0.5, 0, 0.6)
        love.graphics.circle('fill', screenWidth/2, baseY + offsetY - 40, 30)
    end
end

function countAliveEnemies()
    local count = 0
    for _, enemy in ipairs(enemies) do
        if enemy.alive then count = count + 1 end
    end
    return count
end