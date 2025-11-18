--UI
-- main.lua
function love.load()
    -- Example party data
    party = {
        {name="Squall", hp=1200, maxHp=1500, mp=200, maxMp=300, limit=50, maxLimit=100},
        {name="Rinoa", hp=800, maxHp=1200, mp=400, maxMp=500, limit=30, maxLimit=100}
    }

    font = love.graphics.newFont(14)
    love.graphics.setFont(font)
end

function drawBar(x, y, width, height, value, maxValue, color)
    love.graphics.setColor(0.2, 0.2, 0.2) -- BG
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(color) -- Bar
    love.graphics.rectangle("fill", x, y, (value/maxValue) * width, height)
    love.graphics.setColor(1,1,1) -- Reset color
end

function love.draw()
    local startX = 20
    local startY = 20
    local barWidth = 200
    local barHeight = 15
    local padding = 10

    for i, char in ipairs(party) do
        local y = startY + (i-1)*(barHeight*3 + padding*3)
        -- Name
        love.graphics.print(char.name, startX, y)
        -- HP bar
        drawBar(startX, y + 20, barWidth, barHeight, char.hp, char.maxHp, {1,0,0})
        love.graphics.print(char.hp.."/"..char.maxHp, startX + barWidth + 5, y + 20)
        -- MP bar
        drawBar(startX, y + 40, barWidth, barHeight, char.mp, char.maxMp, {0,0,1})
        love.graphics.print(char.mp.."/"..char.maxMp, startX + barWidth + 5, y + 40)
        -- Limit bar
        drawBar(startX, y + 60, barWidth, barHeight, char.limit, char.maxLimit, {1,1,0})
        love.graphics.print("Limit: "..char.limit.."/"..char.maxLimit, startX + barWidth + 5, y + 60)
    end

    -- Example menu overlay
    love.graphics.setColor(0,0,0,0.6)
    love.graphics.rectangle("fill", 400, 300, 200, 120)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Attack\nMagic\nItem\nDefend", 410, 310)
end
