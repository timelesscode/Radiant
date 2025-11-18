-- player.lua
local Assets = require("assets")  -- load sprites/assets here if needed

local Player = {}

-- ===============================
-- Core Attributes
-- ===============================
Player.mode = "onFoot"  -- "onFoot" or "ship"

-- Stats shared across both modes
Player.level = 1
Player.exp = 0
Player.expToNext = 100
Player.score = 0
Player.polarity = "blue"

-- ===============================
-- On-Foot Mode
-- ===============================
Player.onFoot = {
    entity = nil,          -- will hold the Entity object
    hp = 3,
    maxHp = 3,
    speed = 150,
    weapons = {
        melee = {level = 1, unlocked = true},
        ranged = {level = 0, unlocked = false},
    },
    items = {},            -- collectable items affecting on-foot stats
}

-- ===============================
-- Ship Mode
-- ===============================
Player.ship = {
    entity = nil,          -- Entity object for spaceship
    hp = 3,
    maxHp = 3,
    speed = 200,
    fireRate = 0.15,
    damage = 1,
    sprite = Assets.playerShip,  -- assign spaceship sprite
    weapons = {
        spread = {level = 1, unlocked = true},
        laser = {level = 0, unlocked = false},
        homing = {level = 0, unlocked = false},
    },
    items = {},            -- collectable items affecting ship stats
}

-- ===============================
-- Inventory / Items
-- ===============================
Player.inventory = {
    onFootItems = {},
    shipItems = {},
}

function Player:addItem(item)
    if item.type == "onFoot" then
        table.insert(Player.inventory.onFootItems, item)
        -- apply item effects
        if item.apply then item.apply(Player.onFoot) end
    elseif item.type == "ship" then
        table.insert(Player.inventory.shipItems, item)
        if item.apply then item.apply(Player.ship) end
    end
end

-- ===============================
-- Mode Switching
-- ===============================
function Player:switchMode(mode)
    if mode == "onFoot" or mode == "ship" then
        self.mode = mode
    end
end

function Player:getCurrent()
    if self.mode == "onFoot" then
        return self.onFoot
    else
        return self.ship
    end
end

-- ===============================
-- Reset / Initialize
-- ===============================
function Player:initialize()
    -- On foot entity
    self.onFoot.entity = {
        x = 400,
        y = 500,
        vx = 0,
        vy = 0,
        radius = 12,
        alive = true,
        hp = self.onFoot.hp,
        maxHp = self.onFoot.maxHp,
        color = {0.3, 0.7, 1},
    }

    -- Ship entity
    self.ship.entity = {
        x = 400,
        y = 500,
        vx = 0,
        vy = 0,
        radius = 12,
        alive = true,
        hp = self.ship.hp,
        maxHp = self.ship.maxHp,
        color = {0.3, 0.7, 1},
        sprite = self.ship.sprite
    }
end

-- ===============================
-- Update
-- ===============================
function Player:update(dt)
    local current = self:getCurrent()
    -- Basic movement physics
    current.x = current.x + (current.vx or 0) * dt
    current.y = current.y + (current.vy or 0) * dt
end

-- ===============================
-- Draw
-- ===============================
function Player:draw()
    local current = self:getCurrent()
    if self.mode == "ship" and current.sprite then
        local w, h = current.sprite:getWidth(), current.sprite:getHeight()
        local scale = 48 / w  -- adjust to desired size
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(current.sprite, current.x, current.y, 0, scale, scale, w/2, h/2)
    else
        -- on foot: simple circle for now
        love.graphics.setColor(current.color)
        love.graphics.circle("fill", current.x, current.y, current.radius)
    end
end

return Player
