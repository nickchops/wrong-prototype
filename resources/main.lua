
-- app globals

appWidth = director.displayWidth
appHeight = director.displayHeight

minX = -appWidth/2
maxX = appWidth/2
minY = -appHeight/2
maxY = appHeight/2
battleCount = 0

ballRadius = 8

-- Main menu --------------------------------------------------------------------

sceneMainMenu = director:createScene()

function sceneMainMenu:setUp(event) -- must declare member functions after sceneMainMenu itself!
    dbg.print("sceneMainMenu:setUp")
    
    -- adding a label as member of the scene itself allows us to manage it easily
    self.label = director:createLabel({x=appWidth/2, y=appHeight/2, text="Main Menu"})
    self.label.x = self.label.x - self.label.wText/2
    
    system:addEventListener({"touch"}, sceneMainMenu)
end
function sceneMainMenu:tearDown(event)
    dbg.print("sceneMainMenu:tearDown")
    self.label = nil -- good practice to nil unused objects
    
    system:removeEventListener({"touch"}, sceneMainMenu)
end
function sceneMainMenu:touch(event)
    if event.phase == "began" then
        battleCount = battleCount+1
        director:moveToScene(sceneBattle, {transitionType="slideInL", transitionTime=0.5})
    end
end

sceneMainMenu:addEventListener({"setUp", "tearDown"}, sceneMainMenu)

---------------------------------------------------------------------------------

-- Util functions
function NodeDestroy(target)
    target:removeFromParent()
    -- removing node from parent kills it on garbage collection if we have no other reference to it
    -- can later do other clean-up tasks here
end

function VectorFromAngle(angle, size)
    return {x = (math.sin(angle) * size), y = (math.cos(angle) * size)}
end

-- pseudo-class to track a player's info
Player = {}
Player.__index = Player -- meta table to implement a "class" in lua

function Player.Create(id, health)
    local player = {}            -- the new object
    setmetatable(player,Player)  -- make Player handle lookup

    -- initialize the object
    player.id = id -- player is just a table and we're assigning key-value pairs to it
    player.touch = {}
    player.touch.x = nil
    player.touch.y = nil
    player.velocity = 0
    player.moveWithFinger = false
    player.health = health

    player.touchPosDiff = nil
    player.halfHeight = 21 --for detecting collisions
    player.sledColour = nil
    
    -- Visual stuff
    -- Sleds are 8x42 with anchor at "front"
    -- y pos of sled used for movement
    local mirrorX = nil
    local xPos = nil
        
    if id == 1 then
        mirrorX = 1
        player.sledColour = color.fuchsia
        xPos = -appWidth/2 + 20
    else
        mirrorX = -1
        player.sledColour = color.yellow
        xPos = appWidth/2 - 20
    end
		
	-- for now, use cheap labels for health
	player.label = director:createLabel({x=20, y=appHeight-40, text=health})
	player.label.color = player.sledColour
	if id == 2 then player.label.x=appWidth-40 end
	
	player.sled = director:createSprite({x=xPos, y=0, xAnchor=0.5, yAnchor=0.5, source="textures/sledp" .. id .. ".png"})

	-- pre-calculate collision pos for balls to do super-cheap collision detection
	player.collideX = player.sled.x + mirrorX*ballRadius
	player.collideY = player.halfHeight + ballRadius --relative to sled
	
	origin:addChild(player.sled)
	return player
end

function Player:Destroy()
    self.sled:removeFromParent()
    self.label:removeFromParent()
end

-- some functions we'll add later
function Player:AddAmmo(amount)
end

function Player:AddHealth(amount)
end

function Player:Fire(weapon)
end

function Player:TakeHit() -- simple "flash" anim
    tween:to(self.sled, {alpha=0.2, time=0.1})
    tween:to(self.sled, {alpha=1.0, time=0.1, delay=0.1})
    self.health = self.health -1
    if self.health == 0 then
        director:moveToScene(sceneMainMenu, {transitionType="slideInR", transitionTime=0.5})
    end
    
    self.label.text = self.health
end


-- Balls (which we can later re-use for weapons)

Collidable = {}
Collidable.__index = Collidable

function Collidable.Create(objType, xPos, yPos, startVector)
    local collidable = {}
    setmetatable(collidable,Collidable)
    
    if objType == "expander" then
        -- do 
    elseif objType == "heatseeker" then
        -- do
        -- etc
    else
        colour = color.blue

        collidable = director:createSprite({
            x=xPos,
            y=yPos,
            xAnchor=0.5,
            yAnchor=0.5,
            source="textures/wrongball.png"})
            
        tween:from(collidable, {xScale=0, yScale=0, time=0.5}) --simple fade in anim
    end
    collidable.vec = startVector
    collidable.objType = objType
    
    origin:addChild(collidable)
	collidables[collidable.name] = collidable --node.name is a unique ID so we can track balls easily
    return collidable
end

local addBall = function()
    -- we push the ball straight to a global table in create so no need to get a ref here
    Collidable.Create("ball", 0, 0, VectorFromAngle(math.rad(math.random(0,359)), math.random(ballSpeed,ballSpeed+3)))
end

local addNewBall = function(event)
    ballSpeed = ballSpeed + 1
    addBall()
end

local replenishBalls = function(event)
    if ballCreateFlag > 0 then
        ballSpeed = ballSpeed + 0.3
        ballCreateFlag = ballCreateFlag -1
        addBall()
    end
end


-- battle screen -------------------------------------------------------

sceneBattle = director:createScene()

-- update and touch events must have these names for addEventListener to register
-- them for a scene table
function sceneBattle:update(event)

    -- Sled Movement:
    
    -- move exactly with finger while finger is down
    if player1.moveWithFinger == true then
        player1.sled.y = player1.touch.y - player1.touchPosDiff
    else
        -- if finger is up, keep moving but decelerate
        player1.sled.y = player1.sled.y + player1.velocity
        
        if player1.velocity > 0 then
            player1.velocity = player1.velocity - 1
        elseif player1.velocity < 0 then
            player1.velocity = player1.velocity + 1
        end
    end
    
    -- keep within screen bounds
    if player1.sled.y > maxY - player1.halfHeight then
        player1.sled.y = maxY - player1.halfHeight
        player1.velocity = 0
    elseif player1.sled.y < minY + player1.halfHeight then
        player1.sled.y = minY + player1.halfHeight
        player1.velocity = 0
    end
    
    -- Balls:
    for k,obj in pairs(collidables) do
        -- movement:
        obj.y = obj.y + obj.vec.y
        obj.x = obj.x + obj.vec.x
        
        -- super simplistic bounce function. We put the ball on the screen edge rather than moving exactly
        if obj.x > maxX then
            obj.x = maxX
            obj.vec.x = -obj.vec.x
            -- bullets bounce once
            if obj.objType == "bullet" then obj.bulletFlag = 1 end
        end
        if obj.x < minX then
            obj.x = minX
            obj.vec.x = -obj.vec.x
            if obj.objType == "bullet" then obj.bulletFlag = 1 end
        end
        if obj.y > maxY then
            obj.y = maxY
            obj.vec.y = -obj.vec.y
        end
        if obj.y < minY then
            obj.y = minY
            obj.vec.y = -obj.vec.y
        end
        
        -- Collisions (cheap collisions, ignoring fact ball is rounded!)
        for pK,player in pairs(players) do
            playerCollideYTop = player.sled.y + player.collideY
            playerCollideYBot = player.sled.y - player.collideY
            
            if ((player.collideX < 0 and obj.x < player.collideX) or (player.collideX > 0 and obj.x > player.collideX))
                    and obj.y < playerCollideYTop and obj.y > playerCollideYBot then
                
                player:TakeHit()
                local fx = director:createCircle({
                    x=obj.x,y=obj.y,
                    xAnchor=0.5,yAnchor=0.5,
                    radius=ballRadius,
                    color=color.lightBlue, strokeWidth=0})
                origin:addChild(fx)
                tween:to(fx, {radius=ballRadius*3, alpha=0, time=0.3, onComplete=NodeDestroy})

                print("destroy obj " .. obj.name)
                obj:removeFromParent()
                collidables[obj.name] = nil
				
				--replace destroyed ball
                ballCreateFlag = ballCreateFlag + 1
				break
            end
        end
    end
end

function sceneBattle:touch(event)

    event.y = event.y - appHeight/2 --touch 0,0 always bottom left; align with our origin
    
    if event.phase == "began" then
        player1.touch.x = event.x
        player1.touch.y = event.y
        player1.velocity = 0
        player1.touchPosDiff = event.y - player1.sled.y
    end
    
    if event.phase == "ended" then
        player1.moveWithFinger = false
    end
    
    if event.phase == "moved" then
        xDiff = event.x - player1.touch.x
        yDiff = event.y - player1.touch.y
        player1.touch.x = event.x
        player1.touch.y = event.y
        
        player1.moveWithFinger = true
        player1.velocity = yDiff --on finger-off, continue moving (will decelerate)
    end
end

function sceneBattle:setUp(event)
    dbg.print("sceneBattle:setUp")

    -- director:create makes the current scene the parent node. The scene keeps a reference to its children.
    -- director's coordinates (x=,y=) are relative to the parent, i.e. the scene in this case which always
    -- has (0,0) at the bottom left of the screen
    background = director:createRectangle({
        x=0, y=0,
        w=appWidth, h=appHeight,
        strokeWidth=0,
        color=color.black, alpha=1.0,
        })

	-- dummy node at screen centre. A plain node has no visual element. We can add children to make
    -- them relative to it's position. This is the best way to do local coordinate systems in Quick;
    -- don't use parent.xAnchor etc as that's not very flexible or intuitive
    origin = director:createNode({x=appWidth/2, y=appHeight/2})

    math.randomseed(os.time())

    for n=0, 100, 1 do
        -- star is local to a single loop call, but on each call a new vector object is created
        -- Without "local", this would still work, but we'd have to do star=nil at the end or
        -- the final object would still be referenced at the end
        local star = director:createLines({x=math.random(0, appWidth), y=math.random(0, appHeight), coords={0,0, 1,1}, strokeWidth = 1})

        -- set start colour: get a random white value then allow some variance in each channel for off-white result
        local brightness = math.random(20, 127)
        star.strokeColor = {math.random(brightness-20, brightness), math.random(brightness-5, brightness), math.random(brightness-20, brightness)}
        
        background:addChild(star) -- background.children is now a table with references to the star objects
        
        -- star coords are now relative to background. Pointless right now as scene and background
        -- origins are the same! But we can now easily move them all by moving the background
    end

    player1 = Player.Create(1, 5)
    player2 = Player.Create(2, 5)
    
    players = {}
    table.insert(players, player1)
    table.insert(players, player2)

    ballSpeed = 1
    ballCreateFlag = 10 -- queues up balls to add at any time
    
    -- we'll manage ball movement ourselves as its so simple.
    -- could "upgrade" to physics/box2d if needed.    
    collidables = {}
    
    -- main game logic handlers
    system:addEventListener({"touch", "update"}, sceneBattle)
    ballTimer = system:addTimer(addNewBall, 10, 0)
    ballReplaceTimer = system:addTimer(replenishBalls, 0.2, 0)
    
    
    -- debug label to check we're in right scene!
    self.label = director:createLabel({x=appWidth/2, y=30, text="Battle " .. battleCount})
    self.label.x = self.label.x - self.label.wText/2
end

function sceneBattle:tearDown(event)
    dbg.print("sceneBattle:tearDown")
    self.label = nil
    
    for k,v in pairs(background.children) do
        v:removeFromParent() -- take object out of the scene, no references left so lua will garbage collect stars
    end

    system:removeEventListener({"touch", "update"}, sceneBattle)

    ballTimer:cancel()
    ballReplaceTimer:cancel()
    
    if self.ballTimer then
        self.ballTimer:cancel()
        self.ballTimer = nil
    end
    if self.ballReplaceTimer then
        self.ballReplaceTimer:cancel()
        self.ballReplaceTimer = nil
    end
    
    for k,v in pairs(collidables) do
        v:removeFromParent()
        collidables[k]=nil -- quick destruction of array contents. Only safe when removing all values or from the end
    end
    collidables = nil

    for k,v in pairs(players) do
        v:Destroy()
    end
    players = nil
    player1 = nil
    player2 = nil

    background:removeFromParent()
    background = nil
end
sceneBattle:addEventListener({"setUp", "tearDown"}, sceneBattle)

------------------------------------------------------------------------------------

director:moveToScene(sceneMainMenu) -- start game with instantaneous change to main menu (last scene created is current)
