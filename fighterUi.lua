-- FF8-inspired UI overlay
function drawUI()
    local padding = 10
    local barWidth = 220
    local barHeight = 18
    local startX = 20
    local startY = 20

    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", startX - 10, startY - 10, barWidth + 160, 120, 8)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", startX - 10, startY - 10, barWidth + 160, 120, 8)

    -- Player name and level
    love.graphics.setColor(1,1,1)
    love.graphics.print(classes[player.class].name .. "  Lv." .. player.level, startX, startY)

    -- HP Bar
    local hpX = startX
    local hpY = startY + 25
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", hpX, hpY, barWidth, barHeight, 4)
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.rectangle("fill", hpX, hpY, (player.hp / player.maxHp) * barWidth, barHeight, 4)
    love.graphics.setColor(1,1,1)
    love.graphics.print("HP: " .. math.floor(player.hp) .. " / " .. player.maxHp, hpX + 5, hpY + 2)

    -- Ability / Limit Bar
    local limitX = startX
    local limitY = hpY + barHeight + padding
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", limitX, limitY, barWidth, barHeight, 4)

    if player.abilityReady then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Ability: READY!", limitX + barWidth + 5, limitY + 2)
        love.graphics.rectangle("fill", limitX, limitY, barWidth, barHeight, 4)
    else
        love.graphics.setColor(1, 0.7, 0)
        local cooldownRatio = 1 - player.abilityCooldown / player.abilityMaxCooldown
        love.graphics.rectangle("fill", limitX, limitY, cooldownRatio * barWidth, barHeight, 4)
        love.graphics.setColor(1,1,1)
        love.graphics.print("Ability: " .. string.format("%.1fs", player.abilityCooldown), limitX + barWidth + 5, limitY + 2)
    end

    -- Optional: MP Bar (if you want) 
    local mpX = startX
    local mpY = limitY + barHeight + padding
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", mpX, mpY, barWidth, barHeight, 4)
    love.graphics.setColor(0,0,1)
    love.graphics.rectangle("fill", mpX, mpY, (player.mp / player.maxMp) * barWidth, barHeight, 4)
    love.graphics.setColor(1,1,1)
    love.graphics.print("MP: " .. player.mp .. " / " .. player.maxMp, mpX + 5, mpY + 2)
    ]]

    -- Wave / Enemies
    love.graphics.setColor(1,1,1)
    love.graphics.print("Wave: " .. wave, 1050, 20)
    love.graphics.print("Defeated: " .. enemiesDefeated .. " / 15", 1000, 45)
    love.graphics.print("Enemies: " .. #enemies .. " / " .. maxEnemiesOnScreen, 1000, 70)
end

return fighterUi