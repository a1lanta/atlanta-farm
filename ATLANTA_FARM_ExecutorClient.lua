-- HALLOWEN MM2 v2.2 / fast proximity pickup + always-on Noclip
-- Self-contained. No remote loadstring or external dependencies.
-- Movement and pickups remain subject to Roblox/server validation.

local ok, err = xpcall(function()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CollectionService = game:GetService("CollectionService")
    local VirtualUser = game:GetService("VirtualUser")

    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:WaitForChild("PlayerGui")
    local guiName = "HALLOWEN_MM2_OPTIMIZED_V22"

    -- Running the script again safely removes earlier windows and their listeners.
    for _,name in ipairs({
        guiName, "HALLOWEN_MM2_OPTIMIZED_V21", "HALLOWEN_MM2_OPTIMIZED_V20", "HALLOWEN_MM2_V19", "HALLOWEN_MM2_V18",
        "ATLANTA_FARM_V17", "ATLANTA_FARM_V16", "ATLANTA_FARM_V15"
    }) do
        local old = playerGui:FindFirstChild(name)
        if old then pcall(function() old:Destroy() end) end
    end

    -- Clean up ESP objects left by an older interrupted version.
    for _,entry in ipairs({
        {Workspace, "HalloweenMM2_CurrentTarget"},
        {Workspace, "HalloweenMM2TargetESP"},
        {playerGui, "HalloweenMM2_Nearest"},
        {playerGui, "HalloweenMM2TargetLabel"}
    }) do
        local old=entry[1]:FindFirstChild(entry[2])
        if old then pcall(function() old:Destroy() end) end
    end

    local C = {
        bg=Color3.fromRGB(17,15,24), card=Color3.fromRGB(29,25,37),
        elevated=Color3.fromRGB(42,35,48), orange=Color3.fromRGB(246,151,67),
        lilac=Color3.fromRGB(175,137,211), white=Color3.fromRGB(246,239,245),
        muted=Color3.fromRGB(170,164,181), green=Color3.fromRGB(142,225,171),
        red=Color3.fromRGB(255,122,122)
    }
    local settings = {
        farm=false, speed=40, noclip=true,
        antiAfk=true, antiFling=true, avoidMurderer=true,
        visits=0, candies=0, coins=0, failures=0, disappearances=0,
        target=nil, arrivedAt=nil, lastDistance=math.huge, lastProgressAt=0,
        status="Готово · Noclip ON · фарм выключен"
    }
    local alive = true
    local started = os.clock()
    local connections = {}
    local collectibles = setmetatable({}, {__mode="k"})
    local visited = setmetatable({}, {__mode="k"})
    local originalCollision = setmetatable({}, {__mode="k"})
    local character, humanoid, root
    local hoverAttachment, hoverForce
    local nextScan, nextClip, nextUi, nextSafety = 0,0,0,0
    local gui
    local refresh
    local setFarm
    local heldSlider = false
    local sliderTouch = nil
    local dragging = false
    local dragTouch, dragPosition, originalPanelPosition

    local function connect(signal, fn)
        local con=signal:Connect(fn)
        connections[#connections+1]=con
        return con
    end
    local function make(className, parent, props)
        local inst=Instance.new(className)
        for key,value in pairs(props or {}) do inst[key]=value end
        inst.Parent=parent
        return inst
    end
    local function radius(inst, px)
        make("UICorner", inst, {CornerRadius=UDim.new(0,px)})
    end
    local function stroke(inst, color, transparency)
        make("UIStroke", inst, {Color=color, Thickness=1, Transparency=transparency or 0})
    end
    local function label(parent, textValue, sz, color, bold)
        return make("TextLabel",parent,{
            BackgroundTransparency=1,Text=textValue,TextSize=sz or 12,
            Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextColor3=color or C.white,TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center,
            TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0
        })
    end
    local function primaryButton(parent, textValue, size)
        local b=make("TextButton",parent,{
            Text=textValue,TextColor3=C.white,TextSize=12,
            Font=Enum.Font.GothamBold,BackgroundColor3=C.elevated,
            BorderSizePixel=0,AutoButtonColor=false,
            Size=size or UDim2.fromOffset(64,32)
        })
        radius(b,9)
        return b
    end
    local function connectClick(btn, callback)
        connect(btn.MouseButton1Click,callback)
    end
    local function setToggleText(btn, enabled)
        btn.Text=enabled and "ON" or "OFF"
        btn.TextColor3=enabled and C.green or C.muted
        btn.BackgroundColor3=enabled and Color3.fromRGB(39,66,51) or C.elevated
    end
    local function card(parent, height)
        local frame=make("Frame",parent,{
            BackgroundColor3=C.card,BorderSizePixel=0,
            Size=UDim2.new(1,-12,0,height)
        })
        radius(frame,11)
        stroke(frame,C.lilac,0.89)
        return frame
    end
    local function settingRow(parent, title, caption, height)
        local f=card(parent,height or 72)
        local heading=label(f,title,13,C.white,true)
        heading.Position=UDim2.fromOffset(13,9)
        heading.Size=UDim2.new(1,-103,0,22)
        local sub=label(f,caption,10,C.muted,false)
        sub.Position=UDim2.fromOffset(13,33)
        sub.Size=UDim2.new(1,-103,0,22)
        local b=primaryButton(f,"OFF")
        b.AnchorPoint=Vector2.new(1,0.5)
        b.Position=UDim2.new(1,-13,0.5,0)
        return f,b,sub
    end

    -- Initialize the menu before starting the farming heartbeat.
    gui=make("ScreenGui",playerGui,{
        Name=guiName,ResetOnSpawn=false,IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=85
    })
    local launcher=primaryButton(gui,"🎃",UDim2.fromOffset(53,53))
    launcher.Name="PumpkinLauncher"
    launcher.TextSize=25
    launcher.Position=UDim2.new(0,14,0.50,-26)
    launcher.BackgroundColor3=Color3.fromRGB(78,47,78)
    stroke(launcher,C.orange,0.15)
    radius(launcher,14)

    local panel=make("Frame",gui,{
        Name="MainWindow",BackgroundColor3=C.bg,BorderSizePixel=0,
        ClipsDescendants=true,Size=UDim2.fromOffset(372,490),
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Visible=true
    })
    radius(panel,16)
    stroke(panel,C.orange,0.38)
    local scale=make("UIScale",panel,{Scale=1})
    make("Frame",panel,{
        BorderSizePixel=0,BackgroundColor3=C.orange,
        Size=UDim2.new(1,0,0,3)
    })
    local header=make("Frame",panel,{
        BackgroundTransparency=1,Size=UDim2.new(1,0,0,69),Active=true
    })
    local pumpkin=label(header,"🎃",25,C.orange,true)
    pumpkin.Position=UDim2.fromOffset(14,11)
    pumpkin.Size=UDim2.fromOffset(31,32)
    local headerTitle=label(header,"HALLOWEN MM2",18,C.white,true)
    headerTitle.Position=UDim2.fromOffset(49,9)
    headerTitle.Size=UDim2.new(1,-126,0,28)
    local telegram=label(header,"✈ TELEGRAM  @AtlantaRobuxShop",10,C.orange,true)
    telegram.Position=UDim2.fromOffset(49,39)
    telegram.Size=UDim2.new(1,-110,0,18)
    local close=primaryButton(header,"✕",UDim2.fromOffset(31,31))
    close.Position=UDim2.new(1,-43,0,18)
    close.TextSize=18

    local tabs=make("Frame",panel,{
        BackgroundTransparency=1,Size=UDim2.new(1,-24,0,36),
        Position=UDim2.fromOffset(12,74)
    })
    local tabButtons, pages={},{ }
    for i, tabName in ipairs({"ФАРМ","ЗАЩИТА","СТАТИСТИКА"}) do
        local b=primaryButton(tabs,tabName)
        b.TextSize=11
        b.Size=UDim2.new(1/3,-8,1,0)
        b.Position=UDim2.new((i-1)/3,4,0,0)
        tabButtons[i]=b
        local page=make("ScrollingFrame",panel,{
            Name="Tab"..i,Position=UDim2.fromOffset(11,119),
            Size=UDim2.new(1,-22,1,-155),BorderSizePixel=0,
            BackgroundTransparency=1,ScrollBarThickness=3,
            ScrollBarImageColor3=C.orange,ScrollingDirection=Enum.ScrollingDirection.Y,
            CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
            Visible=i==1
        })
        make("UIListLayout",page,{
            FillDirection=Enum.FillDirection.Vertical,
            SortOrder=Enum.SortOrder.LayoutOrder,
            Padding=UDim.new(0,9),HorizontalAlignment=Enum.HorizontalAlignment.Center
        })
        make("UIPadding",page,{
            PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,12)
        })
        pages[i]=page
    end
    local function showTab(index)
        for i,b in ipairs(tabButtons) do
            pages[i].Visible=(i==index)
            b.BackgroundColor3=i==index and Color3.fromRGB(75,47,57) or C.card
            b.TextColor3=i==index and C.orange or C.muted
        end
    end
    for i,b in ipairs(tabButtons) do
        connectClick(b,function() showTab(i) end)
    end
    showTab(1)

    local footer=label(panel,"✈ TELEGRAM  •  @AtlantaRobuxShop  •  v2.2",10,C.muted,true)
    footer.TextXAlignment=Enum.TextXAlignment.Center
    footer.Position=UDim2.new(0,10,1,-30)
    footer.Size=UDim2.new(1,-20,0,23)

    local farmRow,farmBtn=settingRow(pages[1],"AUTO CANDY FARM","Ближайшая конфета → затем монеты")
    local speedCard=card(pages[1],115)
    local speedTitle=label(speedCard,"СКОРОСТЬ ПОЛЁТА",12,C.white,true)
    speedTitle.Position=UDim2.fromOffset(13,7)
    speedTitle.Size=UDim2.new(1,-100,0,23)
    local speedBox=make("TextBox",speedCard,{
        Text="40",TextSize=14,Font=Enum.Font.GothamBold,
        TextColor3=C.orange,BackgroundColor3=C.elevated,
        ClearTextOnFocus=false,BorderSizePixel=0,
        Size=UDim2.fromOffset(55,28),Position=UDim2.new(1,-68,0,7)
    })
    radius(speedBox,8)
    local track=make("Frame",speedCard,{
        BorderSizePixel=0,BackgroundColor3=C.elevated,
        Position=UDim2.fromOffset(15,55),Size=UDim2.new(1,-30,0,8),Active=true
    })
    radius(track,4)
    local fill=make("Frame",track,{
        BorderSizePixel=0,BackgroundColor3=C.orange,Size=UDim2.fromScale(39/99,1)
    })
    radius(fill,4)
    local knob=make("Frame",track,{
        BorderSizePixel=0,BackgroundColor3=C.white,Active=true,
        AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(18,18),
        Position=UDim2.fromScale(39/99,0.5)
    })
    radius(knob,9)
    local speedSub=label(speedCard,"1  —  медленно                 100  —  быстро",10,C.muted)
    speedSub.Position=UDim2.fromOffset(13,77)
    speedSub.Size=UDim2.new(1,-26,0,21)

    local avoidRow,avoidBtn=settingRow(pages[1],"ИЗБЕГАТЬ MURDERER","Если роль/оружие видны клиенту")
    local noteRow=card(pages[1],72)
    local noteText=label(noteRow,"Цель пересчитывается автоматически.\nСбор подтверждает только сервер игры.",11,C.muted)
    noteText.TextWrapped=true
    noteText.TextTruncate=Enum.TextTruncate.None
    noteText.Position=UDim2.fromOffset(14,6)
    noteText.Size=UDim2.new(1,-28,1,-12)

    local antiRow,antiBtn=settingRow(pages[2],"ANTI-FLING","Ограничение резких толчков")
    local afkRow,afkBtn=settingRow(pages[2],"ANTI-AFK","Попытка активности при простое")
    local statsCard=card(pages[3],185)
    local statsTitle=label(statsCard,"СТАТИСТИКА СЕССИИ",13,C.orange,true)
    statsTitle.Position=UDim2.fromOffset(13,9)
    statsTitle.Size=UDim2.new(1,-26,0,25)
    local statsLines={}
    for i=1,5 do
        local ln=label(statsCard,"—",12,C.white,i==1)
        ln.Position=UDim2.fromOffset(13,36+(i-1)*28)
        ln.Size=UDim2.new(1,-26,0,24)
        statsLines[i]=ln
    end
    local statusCard=card(pages[3],95)
    local statusHead=label(statusCard,"СТАТУС",12,C.orange,true)
    statusHead.Position=UDim2.fromOffset(13,7)
    statusHead.Size=UDim2.new(1,-26,0,20)
    local statusText=label(statusCard,settings.status,11,C.white)
    statusText.TextWrapped=true
    statusText.TextTruncate=Enum.TextTruncate.None
    statusText.Position=UDim2.fromOffset(13,28)
    statusText.Size=UDim2.new(1,-26,0,59)

    local function speedUI()
        local amount=math.clamp(settings.speed,1,100)
        local ratio=(amount-1)/99
        fill.Size=UDim2.fromScale(ratio,1)
        knob.Position=UDim2.fromScale(ratio,0.5)
        if not speedBox:IsFocused() then speedBox.Text=tostring(amount) end
    end
    refresh=function()
        if not alive then return end
        setToggleText(farmBtn,settings.farm)
        setToggleText(avoidBtn,settings.avoidMurderer)
        setToggleText(antiBtn,settings.antiFling)
        setToggleText(afkBtn,settings.antiAfk)
        speedUI()
        statsLines[1].Text="Подлётов к целям: "..settings.visits
        statsLines[2].Text="Целей исчезло рядом: "..settings.disappearances
        statsLines[3].Text="Из них конфеты: "..settings.candies
        statsLines[4].Text="Из них монеты: "..settings.coins
        local seconds=math.floor(os.clock()-started)
        statsLines[5].Text=string.format("Время: %02d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
        statusText.Text=settings.status
    end

    local function classify(part)
        if not part or not part:IsA("BasePart") or not part.Parent then return nil end
        if part==root or (character and part:IsDescendantOf(character)) then return nil end
        if CollectionService:HasTag(part,"AtlantaCoin") or
           CollectionService:HasTag(part,"Candy") or part:GetAttribute("AtlantaCoin")==true then
            return "candy"
        end
        if CollectionService:HasTag(part,"Coin") then return "coin" end
        local node=part
        for _=1,4 do
            if not node or node==Workspace then break end
            local n=string.lower(node.Name)
            if n:find("candy",1,true) or n:find("конфет",1,true)
                or n=="green" or n=="purple" or n=="cyan" then
                return "candy"
            end
            if n:find("coin",1,true) or n:find("монет",1,true) then
                return "coin"
            end
            node=node.Parent
        end
        return nil
    end
    local function addPart(obj)
        if not alive or not obj:IsA("BasePart") then return end
        local kind=classify(obj)
        if kind then collectibles[obj]=kind end
    end
    -- Initial scan is spread across frames to avoid freezing the game on a large map.
    task.spawn(function()
        local all=Workspace:GetDescendants()
        for i,obj in ipairs(all) do
            if not alive then break end
            addPart(obj)
            if i%350==0 then task.wait() end
        end
        all=nil
    end)
    connect(Workspace.DescendantAdded,addPart)
    for _,tag in ipairs({"AtlantaCoin","Candy","Coin"}) do
        connect(CollectionService:GetInstanceAddedSignal(tag),addPart)
    end
    -- Remove deleted parts promptly; weak tables then allow garbage collection.
    connect(Workspace.DescendantRemoving,function(obj)
        if not alive then return end
        if settings.target==obj then
            -- Disappearance near the player is a pickup *indicator*, not server proof.
            if root and collectibles[obj] and (root.Position-obj.Position).Magnitude<3.6 then
                settings.disappearances=settings.disappearances+1
                if collectibles[obj]=="candy" then settings.candies=settings.candies+1
                else settings.coins=settings.coins+1 end
                settings.status="Цель исчезла рядом · ищу следующую · Noclip ON"
            end
            settings.target=nil
            settings.arrivedAt=nil
            settings.lastDistance=math.huge
            nextScan=0
        end
        if collectibles[obj] then collectibles[obj]=nil;visited[obj]=nil end
    end)

    local function updateCharacter()
        character=player.Character
        humanoid=character and character:FindFirstChildOfClass("Humanoid") or nil
        root=character and character:FindFirstChild("HumanoidRootPart") or nil
        hoverForce=nil
        hoverAttachment=nil
        if character then
            for part in pairs(originalCollision) do
                if not part:IsDescendantOf(character) then originalCollision[part]=nil end
            end
        end
    end
    updateCharacter()

    local function ensureHover()
        if not root or not root.Parent then return end
        if hoverAttachment and hoverAttachment.Parent~=root then hoverAttachment=nil;hoverForce=nil end
        if not hoverAttachment then
            hoverAttachment=make("Attachment",root,{Name="HalloweenFloatAttachment"})
            hoverForce=make("VectorForce",root,{
                Name="HalloweenAntiGravity",Attachment0=hoverAttachment,
                RelativeTo=Enum.ActuatorRelativeTo.World,
                ApplyAtCenterOfMass=true
            })
        end
        -- Counteracting gravity prevents continuous fall while Noclip is always ON.
        hoverForce.Force=Vector3.new(0,root.AssemblyMass*Workspace.Gravity,0)
        if not settings.farm then
            -- Avoid drifting vertically after a flight is switched off.
            local vel=root.AssemblyLinearVelocity
            if math.abs(vel.Y)>3 then
                root.AssemblyLinearVelocity=Vector3.new(vel.X,math.clamp(vel.Y,-3,3),vel.Z)
            end
        end
    end
    local function updateNoclip()
        if not character or not character.Parent then return end
        for _,obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if originalCollision[obj]==nil then originalCollision[obj]=obj.CanCollide end
                if obj.CanCollide then obj.CanCollide=false end
                -- Restore normal visibility after older script versions.
                -- Do not reveal the naturally invisible HumanoidRootPart or hidden parts.
                if obj.Name~="HumanoidRootPart" and obj.Transparency<1
                    and obj.LocalTransparencyModifier~=0 then
                    obj.LocalTransparencyModifier=0
                end
            end
        end
        ensureHover()
    end
    local function restoreCollision()
        for part,val in pairs(originalCollision) do
            if part and part.Parent then pcall(function() part.CanCollide=val end) end
            originalCollision[part]=nil
        end
        if hoverAttachment then hoverAttachment:Destroy() end
        if hoverForce then hoverForce:Destroy() end
        hoverAttachment=nil;hoverForce=nil
    end

    local dangerPositions={}
    local nextDangerRefresh=0
    local function collectDanger()
        table.clear(dangerPositions)
        if not settings.avoidMurderer then return end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                local ch=other.Character
                local name=other:GetAttribute("Role") or other:GetAttribute("AtlantaRole") or other:GetAttribute("CurrentRole")
                if type(name)~="string" and ch then
                    name=ch:GetAttribute("Role") or ch:GetAttribute("AtlantaRole") or ch:GetAttribute("CurrentRole")
                end
                local isMurder=type(name)=="string" and string.lower(name):find("murder",1,true)~=nil
                if ch and not isMurder then
                    for _,item in ipairs(ch:GetChildren()) do
                        if item:IsA("Tool") then
                            local itemName=string.lower(item.Name)
                            if itemName=="knife" or itemName=="murderknife" then isMurder=true;break end
                        end
                    end
                end
                local rr=ch and ch:FindFirstChild("HumanoidRootPart")
                if isMurder and rr then dangerPositions[#dangerPositions+1]=rr.Position end
            end
        end
    end
    local function nearDanger(point, radius)
        if not settings.avoidMurderer then return false end
        local d=radius or 27
        for _,pos in ipairs(dangerPositions) do
            local dx=pos.X-point.X
            local dz=pos.Z-point.Z
            if dx*dx+dz*dz<d*d then return true end
        end
        return false
    end
    local function chooseNearest()
        if not root then return nil end
        -- Threat lookup runs at most once every 0.6 sec; not on each target scan.
        if os.clock()>=nextDangerRefresh then
            nextDangerRefresh=os.clock()+0.60
            collectDanger()
        end
        local origin=root.Position
        local bestCandy,bestCoin
        local candyD,coinD=math.huge,math.huge
        local now=os.clock()
        for part,kind in pairs(collectibles) do
            if part.Parent and now-(visited[part] or -999)>4 then
                local difference=part.Position-origin
                local sq=difference:Dot(difference)
                if sq<550*550 and not nearDanger(part.Position,27) then
                    if kind=="candy" and sq<candyD then
                        candyD=sq;bestCandy=part
                    elseif kind=="coin" and sq<coinD then
                        coinD=sq;bestCoin=part
                    end
                end
            elseif not part.Parent then
                collectibles[part]=nil
                visited[part]=nil
            end
        end
        return bestCandy or bestCoin
    end

    local function clearCurrentTarget()
        settings.target=nil
        settings.arrivedAt=nil
        settings.lastDistance=math.huge
        settings.lastProgressAt=os.clock()
    end
    local function setCurrentTarget(target)
        settings.target=target
        settings.arrivedAt=nil
        settings.lastDistance=math.huge
        settings.lastProgressAt=os.clock()
        settings.status=collectibles[target]=="candy" and
            "Лечу к ближайшей конфете · Noclip ON" or "Лечу к ближайшей монете · Noclip ON"
    end
    local function stopFlight()
        if humanoid and humanoid.Parent then humanoid.AutoRotate=true end
        clearCurrentTarget()
        if root and root.Parent then
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
        end
    end
    setFarm=function(value)
        settings.farm=not not value
        if not settings.farm then
            stopFlight()
            settings.status="Фарм выключен · Noclip ON"
        else
            settings.status="Ищу ближайшую конфету · Noclip ON"
            nextScan=0
        end
        refresh()
    end
    local function finishTarget(target, succeeded)
        if target then
            -- Failure gets a short delay. Completed (touched) targets get longer delay
            -- so the character will seek new items instead of circling one decoration.
            visited[target]=os.clock()-(succeeded and 0 or 2)
            if not succeeded then settings.failures=settings.failures+1 end
        end
        clearCurrentTarget()
        if succeeded then
            settings.status="Контакт с целью · ищу следующую · Noclip ON"
        end
        nextScan=0
    end
    -- Some executors expose firetouchinterest. Optional only: do not depend on it.
    -- Never call unknown game remotes or execute external code.
    local lastTouchAttempt=0
    local function tryClientTouch(target)
        if not root or not target or not target.Parent then return end
        local fn=firetouchinterest
        if type(fn)=="function" and os.clock()-lastTouchAttempt>0.12 then
            lastTouchAttempt=os.clock()
            pcall(function()
                fn(root,target,0)
                fn(root,target,1)
            end)
        end
    end
    local function updateFlight(dt)
        if not settings.farm then return end
        if not character or not humanoid or not root or humanoid.Health<=0 then
            clearCurrentTarget()
            settings.status="Ожидаю нового раунда · Noclip ON"
            return
        end
        local target=settings.target
        if not target then return end
        if not target.Parent or not target:IsDescendantOf(Workspace) then
            -- The removal event can already have counted this disappearance.
            finishTarget(target,true)
            return
        end
        if nearDanger(target.Position,25) or nearDanger(root.Position,15) then
            settings.status="Murderer рядом · меняю цель · Noclip ON"
            finishTarget(target,false)
            return
        end
        -- Fly into the actual part, rather than stopping 2.8 studs away.
        -- This increases the chance of the game's Touched / proximity logic firing.
        local goal=target.Position+Vector3.new(0,0.14,0)
        local vector=goal-root.Position
        local distance=vector.Magnitude
        if distance<=0.72 then
            if not settings.arrivedAt then
                settings.arrivedAt=os.clock()
                settings.visits=settings.visits+1
                settings.status=collectibles[target]=="candy" and
                    "Касаюсь конфеты · Noclip ON" or "Касаюсь монеты · Noclip ON"
            end
            tryClientTouch(target)
            -- Stay briefly at the part so collision / pickup scripts can react.
            if os.clock()-settings.arrivedAt>=0.27 then
                finishTarget(target,true)
            end
            return
        end
        -- Detect repeated server corrections that make the player appear stuck.
        if distance < settings.lastDistance-0.24 then
            settings.lastDistance=distance
            settings.lastProgressAt=os.clock()
        elseif os.clock()-settings.lastProgressAt>1.6 then
            settings.status="Не могу приблизиться · меняю цель · Noclip ON"
            finishTarget(target,false)
            return
        end
        local delta=math.max(0.001,math.min(dt,0.05))
        local move=math.min(distance,settings.speed*delta)
        local nextPosition=root.Position+vector.Unit*move
        local flat=Vector3.new(vector.X,0,vector.Z)
        humanoid.AutoRotate=false
        if flat.Magnitude>0.08 then
            root.CFrame=CFrame.lookAt(nextPosition,nextPosition+flat.Unit)
        else
            root.CFrame=CFrame.new(nextPosition)*root.CFrame.Rotation
        end
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end

    connect(player.CharacterAdded,function()
        task.defer(function()
            if not alive then return end
            updateCharacter()
            if character then
                humanoid=character:WaitForChild("Humanoid",8)
                root=character:WaitForChild("HumanoidRootPart",8)
            end
            if not alive then return end
            nextClip=0;nextScan=0;nextDangerRefresh=0
            clearCurrentTarget()
        end)
    end)
    connect(player.CharacterRemoving,function()
        restoreCollision()
        character=nil;humanoid=nil;root=nil
        clearCurrentTarget()
    end)
    connect(player.Idled,function()
        if not alive or not settings.antiAfk then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero, Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new())
        end)
    end)

    connectClick(farmBtn,function() setFarm(not settings.farm) end)
    connectClick(avoidBtn,function()
        settings.avoidMurderer=not settings.avoidMurderer
        nextScan=0;refresh()
    end)
    connectClick(antiBtn,function()
        settings.antiFling=not settings.antiFling
        refresh()
    end)
    connectClick(afkBtn,function()
        settings.antiAfk=not settings.antiAfk
        refresh()
    end)
    local function changeSpeed(value)
        settings.speed=math.clamp(math.floor((tonumber(value) or settings.speed)+0.5),1,100)
        speedUI()
    end
    local function sliderChange(input)
        local fraction=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        changeSpeed(1+99*fraction)
    end
    local function sliderStart(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            heldSlider=true
            sliderTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
            sliderChange(input)
        end
    end
    connect(track.InputBegan,sliderStart)
    connect(knob.InputBegan,sliderStart)
    connect(UserInputService.InputChanged,function(input)
        if heldSlider and (input.UserInputType==Enum.UserInputType.MouseMovement or input==sliderTouch) then
            sliderChange(input)
        end
        if dragging and dragPosition and
           (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragTouch) then
            local delta=input.Position-dragPosition
            panel.Position=UDim2.new(originalPanelPosition.X.Scale,originalPanelPosition.X.Offset+delta.X,
                originalPanelPosition.Y.Scale,originalPanelPosition.Y.Offset+delta.Y)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if heldSlider and (input.UserInputType==Enum.UserInputType.MouseButton1 or input==sliderTouch) then
            heldSlider=false;sliderTouch=nil
        end
        if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input==dragTouch) then
            dragging=false;dragTouch=nil
        end
    end)
    connect(speedBox.FocusLost,function()
        changeSpeed(speedBox.Text)
        speedBox.Text=tostring(settings.speed)
    end)
    connect(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
            dragPosition=input.Position
            originalPanelPosition=panel.Position
        end
    end)
    local function fitScale()
        local camera=Workspace.CurrentCamera
        local screen=camera and camera.ViewportSize or Vector2.new(400,720)
        scale.Scale=math.clamp(math.min((screen.X-16)/390,(screen.Y-20)/510),0.57,1)
    end
    fitScale()
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),fitScale)
    local open=true
    local function show(value)
        open=value
        panel.Visible=value
        if value then fitScale() end
    end
    connectClick(launcher,function() show(not open) end)
    connectClick(close,function() show(false) end)
    connect(UserInputService.InputBegan,function(input,processed)
        if not processed and input.KeyCode==Enum.KeyCode.RightShift then show(not open) end
    end)

    local t=0
    connect(RunService.Heartbeat,function(dt)
        if not alive then return end
        t=t+math.min(dt,0.1)
        updateFlight(dt)
        if t>=nextClip then
            nextClip=t+0.22
            if not character or not root or not humanoid or humanoid.Health<=0 then
                updateCharacter()
            end
            updateNoclip()
        end
        if t>=nextScan then
            nextScan=t+0.22
            if settings.farm and root and humanoid and humanoid.Health>0 and not settings.arrivedAt then
                local nearest=chooseNearest()
                if nearest and nearest~=settings.target then
                    local current=settings.target
                    local switch=(not current) or (not current.Parent)
                    if not switch then
                        local oldDist=(current.Position-root.Position).Magnitude
                        local newDist=(nearest.Position-root.Position).Magnitude
                        -- Avoid target jitter; still prefer candies to normal coins.
                        switch=newDist+3.5<oldDist or (collectibles[nearest]=="candy" and collectibles[current]~="candy")
                    end
                    if switch then setCurrentTarget(nearest) end
                elseif not nearest and not settings.target then
                    settings.status="Жду появления конфет · Noclip ON"
                end
            end
        end
        if t>=nextSafety then
            nextSafety=t+0.65
            if settings.antiFling and root and root.Parent then
                local v=root.AssemblyLinearVelocity
                local planar=Vector3.new(v.X,0,v.Z)
                if planar.Magnitude>170 then root.AssemblyLinearVelocity=Vector3.zero end
                if root.AssemblyAngularVelocity.Magnitude>45 then root.AssemblyAngularVelocity=Vector3.zero end
            end
        end
        if t>=nextUi then
            nextUi=t+0.75
            refresh()
        end
    end)

    connect(gui.Destroying,function()
        alive=false
        settings.farm=false
        stopFlight()
        restoreCollision()
        for _,con in ipairs(connections) do pcall(function() con:Disconnect() end) end
    end)

    updateNoclip() -- Noclip is enabled immediately without a UI row.
    refresh()
end, function(message)
    return tostring(message).."\n"..debug.traceback()
end)
if not ok then warn("[HALLOWEN MM2 v2.2] Startup error: "..tostring(err)) end
