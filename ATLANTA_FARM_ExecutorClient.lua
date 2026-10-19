--[[
  PHANTOM / MM2 — CANDY ENGINE 4.0
  Completely rebuilt GUI; previous Halloween UI is not used.
  IMPORTANT: Run the CONTENTS of this file, not an old GitHub loadstring.
  This is a client-side script: physics flinging and game events are best effort.
]]
print('[PHANTOM V4] BOOT START — this is NOT the old Halloween menu')

local function boot()
    local Players = game:GetService('Players')
    local TweenService = game:GetService('TweenService')
    local UserInputService = game:GetService('UserInputService')
    local RunService = game:GetService('RunService')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local VirtualUser = game:GetService('VirtualUser')
    local player = Players.LocalPlayer
    if not player then
        local since = os.clock()
        repeat task.wait(0.1); player = Players.LocalPlayer until player or os.clock()-since > 12
    end
    assert(player, '[PHANTOM V4] LocalPlayer missing')
    local playerGui = player:WaitForChild('PlayerGui', 12)
    assert(playerGui, '[PHANTOM V4] PlayerGui missing')

    local globalEnv = nil
    pcall(function() if type(getgenv) == 'function' then globalEnv = getgenv() end end)
    if globalEnv and type(globalEnv.PHANTOM_MM2_SHUTDOWN) == 'function' then
        pcall(globalEnv.PHANTOM_MM2_SHUTDOWN)
    end

    local scopes = {playerGui}
    pcall(function() table.insert(scopes, game:GetService('CoreGui')) end)
    pcall(function()
        if type(gethui) == 'function' then
            local ui = gethui()
            if ui then table.insert(scopes, ui) end
        end
    end)
    for _, scope in ipairs(scopes) do
        for _, name in ipairs({'HalloweenAutofarm', 'HalloweenAutofarmV3', 'PHANTOM_MM2_V4'}) do
            local old = scope:FindFirstChild(name)
            if old then pcall(function() old:Destroy() end) end
        end
    end

    local state = {alive = true, connections = {}, move = nil, moving = false,
        float = nil, attachment = nil, collision = {}, ignored = {},
        active = false, resetting = false, endGame = false, version = '4.0'}
    local cfg = {farm = false, speed = 25, avoid = true, antiFling = true,
        autoReset = true, autoEnd = false, antiAFK = true}
    local bag, lifetime, startTime = 0, 0, os.clock()
    local roundActive, lastRoundEnd = false, -math.huge
    local murderer = nil
    local lastReset = -math.huge

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(state.connections, c)
        return c
    end
    local function make(kind, props, parent)
        local o = Instance.new(kind)
        for k, v in pairs(props or {}) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local P = {
        bg = Color3.fromRGB(11, 16, 24), panel = Color3.fromRGB(20, 28, 40),
        card = Color3.fromRGB(25, 35, 49), alt = Color3.fromRGB(33, 45, 61),
        edge = Color3.fromRGB(53, 69, 84), text = Color3.fromRGB(238, 247, 250),
        muted = Color3.fromRGB(143, 163, 180),
        mint = Color3.fromRGB(64, 232, 197), green = Color3.fromRGB(111, 232, 159),
        red = Color3.fromRGB(255, 119, 129), off = Color3.fromRGB(72, 86, 103),
    }
    local function round(obj, n)
        make('UICorner', {CornerRadius=UDim.new(0, n or 10)}, obj)
        return obj
    end
    local function outline(obj, color, transparency)
        return make('UIStroke', {Color=color or P.edge, Thickness=1,
            Transparency=transparency or 0.3, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, obj)
    end
    local function tween(obj, seconds, props)
        local t = TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end
    local function label(parent, value, pos, size, txtSize, color, bold)
        return make('TextLabel', {Text=tostring(value), Position=pos, Size=size,
            BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center, TextWrapped=false,
            Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextSize=txtSize or 12, TextColor3=color or P.text}, parent)
    end
    local function frame(parent, pos, size, color, radius)
        local f = make('Frame', {Position=pos, Size=size, BackgroundColor3=color or P.card,
            BorderSizePixel=0}, parent)
        if radius then round(f, radius) end
        return f
    end
    local gui = make('ScreenGui', {Name='PHANTOM_MM2_V4', ResetOnSpawn=false,
        IgnoreGuiInset=true, DisplayOrder=999999, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
    state.gui = gui
    local W, H = 382, 486
    local shadow = frame(gui, UDim2.new(0.5, -W/2-7, 0.5, -H/2),
        UDim2.fromOffset(W+14, H+17), Color3.fromRGB(0,0,0), 22)
    shadow.BackgroundTransparency=0.42
    local win = frame(gui, UDim2.fromScale(0.5,0.5), UDim2.fromOffset(W,H), P.bg, 20)
    win.Name='PHANTOM_Window'; win.AnchorPoint=Vector2.new(0.5,0.5)
    win.ClipsDescendants=true; win.Active=true
    outline(win, P.edge, 0.13)
    shadow.AnchorPoint=Vector2.new(0.5,0.5)
    shadow.Position=UDim2.new(0.5,0,0.5,7)
    local accent = frame(win, UDim2.fromOffset(18,13), UDim2.fromOffset(4,34), P.mint, 2)
    local header = frame(win, UDim2.fromOffset(0,0), UDim2.new(1,0,0,70), P.bg)
    header.BackgroundTransparency=1; header.Active=true
    accent.Parent=header
    local brand = label(header,'PHANTOM',UDim2.fromOffset(33,11),UDim2.fromOffset(183,24),20,P.text,true)
    brand.Name='Brand'
    label(header,'MM2  /  CANDY ENGINE',UDim2.fromOffset(34,36),UDim2.fromOffset(220,16),10,P.muted,true)
    local collapse = make('TextButton',{Name='Minimize',Position=UDim2.new(1,-87,0,17),
        Size=UDim2.fromOffset(30,30), Text='−', TextSize=21,Font=Enum.Font.GothamBold,
        TextColor3=P.muted,BackgroundColor3=P.panel,BorderSizePixel=0,AutoButtonColor=false},header)
    round(collapse,9)
    local close = make('TextButton',{Name='Close',Position=UDim2.new(1,-51,0,17),
        Size=UDim2.fromOffset(30,30),Text='×',TextSize=20,Font=Enum.Font.GothamBold,
        TextColor3=P.text,BackgroundColor3=P.panel,BorderSizePixel=0,AutoButtonColor=false},header)
    round(close,9)
    local line = frame(win,UDim2.fromOffset(18,68),UDim2.new(1,-36,0,1),P.edge)
    line.BackgroundTransparency=0.5

    local tabBackground = frame(win, UDim2.fromOffset(18,83), UDim2.new(1,-36,0,45),P.panel,12)
    local tabs, pages = {}, {}
    local names = {'FARM','DEFENSE','SESSION'}
    local currentTab = 'FARM'
    for i,name in ipairs(names) do
        local btn = make('TextButton',{Name=name..'_TAB',Position=UDim2.new((i-1)/3,4,0,5),
            Size=UDim2.new(1/3,-8,0,35),BackgroundColor3=i==1 and P.mint or P.panel,
            Text=name,TextSize=11,Font=Enum.Font.GothamBold,
            TextColor3=i==1 and P.bg or P.muted,BorderSizePixel=0,AutoButtonColor=false},tabBackground)
        round(btn,9)
        tabs[name]=btn
    end
    for _,name in ipairs(names) do
        local page = make('ScrollingFrame',{Name=name..'_PAGE',
            Position=UDim2.fromOffset(18,139),Size=UDim2.new(1,-36,1,-197),
            BackgroundTransparency=1,BorderSizePixel=0,Active=true,
            ScrollingDirection=Enum.ScrollingDirection.Y,
            ScrollBarThickness=3,ScrollBarImageColor3=P.mint,
            CanvasSize=UDim2.fromOffset(0,0),Visible=name==currentTab},win)
        make('UIPadding',{PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,8),
            PaddingLeft=UDim.new(0,1),PaddingRight=UDim.new(0,7)},page)
        local layout=make('UIListLayout',{Padding=UDim.new(0,10),
            SortOrder=Enum.SortOrder.LayoutOrder},page)
        connect(layout:GetPropertyChangedSignal('AbsoluteContentSize'),function()
            page.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+15)
        end)
        pages[name]={page=page,next=0}
    end
    local function selectTab(name)
        currentTab=name
        for n,btn in pairs(tabs) do
            pages[n].page.Visible=n==name
            tween(btn,0.13,{BackgroundColor3=n==name and P.mint or P.panel,
                TextColor3=n==name and P.bg or P.muted})
        end
    end
    for n,btn in pairs(tabs) do
        btn.MouseButton1Click:Connect(function() selectTab(n) end)
    end
    local footer = frame(win,UDim2.new(0,18,1,-46),UDim2.new(1,-36,0,34),P.panel,9)
    local dot=frame(footer,UDim2.fromOffset(10,14),UDim2.fromOffset(7,7),P.muted,4)
    local statusText=label(footer,'READY / Waiting',UDim2.fromOffset(23,4),
        UDim2.new(1,-84,0,26),11,P.muted,false)
    local ver=label(footer,'v4.0',UDim2.new(1,-59,0,4),UDim2.fromOffset(53,26),11,P.mint,true)
    ver.TextXAlignment=Enum.TextXAlignment.Right
    local function status(s, kind)
        if not state.alive then return end
        statusText.Text=s
        dot.BackgroundColor3=kind=='ok' and P.green or kind=='warn' and P.red
            or kind=='work' and P.mint or P.muted
    end
    local function card(tab, height)
        local entry=pages[tab]
        entry.next=entry.next+1
        local f=frame(entry.page,UDim2.fromOffset(0,0),
            UDim2.new(1,-1,0,height),P.panel,12)
        f.LayoutOrder=entry.next
        outline(f,P.edge,0.57)
        return f
    end
    local function titleCard(tab,title,detail)
        local f=card(tab,54)
        f.BackgroundTransparency=1
        label(f,title,UDim2.fromOffset(5,0),UDim2.new(1,-10,0,26),16,P.text,true)
        label(f,detail,UDim2.fromOffset(5,27),UDim2.new(1,-10,0,17),11,P.muted)
    end
    local function pillToggle(parent, initial, changed)
        local btn = make('TextButton',{Position=UDim2.new(1,-65,0.5,-14),
            Size=UDim2.fromOffset(52,28),BackgroundColor3=initial and P.mint or P.off,
            BorderSizePixel=0,Text='',AutoButtonColor=false},parent)
        round(btn,14)
        local knob=frame(btn,initial and UDim2.new(1,-25,0,4) or UDim2.fromOffset(4,4),
            UDim2.fromOffset(20,20), P.bg,10)
        local value=initial
        btn.MouseButton1Click:Connect(function()
            value=not value
            tween(btn,0.12,{BackgroundColor3=value and P.mint or P.off})
            tween(knob,0.12,{Position=value and UDim2.new(1,-25,0,4) or UDim2.fromOffset(4,4)})
            changed(value)
        end)
        return btn
    end
    local function setting(tab,name,desc,on,change)
        local f=card(tab,63)
        label(f,name,UDim2.fromOffset(14,9),UDim2.new(1,-92,0,23),13,P.text,true)
        label(f,desc,UDim2.fromOffset(14,34),UDim2.new(1,-92,0,15),10,P.muted)
        pillToggle(f,on,change)
        return f
    end
    local function metric(tab,name,value)
        local f=card(tab,54)
        label(f,name,UDim2.fromOffset(13,9),UDim2.new(0.58,0,0,36),12,P.muted)
        local out=label(f,tostring(value),UDim2.new(0.58,0,0,9),
            UDim2.new(0.42,-13,0,36),15,P.mint,true)
        out.TextXAlignment=Enum.TextXAlignment.Right
        return out
    end

    -- FARM PAGE: a hero control + bag indicator + adjustable slider.
    local hero = card('FARM',117)
    hero.BackgroundColor3=P.card
    label(hero,'AUTO COLLECT',UDim2.fromOffset(15,10),UDim2.new(1,-102,0,27),15,P.text,true)
    label(hero,'Smart candy navigation',UDim2.fromOffset(15,35),
        UDim2.new(1,-102,0,18),11,P.muted)
    pillToggle(hero,cfg.farm,function(v)
        cfg.farm=v
        status(v and 'SEARCHING / Candy' or 'READY / Waiting',v and 'work' or nil)
    end)
    local progressBase=frame(hero,UDim2.fromOffset(15,84),UDim2.new(1,-99,0,8),P.off,4)
    local progressFill=frame(progressBase,UDim2.fromOffset(0,0),UDim2.fromScale(0,1),P.mint,4)
    local bagLabel=label(hero,'0 / 50',UDim2.new(1,-78,0,76),
        UDim2.fromOffset(65,23),12,P.mint,true)
    bagLabel.TextXAlignment=Enum.TextXAlignment.Right
    local tip=card('FARM',45)
    label(tip,'MODE',UDim2.fromOffset(14,8),UDim2.fromOffset(59,27),10,P.muted,true)
    local targetLabel=label(tip,'Standing by',UDim2.fromOffset(75,8),
        UDim2.new(1,-88,0,27),12,P.text,true)
    local sliderBox=card('FARM',100)
    label(sliderBox,'FLIGHT SPEED',UDim2.fromOffset(14,10),
        UDim2.new(1,-104,0,26),13,P.text,true)
    local speedLabel=label(sliderBox,tostring(cfg.speed),UDim2.new(1,-63,0,9),
        UDim2.fromOffset(48,27),16,P.mint,true)
    speedLabel.TextXAlignment=Enum.TextXAlignment.Right
    local track=frame(sliderBox,UDim2.fromOffset(16,63),
        UDim2.new(1,-32,0,7),P.off,4)
    local fill=frame(track,UDim2.fromOffset(0,0),
        UDim2.new((cfg.speed-1)/99,0,1,0),P.mint,4)
    local handle=frame(track,UDim2.new((cfg.speed-1)/99,0,0.5,-9),
        UDim2.fromOffset(18,18),P.text,9)
    outline(handle,P.mint,0.1)
    local hit=make('TextButton',{Position=UDim2.fromOffset(0,-16),
        Size=UDim2.new(1,0,0,38),Text='',BackgroundTransparency=1,
        AutoButtonColor=false},track)
    local movingSlider=false
    local function updateSpeed(pos)
        if track.AbsoluteSize.X<1 then return end
        local ratio=math.clamp((pos-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        cfg.speed=math.floor(1+99*ratio+0.5)
        speedLabel.Text=tostring(cfg.speed)
        ratio=(cfg.speed-1)/99
        fill.Size=UDim2.new(ratio,0,1,0)
        handle.Position=UDim2.new(ratio,0,0.5,-9)
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then
            movingSlider=true; updateSpeed(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if movingSlider and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            updateSpeed(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then movingSlider=false end
    end)
    local farmHint=card('FARM',60)
    label(farmHint,'AUTO ROUTING',UDim2.fromOffset(13,7),
        UDim2.new(1,-25,0,24),12,P.mint,true)
    label(farmHint,'Flight adjusts to threats and morphs.',
        UDim2.fromOffset(13,29),UDim2.new(1,-25,0,21),11,P.muted)

    -- DEFENSE PAGE
    titleCard('DEFENSE','PROTECTION','Movement, survival and bag management')
    setting('DEFENSE','Avoid Murderer','Fly to safer candy clusters',cfg.avoid,function(v) cfg.avoid=v end)
    setting('DEFENSE','Anti Fling','Block unwanted physics spikes',cfg.antiFling,function(v) cfg.antiFling=v end)
    setting('DEFENSE','Auto Reset 50/50','Reset when the bag reaches 50',cfg.autoReset,function(v) cfg.autoReset=v end)
    setting('DEFENSE','Auto End Game · BETA','Try physics interaction after reset',cfg.autoEnd,function(v) cfg.autoEnd=v end)
    setting('DEFENSE','Anti AFK','Prevent idle timeout',cfg.antiAFK,function(v) cfg.antiAFK=v end)

    -- SESSION PAGE
    titleCard('SESSION','LIVE SESSION','Collection statistics and diagnostics')
    local statBag=metric('SESSION','Current candy bag','0 / 50')
    local statTotal=metric('SESSION','Candy pickups',0)
    local statRound=metric('SESSION','Round','Waiting')
    local statChar=metric('SESSION','Character','Unknown')
    local statTime=metric('SESSION','Active time','0m 0s')
    local statVersion=metric('SESSION','Interface','PHANTOM v4.0')
    statVersion.TextSize=11
    local function showBag()
        local text=tostring(bag)..' / 50'
        bagLabel.Text=text; statBag.Text=text
        tween(progressFill,0.18,{Size=UDim2.new(math.clamp(bag/50,0,1),0,1,0)})
        statTotal.Text=tostring(lifetime)
    end

    -- Header drag, with a screen-fit UI scale for phone screens.
    local scale=make('UIScale',{Scale=1},win)
    local shadeScale=make('UIScale',{Scale=1},shadow)
    local function fit()
        local camera=workspace.CurrentCamera
        if camera then
            local viewport=camera.ViewportSize
            local s=math.clamp(math.min((viewport.X-22)/W,(viewport.Y-32)/H),0.52,1)
            scale.Scale=s; shadeScale.Scale=s
        end
    end
    fit()
    local viewCamera=workspace.CurrentCamera
    if viewCamera then connect(viewCamera:GetPropertyChangedSignal('ViewportSize'),fit) end
    local dragging,origin,from=false,nil,nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and
           input.UserInputType~=Enum.UserInputType.Touch then return end
        local pt=input.Position
        if pt.X >= collapse.AbsolutePosition.X-4 then return end
        dragging=true; origin=pt; from=win.Position
    end)
    connect(UserInputService.InputChanged,function(input)
        if not dragging or not from then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and
            input.UserInputType~=Enum.UserInputType.Touch then return end
        local d=input.Position-origin
        local x=from.X.Offset+d.X/(scale.Scale)
        local y=from.Y.Offset+d.Y/(scale.Scale)
        win.Position=UDim2.new(from.X.Scale,x,from.Y.Scale,y)
        shadow.Position=UDim2.new(win.Position.X.Scale,win.Position.X.Offset,win.Position.Y.Scale,win.Position.Y.Offset+7)
    end)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    local collapsed=false
    collapse.MouseButton1Click:Connect(function()
        collapsed=not collapsed
        collapse.Text=collapsed and '+' or '−'
        tabBackground.Visible=not collapsed; line.Visible=not collapsed
        footer.Visible=not collapsed
        for n,data in pairs(pages) do data.page.Visible=not collapsed and n==currentTab end
        tween(win,0.19,{Size=UDim2.fromOffset(W,collapsed and 70 or H)})
        tween(shadow,0.19,{Size=UDim2.fromOffset(W+14,(collapsed and 70 or H)+17)})
    end)

    -- Movement and game logic are kept separate from GUI setup.
    local function ch() return player.Character end
    local function root()
        local c=ch()
        if not c then return nil end
        return c:FindFirstChild('HumanoidRootPart') or c:FindFirstChild('UpperTorso')
            or c:FindFirstChild('Torso') or c.PrimaryPart
    end
    local function humanoid()
        local c=ch()
        local h=c and c:FindFirstChildOfClass('Humanoid')
        if not h or h.Health<=0 then return nil end
        return h
    end
    local function stopMove()
        state.moving=false
        if state.move then pcall(function() state.move:Cancel() end); state.move=nil end
    end
    local function stopFloat()
        if state.float then pcall(function() state.float:Destroy() end) end
        if state.attachment then pcall(function() state.attachment:Destroy() end) end
        state.float=nil; state.attachment=nil
    end
    local function restoreCollision()
        for part,old in pairs(state.collision) do
            if part.Parent then pcall(function() part.CanCollide=old end) end
            state.collision[part]=nil
        end
    end
    local function shutdown()
        if not state.alive then return end
        state.alive=false; cfg.farm=false
        stopMove(); stopFloat(); restoreCollision()
        if state.spin then pcall(function() state.spin:Destroy() end) end
        for _,c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
        if gui.Parent then gui:Destroy() end
        if globalEnv and globalEnv.PHANTOM_MM2_SHUTDOWN==shutdown then
            globalEnv.PHANTOM_MM2_SHUTDOWN=nil
        end
    end
    if globalEnv then globalEnv.PHANTOM_MM2_SHUTDOWN=shutdown end
    close.MouseButton1Click:Connect(shutdown)
    gui.Destroying:Connect(function()
        if state.alive then shutdown() end
    end)
    connect(player.Idled,function()
        if not state.alive or not cfg.antiAFK then return end
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end)
    end)

    -- Refresh all candy containers (supports morphs/maps and late insertion).
    local containers, lastScan={}, -math.huge
    local function candies()
        local now=os.clock()
        if now-lastScan>2 then
            lastScan=now; containers={}
            for _,d in ipairs(workspace:GetDescendants()) do
                if d.Name=='CoinContainer' then containers[#containers+1]=d end
            end
        end
        local result={}
        for _,container in ipairs(containers) do
            if container.Parent then
                for _,d in ipairs(container:GetDescendants()) do
                    if d:IsA('BasePart') and (d:FindFirstChild('TouchInterest') or
                        (d.CanTouch and (d.Name:lower():find('coin') or d.Name:lower():find('candy')))) then
                        result[#result+1]=d
                    end
                end
            end
        end
        return result
    end
    local function knifeVisible(plr)
        local c=plr.Character
        if not c then return false end
        for _,item in ipairs(c:GetChildren()) do
            if item:IsA('Tool') and item.Name:lower():find('knife') then return true end
        end
        return false
    end
    local function murdererRoot()
        if murderer and murderer~=player and murderer.Parent==Players then
            local c=murderer.Character
            local r=c and c:FindFirstChild('HumanoidRootPart')
            local h=c and c:FindFirstChildOfClass('Humanoid')
            if r and h and h.Health>0 then return r end
        end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=player and knifeVisible(plr) then
                murderer=plr
                return plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
            end
        end
        return nil
    end
    task.spawn(function()
        while state.alive do
            if cfg.farm and cfg.avoid then
                local remote=ReplicatedStorage:FindFirstChild('Remotes')
                remote=remote and remote:FindFirstChild('Extras')
                remote=remote and remote:FindFirstChild('GetPlayerData')
                if remote and remote:IsA('RemoteFunction') then
                    local ok, data=pcall(function() return remote:InvokeServer() end)
                    if ok and type(data)=='table' then
                        local found=nil
                        for _,plr in ipairs(Players:GetPlayers()) do
                            local entry=data[plr.Name]
                            if plr~=player and type(entry)=='table' and
                                tostring(entry.Role or ''):lower():find('murder') then
                                found=plr; break
                            end
                        end
                        murderer=found
                    end
                end
            end
            task.wait(2.5)
        end
    end)
    local function closestCandy(coins)
        local hrp=root()
        if not hrp then return nil end
        local mr=cfg.avoid and murdererRoot() or nil
        local danger=mr and (mr.Position-hrp.Position).Magnitude<43
        local best,bestDist,bestScore=nil,math.huge,-math.huge
        for _,coin in ipairs(coins) do
            if coin.Parent and (state.ignored[coin] or 0)<os.clock() then
                local d=(coin.Position-hrp.Position).Magnitude
                local threat=mr and (coin.Position-mr.Position).Magnitude or math.huge
                if threat>42 then
                    if danger then
                        -- Favor the safer opposite side, but still choose a real coin.
                        local score=math.min(threat,210)-d*0.23
                        if score>bestScore then best,bestDist,bestScore=coin,d,score end
                    elseif d<bestDist then
                        best,bestDist=coin,d
                    end
                end
            end
        end
        return best,bestDist
    end
    local function updateBag(count)
        local old=bag
        if typeof(count)=='number' and count>=0 and count<=50 then
            bag=math.max(bag,math.floor(count))
        else
            bag=math.min(50,bag+1)
        end
        lifetime=lifetime+math.max(0,bag-old)
        showBag()
    end
    local function resetBag()
        if not cfg.autoReset or bag<50 or state.resetting then return end
        if os.clock()-lastReset<8 then return end
        local h=humanoid()
        if not h then return end
        lastReset=os.clock(); state.resetting=true
        targetLabel.Text='RESETTING'; status('BAG FULL / Reset','work')
        stopMove(); stopFloat(); restoreCollision()
        pcall(function() h.Health=0; h:ChangeState(Enum.HumanoidStateType.Dead) end)
        task.delay(5,function()
            if state.alive and state.resetting and humanoid()==h and h.Health>0 then
                state.resetting=false; status('RESET / Blocked','warn')
            end
        end)
    end
    local function roundHasCandy()
        return roundActive or (#candies()>0 and os.clock()-lastRoundEnd>2)
    end
    local function attemptEndGame()
        if not cfg.autoEnd or not cfg.farm or state.endGame or not roundHasCandy() then return end
        local target=murdererRoot()
        for _=1,8 do
            if target or not state.alive then break end
            task.wait(0.25); target=murdererRoot()
        end
        local rp=root(); local h=humanoid()
        if not target or not rp or not h or rp==target then return end
        state.endGame=true
        stopMove(); stopFloat(); restoreCollision()
        status('END GAME / Experimental','work')
        local body=make('BodyAngularVelocity',{Name='PHANTOM_EndGameSpin',
            AngularVelocity=Vector3.new(0,900,0),MaxTorque=Vector3.new(1e9,1e9,1e9),P=1e9},rp)
        state.spin=body
        local began=os.clock()
        while state.alive and cfg.autoEnd and os.clock()-began<1.3
            and rp.Parent and target.Parent and h.Health>0 and roundHasCandy() do
            rp.CFrame=target.CFrame*CFrame.new(0,0,1.7)
            task.wait(0.04)
        end
        pcall(function() body:Destroy() end)
        state.spin=nil
        if rp.Parent then
            rp.AssemblyAngularVelocity=Vector3.zero
            rp.AssemblyLinearVelocity=Vector3.zero
        end
        state.endGame=false
        status('END GAME / Attempt finished','work')
    end
    connect(player.CharacterAdded,function(model)
        stopMove(); stopFloat(); restoreCollision()
        local wasReset=state.resetting
        state.resetting=false
        if wasReset then bag=0; showBag() end
        task.spawn(function()
            local h=model:WaitForChild('Humanoid',8)
            local rp=model:WaitForChild('HumanoidRootPart',8)
            if not h or not rp or not state.alive then return end
            statChar.Text=model.Name:lower():find('zomb') and 'Zombie' or 'Ready'
            if wasReset and cfg.autoEnd and cfg.farm then
                task.wait(0.65)
                if state.alive then attemptEndGame() end
            end
        end)
    end)
    local events={}
    task.spawn(function()
        while state.alive do
            local remotes=ReplicatedStorage:FindFirstChild('Remotes')
            local gp=remotes and remotes:FindFirstChild('Gameplay')
            if gp then
                local function hook(name,callback)
                    local event=gp:FindFirstChild(name)
                    if event and event:IsA('RemoteEvent') and events[name]~=event then
                        events[name]=event
                        connect(event.OnClientEvent,callback)
                    end
                end
                hook('CoinCollected',function(a,b,c)
                    local count=nil
                    -- The first parameter can be nil or an Instance. Don't use
                    -- ipairs here: it stops at the first nil and loses the count.
                    for _,v in pairs({a,b,c}) do
                        if typeof(v)=='number' and v>=0 and v<=50 then count=v end
                    end
                    updateBag(count)
                    resetBag()
                end)
                hook('RoundStart',function()
                    roundActive=true; murderer=nil
                    bag=0; showBag(); statRound.Text='Active'
                end)
                hook('RoundEndFade',function()
                    roundActive=false; lastRoundEnd=os.clock(); murderer=nil
                    statRound.Text='Finished'; stopMove()
                end)
            end
            task.wait(2)
        end
    end)
    connect(RunService.Stepped,function()
        if not state.alive then return end
        local c=ch()
        if cfg.farm and state.moving and not state.endGame and not state.resetting
            and humanoid() and c then
            for _,part in ipairs(c:GetDescendants()) do
                if part:IsA('BasePart') then
                    if state.collision[part]==nil then state.collision[part]=part.CanCollide end
                    part.CanCollide=false
                end
            end
        elseif next(state.collision) then
            restoreCollision()
        end
    end)
    connect(RunService.Heartbeat,function()
        if not state.alive then return end
        local rp=root()
        if cfg.farm and state.moving and not state.endGame and not state.resetting
            and humanoid() and rp then
            if not state.float or not state.attachment or state.attachment.Parent~=rp then
                stopFloat()
                state.attachment=make('Attachment',{Name='PHANTOM_FloatAttachment'},rp)
                state.float=make('VectorForce',{Name='PHANTOM_Float',
                    Attachment0=state.attachment,RelativeTo=Enum.ActuatorRelativeTo.World,
                    ApplyAtCenterOfMass=true},rp)
            end
            state.float.Force=Vector3.new(0,rp.AssemblyMass*workspace.Gravity,0)
        elseif state.float then stopFloat() end
        if cfg.antiFling and rp and not state.endGame then
            if rp.AssemblyLinearVelocity.Magnitude>math.max(145,cfg.speed*2+40) then
                rp.AssemblyLinearVelocity=Vector3.zero
            end
            if rp.AssemblyAngularVelocity.Magnitude>35 then
                rp.AssemblyAngularVelocity=Vector3.zero
            end
        end
    end)
    task.spawn(function()
        while state.alive do
            local ok,err=pcall(function()
                if cfg.farm and not state.resetting and not state.endGame and humanoid() then
                    resetBag()
                    local coins=candies()
                    if #coins>0 and (roundActive or os.clock()-lastRoundEnd>2) then
                        local coin,dist=closestCandy(coins)
                        local rp=root()
                        if coin and rp then
                            targetLabel.Text='CANDY / Traveling'
                            status('ACTIVE / Collecting','ok')
                            statRound.Text='Active'
                            local delta=coin.Position-rp.Position
                            local flat=Vector3.new(delta.X,0,delta.Z)
                            local goal=flat.Magnitude>0.01
                                and CFrame.lookAt(coin.Position,coin.Position+flat.Unit)
                                or CFrame.new(coin.Position)
                            local duration=math.clamp(dist/math.max(cfg.speed,1),0.08,12)
                            local move=TweenService:Create(rp,TweenInfo.new(duration,Enum.EasingStyle.Linear),{CFrame=goal})
                            state.move=move; state.moving=true; move:Play()
                            local began=os.clock()
                            while state.alive and cfg.farm and state.move==move
                                and not state.resetting and not state.endGame
                                and root()==rp and coin.Parent and os.clock()-began<duration+0.5 do
                                local gap=(rp.Position-coin.Position).Magnitude
                                if gap<3.3 and not coin:FindFirstChild('TouchInterest') then break end
                                if cfg.avoid then
                                    local m=murdererRoot()
                                    if m and ((m.Position-rp.Position).Magnitude<24
                                        or (m.Position-coin.Position).Magnitude<36) then
                                        targetLabel.Text='REROUTE / Threat'
                                        status('DEFENSE / Evading','work')
                                        break
                                    end
                                end
                                task.wait(0.05)
                            end
                            if state.move==move then stopMove() end
                            if coin.Parent then state.ignored[coin]=os.clock()+1.5 end
                        else
                            targetLabel.Text='NO SAFE CANDY'
                            status('DEFENSE / No safe target','work')
                        end
                    else
                        targetLabel.Text='WAITING / Round'
                        status('READY / Waiting','work')
                    end
                else
                    if not state.endGame then targetLabel.Text='STANDBY' end
                end
            end)
            if not ok then
                stopMove(); stopFloat()
                warn('[PHANTOM V4] Farm error: '..tostring(err))
                status('ERROR / Retrying','warn')
                task.wait(0.6)
            end
            task.wait(0.17)
        end
    end)
    task.spawn(function()
        while state.alive do
            local seconds=math.floor(os.clock()-startTime)
            statTime.Text=string.format('%dm %02ds',math.floor(seconds/60),seconds%60)
            local model=ch()
            if model then
                statChar.Text=(model.Name:lower():find('zomb') or model:GetAttribute('Zombie'))
                    and 'Zombie' or (humanoid() and 'Ready' or 'Respawning')
            end
            task.wait(1)
        end
    end)
    print('[PHANTOM V4] MENU CREATED / PHANTOM_MM2_V4 / ready')
end

local ok,reason=pcall(boot)
if not ok then
    warn('[PHANTOM V4] STARTUP FAILED: '..tostring(reason))
    print('[PHANTOM V4] Please send the STARTUP FAILED line from executor console')
end
