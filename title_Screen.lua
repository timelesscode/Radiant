local title_Screen = {}

title_Screen.button = {x=330, y=300, w=160, h=40}

function title_Screen.load() end
function title_Screen.update(dt) end

function title_Screen.draw()
    love.graphics.clear(0.1,0.1,0.1)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("PROJECT RADIANT", 0, 150, 800, "center")
    love.graphics.rectangle("line", title_Screen.button.x, title_Screen.button.y, title_Screen.button.w, title_Screen.button.h)
    love.graphics.printf("START", 0, title_Screen.button.y + 10, 800, "center")
end

function title_Screen.mousepressed(x, y, button)
    if button==1 then
        if x>title_Screen.button.x and x<title_Screen.button.x + title_Screen.button.w and
           y>title_Screen.button.y and y<title_Screen.button.y + title_Screen.button.h then
            local fighter = require("scenes.fighter")
            scene_Manager:switch(fighter)
        end
    end
end

return space_Tutorial
