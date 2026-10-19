--[[
 ATLANTA FARM 5.0 | MM2 candy collector
 New opaque orange / violet / white interface.
 Fixes: confirmed pickup-only bag counter, visited coin memory,
 straight movement without VectorForce, no per-frame descendant scans.
 Client side: game/server updates can change how candy events behave.
]]
print('[ATLANTA V5] Starting')

local function start()
    local Players = game:GetService('Players')
    local RunService = game:GetService('RunService')
    local UserInputService = game:GetService('UserInputService')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local VirtualUser = game:GetService('VirtualUser')
    local player = Players.LocalPlayer
    assert(player, 'LocalPlayer unavailable')
    local playerGui = player:WaitForChild('PlayerGui', 12)
    assert(playerGui, 'PlayerGui unavailable')

    local env = nil
    pcall(function() if type(getgenv) == 'function' then env = getgenv() end end)
    if env then
        for _, name in ipairs({'ATLANTA_V5_STOP', 'PHANTOM_MM2_SHUTDOWN'}) do
            if type(env[name]) == 'function' then pcall(env[name]) end
        end
    end
    for _, holder in ipairs({playerGui, game:GetService('CoreGui')}) do
        for _, name in ipairs({'HalloweenAutofarm', 'HalloweenAutofarmV3',
            'PHANTOM_MM2_V4', 'ATLANTA_FARM_V5'}) do
            pcall(function()
                local old = holder:FindFirstChild(name)
                if old then old:Destroy() end
            end)
        end
    end

    local cfg = {farm=false, speed=25, avoid=true, antiFling=true,
                 reset50=true, autoEnd=false, antiAFK=true}
    local state = {alive=true, moving=false, resetting=false, endGame=false,
        connections={}, collision={}, candidate=nil, candidateUntil=0,
        ignored=setmetatable({}, {__mode='k'}), collected=setmetatable({}, {__mode='k'}),
        currentTarget=nil, round=false, lastRoundEnd=-math.huge, murderer=nil,
        bag=0, total=0, started=os.clock(), cooldownReset=-math.huge}

    local function connect(signal, callback)
        local c = signal:Connect(callback)
        table.insert(state.connections, c)
        return c
    end
    local function make(className, parent, props)
        local o = Instance.new(className)
        for k,v in pairs(props or {}) do o[k]=v end
        o.Parent=parent
        return o
    end
    local function corner(o, n)
        make('UICorner', o, {CornerRadius=UDim.new(0,n)})
        return o
    end
    local function stroke(o, color, thickness)
        make('UIStroke',o,{Color=color,Thickness=thickness or 1,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    end
    local CL = {
        bg=Color3.fromRGB(17,9,28), surface=Color3.fromRGB(29,16,47),
        card=Color3.fromRGB(38,22,61), off=Color3.fromRGB(73,52,94),
        border=Color3.fromRGB(101,60,144), violet=Color3.fromRGB(157,83,243),
        orange=Color3.fromRGB(255,129,35), white=Color3.fromRGB(253,250,255),
        muted=Color3.fromRGB(192,170,214), red=Color3.fromRGB(255,115,108)
    }
    local function box(parent, name, size, position, color, radius)
        local f=make('Frame',parent,{Name=name,Size=size,Position=position,
            BackgroundColor3=color,BackgroundTransparency=0,BorderSizePixel=0})
        if radius then corner(f,radius) end
        return f
    end
    local function text(parent, value, size, position, fontSize, color, bold)
        return make('TextLabel',parent,{Text=tostring(value),Size=size,Position=position,
            BackgroundTransparency=1,TextColor3=color or CL.white,
            Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextSize=fontSize or 12,TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
    end
    local function button(parent, value, size, position, background, foreground, radius)
        local b=make('TextButton',parent,{Text=value,Size=size,Position=position,
            BackgroundColor3=background,BackgroundTransparency=0,
            TextColor3=foreground or CL.white,TextSize=12,
            Font=Enum.Font.GothamBold,AutoButtonColor=false,BorderSizePixel=0})
        corner(b,radius or 10)
        return b
    end

    -- Solid, compact GUI. No floating shadow/transparent glass.
    local gui=make('ScreenGui',playerGui,{Name='ATLANTA_FARM_V5',
        ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=999999,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    local W,H=350,430
    local window=box(gui,'Window',UDim2.fromOffset(W,H),UDim2.fromScale(0.5,0.5),CL.bg,18)
    window.AnchorPoint=Vector2.new(0.5,0.5)
    window.ClipsDescendants=true
    window.Active=true
    stroke(window,CL.violet,1.5)

    local stripe=box(window,'OrangeStripe',UDim2.new(1,0,0,4),UDim2.fromOffset(0,0),CL.orange,0)
    stripe.ZIndex=5
    local header=box(window,'Header',UDim2.new(1,0,0,65),UDim2.fromOffset(0,0),CL.bg,0)
    header.Active=true
    text(header,'ATLANTA',UDim2.fromOffset(190,27),UDim2.fromOffset(17,13),21,CL.white,true)
    text(header,'FARM  /  MM2',UDim2.fromOffset(195,17),UDim2.fromOffset(18,39),10,CL.orange,true)
    local minBtn=button(header,'−',UDim2.fromOffset(29,29),UDim2.new(1,-74,0,19),CL.surface,CL.white)
    local closeBtn=button(header,'×',UDim2.fromOffset(29,29),UDim2.new(1,-39,0,19),CL.surface,CL.white)
    local hairline=box(window,'Divider',UDim2.new(1,-30,0,1),UDim2.fromOffset(15,65),CL.border,0)

    local tabs, pages = {}, {}
    local tabbar=box(window,'Tabs',UDim2.new(1,-28,0,43),UDim2.fromOffset(14,76),CL.surface,12)
    local labels={ {'FARM','ФАРМ'}, {'SAFETY','ЗАЩИТА'}, {'STATS','СТАТИСТИКА'} }
    local selected='FARM'
    for i,item in ipairs(labels) do
        local key,caption=item[1],item[2]
        local btn=button(tabbar,caption,UDim2.new(1/3,-6,1,-8),
            UDim2.new((i-1)/3,4,0,4),i==1 and CL.orange or CL.surface,
            i==1 and CL.bg or CL.muted)
        btn.TextSize=i==3 and 10 or 11
        tabs[key]=btn
        local scroll=make('ScrollingFrame',window,{Name=key..'_Page',
            Position=UDim2.fromOffset(14,131),Size=UDim2.new(1,-28,1,-185),
            Visible=key==selected,BackgroundTransparency=1,BorderSizePixel=0,
            ScrollBarThickness=3,ScrollBarImageColor3=CL.violet,
            CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y})
        make('UIPadding',scroll,{PaddingRight=UDim.new(0,6),
            PaddingBottom=UDim.new(0,7)})
        local layout=make('UIListLayout',scroll,{Padding=UDim.new(0,9),
            SortOrder=Enum.SortOrder.LayoutOrder})
        connect(layout:GetPropertyChangedSignal('AbsoluteContentSize'),function()
            scroll.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+12)
        end)
        pages[key]={scroller=scroll,index=0}
        connect(btn.MouseButton1Click,function()
            selected=key
            for name,b in pairs(tabs) do
                local active=name==key
                b.BackgroundColor3=active and CL.orange or CL.surface
                b.TextColor3=active and CL.bg or CL.muted
                pages[name].scroller.Visible=active
            end
        end)
    end
    local footer=box(window,'Footer',UDim2.new(1,-28,0,37),UDim2.new(0,14,1,-47),CL.surface,11)
    local statusLabel=text(footer,'●  ГОТОВ',UDim2.new(1,-70,1,0),UDim2.fromOffset(11,0),11,CL.muted)
    local versionLabel=text(footer,'v5.0',UDim2.fromOffset(55,37),UDim2.new(1,-65,0,0),11,CL.orange,true)
    versionLabel.TextXAlignment=Enum.TextXAlignment.Right
    local function status(value, good)
        if not state.alive then return end
        statusLabel.Text='●  '..value
        statusLabel.TextColor3=good and CL.orange or CL.muted
    end
    local function card(tab, height)
        local page=pages[tab]
        page.index=page.index+1
        local item=box(page.scroller,'Item'..page.index,UDim2.new(1,-1,0,height),
            UDim2.fromOffset(0,0),CL.card,12)
        item.LayoutOrder=page.index
        stroke(item,CL.border,1)
        return item
    end
    local function setting(tab,name,detail,initial,callback)
        local item=card(tab,58)
        text(item,name,UDim2.new(1,-92,0,24),UDim2.fromOffset(13,7),13,CL.white,true)
        text(item,detail,UDim2.new(1,-92,0,18),UDim2.fromOffset(13,31),10,CL.muted)
        local sw=button(item,'',UDim2.fromOffset(49,26),UDim2.new(1,-63,0.5,-13),
            initial and CL.orange or CL.off,CL.white,13)
        local dot=box(sw,'Dot',UDim2.fromOffset(18,18),
            initial and UDim2.fromOffset(27,4) or UDim2.fromOffset(4,4),CL.white,9)
        connect(sw.MouseButton1Click,function()
            initial=not initial
            sw.BackgroundColor3=initial and CL.orange or CL.off
            dot.Position=initial and UDim2.fromOffset(27,4) or UDim2.fromOffset(4,4)
            callback(initial)
        end)
        return item
    end
    local function stat(tab,title,value)
        local item=card(tab,47)
        text(item,title,UDim2.new(0.57,0,1,0),UDim2.fromOffset(13,0),12,CL.muted)
        local v=text(item,value,UDim2.new(0.4,-13,1,0),UDim2.new(0.6,0,0,0),
            13,CL.orange,true)
        v.TextXAlignment=Enum.TextXAlignment.Right
        return v
    end

    setting('FARM','Автофарм','Сбор ближайших конфет',cfg.farm,function(v)
        cfg.farm=v
        status(v and 'ПОИСК КОНФЕТ' or 'ГОТОВ',v)
    end)
    local speedCard=card('FARM',81)
    text(speedCard,'Скорость',UDim2.fromOffset(205,24),UDim2.fromOffset(13,7),14,CL.white,true)
    local speedText=text(speedCard,tostring(cfg.speed),UDim2.fromOffset(60,24),
        UDim2.new(1,-74,0,7),14,CL.orange,true)
    speedText.TextXAlignment=Enum.TextXAlignment.Right
    local track=box(speedCard,'Track',UDim2.new(1,-29,0,7),UDim2.fromOffset(14,54),CL.off,4)
    local fill=box(track,'Fill',UDim2.new((cfg.speed-1)/99,0,1,0),UDim2.fromOffset(0,0),CL.orange,4)
    local handle=box(track,'Knob',UDim2.fromOffset(17,17),
        UDim2.new((cfg.speed-1)/99,-8,0.5,-8),CL.white,9)
    local sliderHit=button(track,'',UDim2.new(1,0,0,32),UDim2.fromOffset(0,-12),CL.surface,CL.white)
    sliderHit.BackgroundTransparency=1
    local adjusting=false
    local function setSpeed(pixel)
        if track.AbsoluteSize.X<2 then return end
        local ratio=math.clamp((pixel-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        cfg.speed=math.floor(1+ratio*99+0.5)
        ratio=(cfg.speed-1)/99
        fill.Size=UDim2.new(ratio,0,1,0)
        handle.Position=UDim2.new(ratio,-8,0.5,-8)
        speedText.Text=tostring(cfg.speed)
    end
    connect(sliderHit.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then
            adjusting=true
            setSpeed(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if adjusting and (input.UserInputType==Enum.UserInputType.MouseMovement or
            input.UserInputType==Enum.UserInputType.Touch) then setSpeed(input.Position.X) end
    end)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then adjusting=false end
    end)
    local bagCard=card('FARM',80)
    text(bagCard,'Мешок (подтверждено)',UDim2.new(1,-106,0,25),
        UDim2.fromOffset(13,8),12,CL.white,true)
    local bagText=text(bagCard,'0 / 50',UDim2.fromOffset(81,25),
        UDim2.new(1,-91,0,8),13,CL.orange,true)
    bagText.TextXAlignment=Enum.TextXAlignment.Right
    local bar=box(bagCard,'Bar',UDim2.new(1,-26,0,9),UDim2.fromOffset(13,53),CL.off,5)
    local barFill=box(bar,'Progress',UDim2.fromScale(0,1),UDim2.fromOffset(0,0),CL.violet,5)
    local targetText=stat('FARM','Цель','Ожидание')
    setting('SAFETY','Избегать убийцу','Выбирать безопасные конфеты',cfg.avoid,
        function(v) cfg.avoid=v end)
    setting('SAFETY','Антифлинг','Защита от резких толчков',cfg.antiFling,
        function(v) cfg.antiFling=v end)
    setting('SAFETY','Авторесет 50/50','Только после 50 подтверждений',cfg.reset50,
        function(v) cfg.reset50=v end)
    setting('SAFETY','Auto End Game · BETA','Физический режим после ресета',cfg.autoEnd,
        function(v) cfg.autoEnd=v end)
    setting('SAFETY','Anti AFK','Защита от отключения за бездействие',cfg.antiAFK,
        function(v) cfg.antiAFK=v end)
    local statBag=stat('STATS','Собрано за раунд','0 / 50')
    local statTotal=stat('STATS','Всего в сессии','0')
    local statChar=stat('STATS','Персонаж','Ожидание')
    local statRound=stat('STATS','Раунд','Ожидание')
    local statTime=stat('STATS','Время','0м 0с')
    local function refreshBag()
        local value=tostring(state.bag)..' / 50'
        bagText.Text=value
        statBag.Text=value
        statTotal.Text=tostring(state.total)
        barFill.Size=UDim2.new(math.clamp(state.bag/50,0,1),0,1,0)
    end

    local function character() return player.Character end
    local function root()
        local c=character()
        return c and (c:FindFirstChild('HumanoidRootPart')
            or c:FindFirstChild('UpperTorso') or c:FindFirstChild('Torso') or c.PrimaryPart)
    end
    local function humanoid()
        local c=character()
        local h=c and c:FindFirstChildOfClass('Humanoid')
        return h and h.Health>0 and h or nil
    end
    local function restoreCollision()
        for part, original in pairs(state.collision) do
            if part and part.Parent then pcall(function() part.CanCollide=original end) end
            state.collision[part]=nil
        end
        if state.rotHumanoid and state.rotHumanoid.Parent then
            pcall(function() state.rotHumanoid.AutoRotate=state.originalRotate end)
        end
        state.rotHumanoid=nil
    end
    local function setNoClip()
        local c=character()
        if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA('BasePart') then
                if state.collision[p]==nil then state.collision[p]=p.CanCollide end
                p.CanCollide=false
            end
        end
        local h=humanoid()
        if h and state.rotHumanoid~=h then
            state.rotHumanoid=h
            state.originalRotate=h.AutoRotate
            h.AutoRotate=false
        end
    end
    local function stopMove()
        state.moving=false
        state.currentTarget=nil
        restoreCollision()
    end
    local function shutdown()
        if not state.alive then return end
        state.alive=false
        cfg.farm=false
        stopMove()
        if state.spin and state.spin.Parent then pcall(function() state.spin:Destroy() end) end
        for _,c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
        if gui.Parent then gui:Destroy() end
        if env and env.ATLANTA_V5_STOP==shutdown then env.ATLANTA_V5_STOP=nil end
    end
    if env then env.ATLANTA_V5_STOP=shutdown end
    connect(closeBtn.MouseButton1Click,shutdown)
    connect(player.Idled,function()
        if cfg.antiAFK and state.alive then
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end)
        end
    end)
    local collapsed=false
    connect(minBtn.MouseButton1Click,function()
        collapsed=not collapsed
        minBtn.Text=collapsed and '+' or '−'
        tabbar.Visible=not collapsed
        hairline.Visible=not collapsed
        footer.Visible=not collapsed
        window.Size=UDim2.fromOffset(W,collapsed and 65 or H)
        for key,page in pairs(pages) do
            page.scroller.Visible=not collapsed and key==selected
        end
    end)
    local movingWindow=false
    local startedAt=nil
    local originalPos=nil
    connect(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then
            if input.Position.X<minBtn.AbsolutePosition.X-8 then
                movingWindow=true
                startedAt=input.Position
                originalPos=window.Position
            end
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if movingWindow and startedAt and originalPos and
            (input.UserInputType==Enum.UserInputType.MouseMovement or
            input.UserInputType==Enum.UserInputType.Touch) then
            local offset=input.Position-startedAt
            window.Position=UDim2.new(originalPos.X.Scale,originalPos.X.Offset+offset.X,
                originalPos.Y.Scale,originalPos.Y.Offset+offset.Y)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then movingWindow=false end
    end)
    local scale=make('UIScale',window,{Scale=1})
    local function fit()
        local cam=workspace.CurrentCamera
        if cam then
            local vp=cam.ViewportSize
            scale.Scale=math.clamp(math.min((vp.X-20)/W,(vp.Y-20)/H),0.54,1)
        end
    end
    fit()

    -- Collectible discovery. Rescanning the whole workspace every 2 seconds was wasteful.
    local containers={}
    local lastScan=-math.huge
    local function candies()
        local now=os.clock()
        if now-lastScan>(#containers==0 and 3 or 10) then
            lastScan=now
            containers={}
            for _,o in ipairs(workspace:GetDescendants()) do
                if o.Name=='CoinContainer' then containers[#containers+1]=o end
            end
        end
        local results={}
        for _,cont in ipairs(containers) do
            if cont.Parent then
                for _,p in ipairs(cont:GetDescendants()) do
                    if p:IsA('BasePart') and p.CanTouch and
                        (p:FindFirstChild('TouchInterest') or
                         p.Name:lower():find('coin') or p.Name:lower():find('candy')) and
                        not state.collected[p] and (state.ignored[p] or 0)<now then
                        results[#results+1]=p
                    end
                end
            end
        end
        return results
    end

    local function knifeEquipped(plr)
        local c=plr.Character
        if not c then return false end
        for _,item in ipairs(c:GetChildren()) do
            if item:IsA('Tool') and item.Name:lower():find('knife') then return true end
        end
        return false
    end
    local function murdererRoot()
        local found=state.murderer
        if found and found~=player and found.Parent==Players then
            local c=found.Character
            local h=c and c:FindFirstChildOfClass('Humanoid')
            local rp=c and c:FindFirstChild('HumanoidRootPart')
            if rp and h and h.Health>0 then return rp end
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and knifeEquipped(p) then
                state.murderer=p
                local c=p.Character
                return c and c:FindFirstChild('HumanoidRootPart')
            end
        end
        return nil
    end
    task.spawn(function()
        -- Role query is infrequent; never inside movement frames.
        while state.alive do
            if cfg.farm and cfg.avoid and state.round then
                local rem=ReplicatedStorage:FindFirstChild('Remotes')
                local ext=rem and rem:FindFirstChild('Extras')
                local fn=ext and ext:FindFirstChild('GetPlayerData')
                if fn and fn:IsA('RemoteFunction') then
                    local ok,data=pcall(function() return fn:InvokeServer() end)
                    if ok and type(data)=='table' then
                        for _,plr in ipairs(Players:GetPlayers()) do
                            local entry=data[plr.Name]
                            if plr~=player and type(entry)=='table' and
                                tostring(entry.Role or ''):lower():find('murder') then
                                state.murderer=plr
                                break
                            end
                        end
                    end
                end
            end
            task.wait(9)
        end
    end)
    local function nearestCandy(options)
        local rp=root()
        if not rp then return nil end
        local threat=cfg.avoid and murdererRoot() or nil
        local threatened=threat and (rp.Position-threat.Position).Magnitude<45
        local best, score=nil,-math.huge
        for _,coin in ipairs(options) do
            if coin.Parent then
                local distance=(coin.Position-rp.Position).Magnitude
                local safety=threat and (coin.Position-threat.Position).Magnitude or math.huge
                if safety>36 then
                    local rank=threatened and (math.min(safety,190)-distance*0.3) or -distance
                    if rank>score then best,score=coin,rank end
                end
            end
        end
        return best
    end
    local function newRound()
        state.bag=0
        state.ignored=setmetatable({}, {__mode='k'})
        state.collected=setmetatable({}, {__mode='k'})
        state.candidate=nil
        state.candidateUntil=0
        refreshBag()
    end
    local function resetIfFull()
        if not cfg.reset50 or state.bag<50 or state.resetting or not state.alive then return end
        if os.clock()-state.cooldownReset<12 then return end
        local h=humanoid()
        if not h then return end
        state.cooldownReset=os.clock()
        state.resetting=true
        status('МЕШОК ПОЛОН — РЕСЕТ',true)
        stopMove()
        pcall(function() h.Health=0; h:ChangeState(Enum.HumanoidStateType.Dead) end)
    end
    local function pickupAcknowledged()
        -- Never infer bag=50 from arbitrary remote parameters. One local pickup
        -- confirmation only counts the current target, and only once.
        local coin=state.candidate
        if not coin or state.collected[coin] or os.clock()>state.candidateUntil or
            state.resetting then return end
        state.collected[coin]=true
        state.ignored[coin]=math.huge
        state.candidate=nil
        state.bag=math.min(50,state.bag+1)
        state.total=state.total+1
        refreshBag()
        resetIfFull()
    end

    local events={}
    task.spawn(function()
        while state.alive do
            local rem=ReplicatedStorage:FindFirstChild('Remotes')
            local gp=rem and rem:FindFirstChild('Gameplay')
            if gp then
                local function bind(name,fn)
                    local event=gp:FindFirstChild(name)
                    if event and event:IsA('RemoteEvent') and events[name]~=event then
                        events[name]=event
                        connect(event.OnClientEvent,fn)
                    end
                end
                bind('CoinCollected',pickupAcknowledged)
                bind('RoundStart',function()
                    state.round=true
                    state.murderer=nil
                    newRound()
                    statRound.Text='Идёт'
                end)
                bind('RoundEndFade',function()
                    state.round=false
                    state.lastRoundEnd=os.clock()
                    state.murderer=nil
                    state.candidate=nil
                    stopMove()
                    statRound.Text='Завершён'
                end)
            end
            task.wait(3)
        end
    end)

    local function endGameAttempt()
        if not cfg.autoEnd or not cfg.farm or state.endGame or not state.alive then return end
        local mr=murdererRoot()
        local rp=root()
        local h=humanoid()
        if not mr or not rp or not h then return end
        state.endGame=true
        local ok,err=pcall(function()
            local spin=make('BodyAngularVelocity',rp,{Name='ATLANTA_EndGame',
                AngularVelocity=Vector3.new(0,820,0),
                MaxTorque=Vector3.new(1e9,1e9,1e9),P=1e9})
            state.spin=spin
            local untilTime=os.clock()+1.1
            while state.alive and cfg.autoEnd and os.clock()<untilTime and
                rp.Parent and mr.Parent and h.Health>0 do
                rp.CFrame=mr.CFrame*CFrame.new(0,0,2)
                task.wait(0.05)
            end
        end)
        if state.spin then pcall(function() state.spin:Destroy() end); state.spin=nil end
        if rp.Parent then
            rp.AssemblyAngularVelocity=Vector3.zero
            rp.AssemblyLinearVelocity=Vector3.zero
        end
        state.endGame=false
        if not ok then warn('[ATLANTA V5] End-game: '..tostring(err)) end
    end
    connect(player.CharacterAdded,function(model)
        stopMove()
        local resetWasActive=state.resetting
        state.resetting=false
        state.candidate=nil
        if resetWasActive then newRound() end
        task.spawn(function()
            local h=model:WaitForChild('Humanoid',9)
            model:WaitForChild('HumanoidRootPart',9)
            if not h or not state.alive then return end
            statChar.Text=model.Name:lower():find('zomb') and 'Зомби' or 'Готов'
            if resetWasActive and cfg.autoEnd and cfg.farm then
                task.wait(0.75)
                if state.alive then endGameAttempt() end
            end
        end)
    end)

    -- Straight, incremental travel. No Tween, VectorForce, BodyVelocity or upward hop.
    local function flyTo(coin)
        local rp=root()
        if not rp or not humanoid() or not coin.Parent then return end
        state.currentTarget=coin
        state.candidate=nil
        state.moving=true
        setNoClip() -- Once per target instead of GetDescendants every frame.
        local initialDistance=(rp.Position-(coin.Position+Vector3.new(0,1.2,0))).Magnitude
        local deadline=os.clock()+math.clamp(initialDistance/math.max(cfg.speed,1)+2.5,2,26)
        local last=os.clock()
        local reached=false
        local lastThreatCheck=0
        while state.alive and cfg.farm and state.currentTarget==coin and not state.resetting
            and not state.endGame and rp.Parent and root()==rp and humanoid()
            and coin.Parent and os.clock()<deadline do
            local now=os.clock()
            local dt=math.clamp(now-last,0.015,0.09)
            last=now
            local target=coin.Position+Vector3.new(0,1.2,0)
            local displacement=target-rp.Position
            local gap=displacement.Magnitude
            if gap<6 then
                state.candidate=coin
                state.candidateUntil=now+2
            end
            if state.collected[coin] then reached=true; break end
            if cfg.avoid and now-lastThreatCheck>0.35 then
                lastThreatCheck=now
                local killer=murdererRoot()
                if killer and ((killer.Position-rp.Position).Magnitude<23 or
                    (killer.Position-coin.Position).Magnitude<30) then
                    status('ОБХОД УБИЙЦЫ',true)
                    break
                end
            end
            if gap<=2.6 then
                reached=true
                -- Hold near candy briefly so a genuine CoinCollected event can arrive.
                rp.CFrame=CFrame.new(target)
                rp.AssemblyLinearVelocity=Vector3.zero
                rp.AssemblyAngularVelocity=Vector3.zero
                local hold=os.clock()+0.65
                while state.alive and cfg.farm and coin.Parent and
                    not state.collected[coin] and os.clock()<hold do
                    task.wait(0.045)
                end
                break
            end
            local nextPos=rp.Position+displacement.Unit*math.min(gap,cfg.speed*dt)
            local flat=Vector3.new(displacement.X,0,displacement.Z)
            if flat.Magnitude>0.1 then
                rp.CFrame=CFrame.lookAt(nextPos,nextPos+flat.Unit)
            else
                rp.CFrame=CFrame.new(nextPos)
            end
            rp.AssemblyLinearVelocity=Vector3.zero
            rp.AssemblyAngularVelocity=Vector3.zero
            task.wait(0.035)
        end
        if state.currentTarget==coin then
            stopMove()
            if not state.collected[coin] then
                -- Do not return immediately to the same ghost/consumed coin.
                state.ignored[coin]=reached and math.huge or (os.clock()+12)
            end
        end
    end

    connect(RunService.Heartbeat,function()
        if not state.alive or not cfg.antiFling or state.moving or state.endGame then return end
        local rp=root()
        if rp and humanoid() then
            if rp.AssemblyLinearVelocity.Magnitude>155 then
                rp.AssemblyLinearVelocity=Vector3.zero
            end
            if rp.AssemblyAngularVelocity.Magnitude>48 then
                rp.AssemblyAngularVelocity=Vector3.zero
            end
        end
    end)
    task.spawn(function()
        while state.alive do
            if cfg.farm and not state.resetting and not state.endGame and humanoid() then
                local ok,err=pcall(function()
                    resetIfFull()
                    if state.resetting then return end
                    if state.round or os.clock()-state.lastRoundEnd>2 then
                        local pool=candies()
                        if #pool>0 then
                            local coin=nearestCandy(pool)
                            if coin then
                                targetText.Text='Конфета'
                                status('СБОР КОНФЕТ',true)
                                flyTo(coin)
                            else
                                targetText.Text='Нет безопасных'
                                status('ПОИСК БЕЗОПАСНОГО ПУТИ',false)
                            end
                        else
                            targetText.Text='Ожидание конфет'
                            status('ОЖИДАНИЕ КОНФЕТ',false)
                        end
                    end
                end)
                if not ok then
                    stopMove()
                    status('ОШИБКА — ПОВТОР',false)
                    warn('[ATLANTA V5] Farm: '..tostring(err))
                    task.wait(0.7)
                end
            else
                if state.moving then stopMove() end
                if not state.resetting then targetText.Text='Ожидание' end
            end
            task.wait(0.22)
        end
    end)
    task.spawn(function()
        while state.alive do
            local seconds=math.floor(os.clock()-state.started)
            statTime.Text=string.format('%dм %02dс',math.floor(seconds/60),seconds%60)
            local c=character()
            statChar.Text=not c and 'Нет персонажа' or
                ((c.Name:lower():find('zomb') or c:GetAttribute('Zombie')) and 'Зомби' or
                (humanoid() and 'Готов' or 'Возрождение'))
            task.wait(1)
        end
    end)
    print('[ATLANTA V5] MENU CREATED; candy counter requires pickup confirmation')
end

local ok,reason=pcall(start)
if not ok then
    warn('[ATLANTA V5] STARTUP ERROR: '..tostring(reason))
end
