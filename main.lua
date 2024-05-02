--[[
    GD50 2018
    Pong Remake

    pong-final
    "The AI Update"

    -- Main Program --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.

    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on 
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

PADDLE_SPEED = 200
PADDLE_WIDTH = 5
PADDLE_HEIGHT = 20
PADDLE_HORIZONTAL_OFFSET = 10
PADDLE_VERTICAL_OFFSET = 30

BALL_WIDTH = 4
BALL_HEIGHT = 4

MAX_SCORE = 3

-- New game mode selection
gameModes = {'Player vs Player', 'Player vs AI', 'AI vs AI'}
selectedMode = 1

--[[
    Runs when the game first starts up, only once; used to initialize the game.
]]
function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong 2024')

    -- "seed" the RNG so that calls to random are always random
    -- use the current time, since that will vary on startup every time
    math.randomseed(os.time())

    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- A good rule of thumb is to use stream for music files and static for all short sound effects. 
    -- Basically, you want to avoid loading large files into memory at once.
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }

    music = {
        ['retro_platforming'] = love.audio.newSource('sounds/retro_platforming.mp3', 'stream'),
        ['funny_bit'] = love.audio.newSource('sounds/funny_bit.mp3', 'stream')
    }

    -- initialize window with virtual resolution
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    -- initialize score variables, used for rendering on the screen and keeping
    -- track of the winner
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(PADDLE_HORIZONTAL_OFFSET, PADDLE_VERTICAL_OFFSET, PADDLE_WIDTH, PADDLE_HEIGHT)
    player2 = Paddle(VIRTUAL_WIDTH - PADDLE_HORIZONTAL_OFFSET, VIRTUAL_HEIGHT - PADDLE_VERTICAL_OFFSET, PADDLE_WIDTH, PADDLE_HEIGHT)

    -- place a ball in the middle of the screen
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, BALL_WIDTH, BALL_HEIGHT)

    -- the state of our game; can be any of the following:
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    -- 5. 'menu' (the game mode selection menu)
    gameState = 'menu'

    fpsDisplay = false
end

--[[
    Called by LÖVE whenever we resize the screen; here, we just want to pass in the
    width and height to push so our virtual resolution can be resized as needed.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Runs every frame, with "dt" passed in, our delta in seconds 
    since the last frame, which LÖVE2D supplies us.
]]
function love.update(dt)
    if gameState == 'serve' then
        music['retro_platforming']:play()
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            ball.dx = math.random(140, 200)
        else
            ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'play' then
        music['retro_platforming']:play()
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        if ball:collides(player1) then
            ball.dx = -ball.dx * 1.03
            ball.x = player1.x + 5

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end
            sounds['paddle_hit']:play()
        end

        if ball:collides(player2) then
            ball.dx = -ball.dx * 1.03
            ball.x = player2.x - 4

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end
            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision and reverse if collided
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        if ball.y >= VIRTUAL_HEIGHT - BALL_HEIGHT then
            ball.y = VIRTUAL_HEIGHT - BALL_HEIGHT
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left or right edge of the screen,
        -- go back to start and update the score
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()
            -- if we've reached a score of MAX_SCORE, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == MAX_SCORE then
                winningPlayer = 2
                gameState = 'done'
                music['retro_platforming']:stop()
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end
    
        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()
            if player1Score == MAX_SCORE then
                winningPlayer = 1
                gameState = 'done'
                music['retro_platforming']:stop()
            else
                gameState = 'serve'
                ball:reset()
            end
        end
    end

    -- player 1 movement
    if love.keyboard.isDown('w') then
        player1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('s') then
        player1.dy = PADDLE_SPEED
    else
        player1.dy = 0
    end

    -- player 2 movement based on game mode
    if selectedMode == 1 then -- Player vs Player
        if love.keyboard.isDown('up') then
            player2.dy = -PADDLE_SPEED
        elseif love.keyboard.isDown('down') then
            player2.dy = PADDLE_SPEED
        else
            player2.dy = 0
        end
    elseif selectedMode == 2 or selectedMode == 3 then -- Player vs AI or AI vs AI
        -- Introduce a random factor to AI paddle movement to simulate varied movements
        local movementRandomizer = math.random()
        if movementRandomizer > 0.5 then -- 50% chance to follow the ball
            if ball.y < player2.y + PADDLE_HEIGHT / 2 then
                player2.dy = -PADDLE_SPEED
            elseif ball.y > player2.y + PADDLE_HEIGHT / 2  then
                player2.dy = PADDLE_SPEED
            else
                player2.dy = 0
            end
        else
            player2.dy = 0 -- 10% chance to not move, simulating a miss
        end

        -- Implement a mechanism to occasionally adjust AI paddle speed randomly
        if math.random() > 0.85 then -- 15% chance to adjust speed
            player2.dy = player2.dy * math.random(0.5, 1.5)
        end
    end

    -- AI vs AI mode: control player 1 with AI
    if selectedMode == 3 then
        -- Add a condition to randomly decide if the AI should miss the ball
        if math.random() > 0.15 then -- 85% chance to attempt to hit the ball
            if ball.y < player1.y + PADDLE_HEIGHT / 2 then
                player1.dy = -PADDLE_SPEED
            elseif ball.y > player1.y + PADDLE_HEIGHT / 2  then
                player1.dy = PADDLE_SPEED
            else
                player1.dy = 0
            end
        else
            player1.dy = 0 -- 15% chance to not move, simulating a miss
        end
    end

    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

--[[
    Keyboard handling, called by LÖVE2D each frame; 
    passes in the key we pressed so we can access.
]]
function love.keypressed(key)
    if key == 'backspace' then
        -- function LÖVE gives us to terminate application
        love.event.quit()
    -- if we press enter during the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of who won for fairness!
            gameState = 'serve'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        elseif gameState == 'menu' then
            gameState = 'start'
        end
    elseif key == 'tab' then
        fpsDisplay = not fpsDisplay
    elseif gameState == 'menu' then
        if key == 'up' then
            selectedMode = math.max(1, selectedMode - 1)
        elseif key == 'down' then
            selectedMode = math.min(#gameModes, selectedMode + 1)
        end
    end
end

--[[
    Called after update by LÖVE2D, used to draw anything to the screen, 
    updated or otherwise.
]]
function love.draw()
    -- begin rendering at virtual resolution
    push:apply('start')

    -- clear the screen with a specific color; in this case, a color similar
    -- to some versions of the original Pong
    love.graphics.clear(40/255, 45/255, 52/255, 255/255)

    -- draw welcome text toward the top of the screen
    love.graphics.setFont(smallFont)

    displayScore()

    if gameState == 'start' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' wins!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'menu' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Select Game Mode:', 0, 10, VIRTUAL_WIDTH, 'center')
        for i, mode in ipairs(gameModes) do
            if i == selectedMode then
                love.graphics.setColor(0, 255, 0, 255)
            else
                love.graphics.setColor(255, 255, 255, 255)
            end
            love.graphics.printf(mode, 0, 20 + i * 10, VIRTUAL_WIDTH, 'center')
        end
        love.graphics.setColor(255, 255, 255, 255)
    end

    love.graphics.setColor(255,0,0)
    player1:render()
    love.graphics.setColor(0,255,0)
    player2:render()
    love.graphics.setColor(0,0,255)
    ball:render()
    -- reset colours
    love.graphics.setColor(255,255,255)
    

    if fpsDisplay then
        displayFPS()
    end

    -- end rendering at virtual resolution
    push:apply('end')
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255/255, 0, 255/255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end

--[[
    Simply draws the score to the screen.
]]
function displayScore()
    -- draw score on the left and right center of the screen
    -- need to switch font to draw before actually printing
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50, 
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end
