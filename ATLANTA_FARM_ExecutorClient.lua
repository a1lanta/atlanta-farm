-- HALLOWEN MM2 v2.3 - installer + launcher.
-- Saves this version to executor filesystem if writefile exists.
-- Queues local reload on supported teleports; no external URLs used.
local CORE = [==[-- HALLOWEN MM2 v2.3 / nearest real pickup, ground safe flight, stable jump
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
    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:WaitForChild("PlayerGui")
    local guiName = "HALLOWEN_MM2_OPTIMIZED_V23"

    -- Running the script again safely removes earlier windows and their listeners.
    for _,name in ipairs({
        guiName, "HALLOWEN_MM2_OPTIMIZED_V22", "HALLOWEN_MM2_OPTIMIZED_V21", "HALLOWEN_MM2_OPTIMIZED_V20", "HALLOWEN_MM2_V19", "HALLOWEN_MM2_V18",
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
        farm=false, speed=25, noclip=true, autoRejoin=true,
        antiAfk=true, antiFling=true, avoidMurderer=true,
        visits=0, candies=0, coins=0, failures=0, disappearances=0,
        target=nil, arrivedAt=nil, lastDistance=math.huge, lastProgressAt=0,
        status="Готово · Noclip AUTO · скорость 25"
    }
    local alive = true
    local started = os.clock()
    local connections = {}
    local collectibles = setmetatable({}, {__mode="k"})
    local visited = setmetatable({}, {__mode="k"})
    local originalCollision = setmetatable({}, {__mode="k"})
    local character, humanoid, root
    local savedAutoRotate, savedJumpEnabled
    local floatAttachment,floatForce
    local autoRejoinCooldown = -math.huge
    local escapeGoal, escapeStarted = nil, 0
    local retryAfter = setmetatable({}, {__mode="k"})
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
    local topStripe=make("Frame",panel,{
        Name="InsetTopStripe",BorderSizePixel=0,BackgroundColor3=C.orange,
        Position=UDim2.fromOffset(11,1),Size=UDim2.new(1,-22,0,2)
    })
    radius(topStripe,2)
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
    local close=primaryButton(header,"",UDim2.fromOffset(32,32))
    close.Name="CloseCross"
    close.Position=UDim2.new(1,-45,0,17)
    close.BackgroundColor3=C.elevated
    for _,angle in ipairs({45,-45}) do
        local line=make("Frame",close,{
            Name="CrossLine",BorderSizePixel=0,BackgroundColor3=C.white,
            AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
            Size=UDim2.fromOffset(18,2),Rotation=angle
        })
        radius(line,2)
    end

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

    local footer=label(panel,"✈ TELEGRAM  •  @AtlantaRobuxShop  •  v2.3",10,C.muted,true)
    footer.TextXAlignment=Enum.TextXAlignment.Center
    footer.Position=UDim2.new(0,10,1,-30)
    footer.Size=UDim2.new(1,-20,0,23)

    local farmRow,farmBtn=settingRow(pages[1],"AUTO CANDY FARM","Ближайшие предметы из CoinContainer")
    local speedCard=card(pages[1],115)
    local speedTitle=label(speedCard,"СКОРОСТЬ ПОЛЁТА",12,C.white,true)
    speedTitle.Position=UDim2.fromOffset(13,7)
    speedTitle.Size=UDim2.new(1,-100,0,23)
    local speedBox=make("TextBox",speedCard,{
        Text="25",TextSize=14,Font=Enum.Font.GothamBold,
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
        BorderSizePixel=0,BackgroundColor3=C.orange,Size=UDim2.fromScale(24/99,1)
    })
    radius(fill,4)
    local knob=make("Frame",track,{
        BorderSizePixel=0,BackgroundColor3=C.white,Active=true,
        AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(18,18),
        Position=UDim2.fromScale(24/99,0.5)
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
    local rejoinRow,rejoinBtn=settingRow(pages[2],"AUTO REJOIN","Попытка при потере связи (не после любого кика)")
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

    -- Optional executor file API: persists settings between client restarts if supported.
    -- Rejoin and reinjection are NOT guaranteed after a full kick / process shutdown.
    local CONFIG_FILE="HALLOWEN_MM2_settings_v23.json"
    local SCRIPT_FILE="HALLOWEN_MM2_Optimized_v23.lua"
    local function saveConfig()
        local data={farm=settings.farm,speed=settings.speed,antiAfk=settings.antiAfk,
            antiFling=settings.antiFling,avoidMurderer=settings.avoidMurderer,
            autoRejoin=settings.autoRejoin}
        pcall(function()
            if type(getgenv)=="function" then getgenv().HALLOWEN_MM2_CONFIG=data end
        end)
        if type(writefile)=="function" then
            pcall(function() writefile(CONFIG_FILE,HttpService:JSONEncode(data)) end)
        end
    end
    local function loadConfig()
        local data=nil
        if type(readfile)=="function" then
            pcall(function() data=HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        end
        if type(data)~="table" then
            pcall(function() if type(getgenv)=="function" then data=getgenv().HALLOWEN_MM2_CONFIG end end)
        end
        if type(data)~="table" then return end
        for _,k in ipairs({"farm","antiAfk","antiFling","avoidMurderer","autoRejoin"}) do
            if type(data[k])=="boolean" then settings[k]=data[k] end
        end
        if type(data.speed)=="number" then settings.speed=math.clamp(math.floor(data.speed+0.5),1,100) end
    end
    loadConfig()
    -- Loader is queued only when the user has placed this standalone Lua file
    -- into their executor filesystem under SCRIPT_FILE.
    local function queueReload()
        local q=nil
        pcall(function()
            if type(queue_on_teleport)=="function" then q=queue_on_teleport end
            if not q and type(syn)=="table" then q=syn.queue_on_teleport end
        end)
        if type(q)~="function" then return false end
        local canReload=false
        pcall(function() canReload=type(isfile)=="function" and isfile(SCRIPT_FILE) end)
        if not canReload then return false end
        local snippet='local ok,data=pcall(function() return readfile("'..SCRIPT_FILE..'") end); if ok and type(data)=="string" then local fn=loadstring(data); if fn then fn() end end'
        return pcall(function() q(snippet) end)
    end
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
        setToggleText(rejoinBtn,settings.autoRejoin)
        speedUI()
        statsLines[1].Text="Подлётов к целям: "..settings.visits
        statsLines[2].Text="Целей исчезло рядом: "..settings.disappearances
        statsLines[3].Text="Исчезли рядом (вероятный сбор): "..settings.candies
        statsLines[4].Text="Ошибки маршрута: "..settings.failures
        local seconds=math.floor(os.clock()-started)
        statsLines[5].Text=string.format("Время: %02d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
        statusText.Text=settings.status
    end

    -- MM2 spawns active pickups below CoinContainer, typically with TouchInterest.
    -- Unlike name scans, this ignores random scenery/coins in unrelated folders.
    local function inCoinContainer(part)
        local ancestor=part and part.Parent
        for _=1,6 do
            if not ancestor or ancestor==Workspace then break end
            if ancestor.Name=="CoinContainer" then return true end
            ancestor=ancestor.Parent
        end
        return false
    end
    local function isPickup(part)
        return part and part:IsA("BasePart") and part:IsDescendantOf(Workspace)
            and inCoinContainer(part) and part:FindFirstChild("TouchInterest")~=nil
    end
    local function addPart(obj)
        if not alive then return end
        if obj:IsA("BasePart") then
            if isPickup(obj) then collectibles[obj]=true end
        elseif obj.Name=="TouchInterest" and obj.Parent and obj.Parent:IsA("BasePart") then
            local part=obj.Parent
            if inCoinContainer(part) then collectibles[part]=true end
        end
    end
    task.spawn(function()
        -- Initial scan is bounded to one pass and yields to avoid frame stalls.
        local all=Workspace:GetDescendants()
        for i,obj in ipairs(all) do
            if not alive then return end
            addPart(obj)
            if i%450==0 then task.wait() end
        end
        all=nil
    end)
    connect(Workspace.DescendantAdded,addPart)
    connect(Workspace.DescendantRemoving,function(obj)
        if collectibles[obj] then
            if settings.target==obj and root and root.Parent and
                (root.Position-obj.Position).Magnitude<5 then
                settings.disappearances+=1
                settings.candies+=1 -- pickup indication only, not confirmed award
            end
            collectibles[obj]=nil
            retryAfter[obj]=nil
            visited[obj]=nil
            if settings.target==obj then
                settings.target=nil
                settings.arrivedAt=nil
                nextScan=0
            end
        elseif obj.Name=="TouchInterest" and obj.Parent and collectibles[obj.Parent] then
            local part=obj.Parent
            collectibles[part]=nil
            if settings.target==part and root and root.Parent and
                (root.Position-part.Position).Magnitude<5 then
                settings.disappearances+=1
                settings.candies+=1
            end
            if settings.target==part then
                settings.target=nil
                settings.arrivedAt=nil
                nextScan=0
            end
        end
    end)

    local roundKnown=false
    local roundActive=true
    local gameplay=ReplicatedStorage:FindFirstChild("Remotes")
    gameplay=gameplay and gameplay:FindFirstChild("Gameplay")
    if gameplay then
        local startEv=gameplay:FindFirstChild("RoundStart")
        local endEv=gameplay:FindFirstChild("RoundEndFade")
        if startEv and startEv:IsA("RemoteEvent") then
            connect(startEv.OnClientEvent,function() roundKnown=true;roundActive=true;nextScan=0 end)
        end
        if endEv and endEv:IsA("RemoteEvent") then
            connect(endEv.OnClientEvent,function()
                roundKnown=true;roundActive=false;settings.target=nil;settings.arrivedAt=nil
                escapeGoal=nil;nextScan=0
            end)
        end
    end

    local function updateCharacter()
        character=player.Character
        humanoid=character and character:FindFirstChildOfClass("Humanoid") or nil
        root=character and character:FindFirstChild("HumanoidRootPart") or nil
        savedAutoRotate=nil
        savedJumpEnabled=nil
        floatAttachment=nil
        floatForce=nil
        for part in pairs(originalCollision) do
            if not character or not part:IsDescendantOf(character) then originalCollision[part]=nil end
        end
    end
    updateCharacter()
    local function flightMode(on)
        if not humanoid or not humanoid.Parent then return end
        if on then
            if savedAutoRotate==nil then savedAutoRotate=humanoid.AutoRotate end
            if savedJumpEnabled==nil then
                savedJumpEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
            end
            humanoid.AutoRotate=false
            -- Prevent jumping impulse while automatic movement owns character position.
            humanoid.Jump=false
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
            if humanoid:GetState()~=Enum.HumanoidStateType.Physics then
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end
        else
            if savedAutoRotate~=nil then humanoid.AutoRotate=savedAutoRotate end
            if savedJumpEnabled~=nil then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,savedJumpEnabled)
            end
            if humanoid.Health>0 and savedJumpEnabled~=nil then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            savedAutoRotate=nil
            savedJumpEnabled=nil
        end
    end
    local function ensureFlightSupport()
        -- Counter gravity only while farming. Unlike v2.2, this never affects normal jumping.
        if not root or not root.Parent then return end
        if floatAttachment and floatAttachment.Parent~=root then
            floatAttachment=nil;floatForce=nil
        end
        if not floatAttachment then
            floatAttachment=make("Attachment",root,{Name="HallowenFlightPoint"})
            floatForce=make("VectorForce",root,{
                Name="HallowenFlightLift",Attachment0=floatAttachment,
                RelativeTo=Enum.ActuatorRelativeTo.World,ApplyAtCenterOfMass=true
            })
        end
        if floatForce then
            floatForce.Force=Vector3.new(0,root.AssemblyMass*Workspace.Gravity,0)
        end
    end
    local function updateNoclip()
        -- Noclip is automatic ONLY during flight; normal jump works when farm is off.
        if not character or not character.Parent or not settings.farm or
            not root or not humanoid or humanoid.Health<=0 or (roundKnown and not roundActive) then return end
        for _,obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if originalCollision[obj]==nil then originalCollision[obj]=obj.CanCollide end
                if obj.CanCollide then obj.CanCollide=false end
                -- No LocalTransparencyModifier modifications: character stays visible.
            end
        end
    end
    local function restoreCollision()
        for part,val in pairs(originalCollision) do
            if part and part.Parent then pcall(function() part.CanCollide=val end) end
            originalCollision[part]=nil
        end
        flightMode(false)
        if floatForce then pcall(function() floatForce:Destroy() end) end
        if floatAttachment then pcall(function() floatAttachment:Destroy() end) end
        floatForce=nil;floatAttachment=nil
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
    -- Keep away from Murderer while preferring the nearest *actual pickup*,
    -- not a random part or a faraway coin promoted by name.
    local function chooseNearest()
        if not root then return nil end
        local origin=root.Position
        local best,bestDist=nil,math.huge
        local now=os.clock()
        for part in pairs(collectibles) do
            if not isPickup(part) then
                collectibles[part]=nil;retryAfter[part]=nil
            elseif now>=(retryAfter[part] or 0) and not nearDanger(part.Position,34) then
                local d=part.Position-origin
                local sq=d:Dot(d)
                if sq<500*500 and sq<bestDist then best=part;bestDist=sq end
            end
        end
        return best
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
        settings.status="Лечу к ближайшей конфете · Noclip ON"
    end
    local function stopFlight()
        clearCurrentTarget()
        escapeGoal=nil
        restoreCollision()
        if root and root.Parent then
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
        end
    end
    setFarm=function(value)
        local nextValue=not not value
        if settings.farm==nextValue then return end
        settings.farm=nextValue
        if not settings.farm then
            stopFlight()
            settings.status="Фарм выключен · прыжок обычный"
        else
            settings.status="Ищу ближайшую конфету · Noclip ON"
            nextScan=0
        end
        saveConfig()
        refresh()
    end
    local function finishTarget(target, succeeded)
        if target then
            -- Longer cool-down if the server left the target in place.
            retryAfter[target]=os.clock()+(succeeded and 7 or 3)
            if not succeeded then settings.failures+=1 end
        end
        clearCurrentTarget()
        if succeeded then settings.status="Контакт с целью · ищу следующую · Noclip ON" end
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
    local floorParams=RaycastParams.new()
    floorParams.FilterType=Enum.RaycastFilterType.Exclude
    floorParams.RespectCanCollide=true
    local lastFloor, lastFloorAt=nil,0
    local function safeHeight(point, target)
        local now=os.clock()
        if now-lastFloorAt>0.12 then
            floorParams.FilterDescendantsInstances=target and {character,target} or {character}
            -- Cast from the desired position to detect floors near that route segment.
            lastFloor=Workspace:Raycast(point+Vector3.new(0,4,0),Vector3.new(0,-82,0),floorParams)
            lastFloorAt=now
        end
        if lastFloor then return math.max(point.Y,lastFloor.Position.Y+2.65) end
        -- If no floor detected, do not dive rapidly into unbounded lower space.
        return math.max(point.Y,root and root.Position.Y-1 or point.Y)
    end
    local function moveStep(dest,dt)
        if not root or not root.Parent then return end
        local start=root.Position
        local vec=dest-start
        local dist=vec.Magnitude
        if dist<0.025 then return end
        local step=math.min(dist,settings.speed*math.clamp(dt,0.001,0.05))
        local pos=start+vec.Unit*step
        pos=Vector3.new(pos.X,safeHeight(pos,settings.target),pos.Z)
        local flat=Vector3.new(vec.X,0,vec.Z)
        if flat.Magnitude>0.04 then
            root.CFrame=CFrame.lookAt(pos,pos+flat.Unit)
        else
            root.CFrame=CFrame.new(pos)*root.CFrame.Rotation
        end
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end
    local function closestThreat(point)
        local nearest,dist=nil,math.huge
        for _,pos in ipairs(dangerPositions) do
            local dx=point.X-pos.X;local dz=point.Z-pos.Z
            local d=dx*dx+dz*dz
            if d<dist then nearest=pos;dist=d end
        end
        return nearest,math.sqrt(dist)
    end
    local function dodgeMurderer(murderer)
        local here=root.Position
        local away=Vector3.new(here.X-murderer.X,0,here.Z-murderer.Z)
        if away.Magnitude<0.5 then away=root.CFrame.LookVector end
        away=Vector3.new(away.X,0,away.Z).Unit
        -- Move far sideways, try a *small* descent, never below walkable floor.
        local retreat=here+away*43+Vector3.new(0,-4,0)
        escapeGoal=Vector3.new(retreat.X,safeHeight(retreat,nil),retreat.Z)
        escapeStarted=os.clock()
        clearCurrentTarget()
        settings.status="Murderer рядом · отлетаю вниз и в сторону · Noclip ON"
    end
    local function updateFlight(dt)
        if not settings.farm then return end
        if not character or not humanoid or not root or humanoid.Health<=0 then
            clearCurrentTarget();settings.status="Жду нового персонажа"
            return
        end
        if roundKnown and not roundActive then
            if savedJumpEnabled~=nil or next(originalCollision)~=nil then restoreCollision() end
            settings.status="Раунд закончился · жду следующий"
            return
        end
        flightMode(true)
        ensureFlightSupport()
        if os.clock()>=nextDangerRefresh then
            nextDangerRefresh=os.clock()+0.3
            collectDanger()
        end
        local threat,dist=closestThreat(root.Position)
        if settings.avoidMurderer and threat and dist<33 and not escapeGoal then
            dodgeMurderer(threat)
        end
        if escapeGoal then
            if (root.Position-escapeGoal).Magnitude<2.1 or os.clock()-escapeStarted>3 then
                escapeGoal=nil;nextScan=0
                settings.status="Ушёл от Murderer · ищу другую конфету"
            else
                moveStep(escapeGoal,dt)
                return
            end
        end
        local target=settings.target
        if not target then return end
        if not isPickup(target) then finishTarget(target,false);return end
        if nearDanger(target.Position,34) then
            finishTarget(target,false)
            settings.status="Конфета рядом с Murderer · пропускаю"
            return
        end
        -- Follow item at stable floor-safe height, not under the map.
        local goal=target.Position
        goal=Vector3.new(goal.X,safeHeight(goal,target),goal.Z)
        local d=(goal-root.Position).Magnitude
        if d<=1.0 then
            if not settings.arrivedAt then
                settings.arrivedAt=os.clock()
                settings.visits+=1
                settings.status="Касаюсь конфеты · Noclip ON"
            end
            tryClientTouch(target)
            -- Don't wait forever for server pickup; timeout and try other targets.
            if os.clock()-settings.arrivedAt>=0.28 then finishTarget(target,true) end
            return
        end
        if d<settings.lastDistance-0.07 then
            settings.lastDistance=d;settings.lastProgressAt=os.clock()
        elseif os.clock()-settings.lastProgressAt>1.3 then
            settings.status="Застревание · перестраиваю цель · Noclip ON"
            finishTarget(target,false)
            return
        end
        moveStep(goal,dt)
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
            escapeGoal=nil
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

    pcall(function()
        connect(GuiService.ErrorMessageChanged,function(message)
            if not alive or not settings.autoRejoin or type(message)~="string" then return end
            local m=string.lower(message)
            if not (m:find("disconnect",1,true) or m:find("connection",1,true)
                or m:find("соединен",1,true) or m:find("kick",1,true)) then return end
            if os.clock()-autoRejoinCooldown<65 or RunService:IsStudio() then return end
            autoRejoinCooldown=os.clock()
            saveConfig()
            queueReload()
            settings.status="Пробую перезайти (если Roblox разрешит)"
            task.defer(function()
                pcall(function() TeleportService:Teleport(game.PlaceId,player) end)
            end)
        end)
    end)
    pcall(function()
        connect(player.OnTeleport,function(state)
            if state==Enum.TeleportState.Started then
                saveConfig()
                if settings.autoRejoin then queueReload() end
            end
        end)
    end)

    connectClick(farmBtn,function() setFarm(not settings.farm) end)
    connectClick(avoidBtn,function()
        settings.avoidMurderer=not settings.avoidMurderer
        nextScan=0;saveConfig();refresh()
    end)
    connectClick(antiBtn,function()
        settings.antiFling=not settings.antiFling
        saveConfig();refresh()
    end)
    connectClick(afkBtn,function()
        settings.antiAfk=not settings.antiAfk
        saveConfig();refresh()
    end)
    connectClick(rejoinBtn,function()
        settings.autoRejoin=not settings.autoRejoin
        saveConfig();refresh()
        if settings.autoRejoin then queueReload() end
    end)
    local speedSaveQueued=false
    local function changeSpeed(value)
        settings.speed=math.clamp(math.floor((tonumber(value) or settings.speed)+0.5),1,100)
        speedUI()
        if not speedSaveQueued then
            speedSaveQueued=true
            task.delay(0.7,function()
                speedSaveQueued=false
                if alive then saveConfig() end
            end)
        end
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
        t+=math.min(dt,0.1)
        if settings.farm then updateFlight(dt) end
        if t>=nextClip then
            nextClip=t+0.2
            if not character or not root or not humanoid or humanoid.Health<=0 then
                updateCharacter()
            end
            if settings.farm and (not roundKnown or roundActive) then updateNoclip() end
        end
        if t>=nextScan then
            nextScan=t+0.18
            if settings.farm and root and humanoid and humanoid.Health>0
                and not settings.target and not escapeGoal and (not roundKnown or roundActive) then
                local nearest=chooseNearest()
                if nearest then setCurrentTarget(nearest)
                else settings.status="Жду появления предметов CoinContainer · Noclip ON" end
            end
        end
        if t>=nextSafety then
            nextSafety=t+0.65
            if settings.antiFling and root and root.Parent and not settings.farm then
                local v=root.AssemblyLinearVelocity
                if v.Magnitude>170 then root.AssemblyLinearVelocity=Vector3.zero end
                if root.AssemblyAngularVelocity.Magnitude>45 then root.AssemblyAngularVelocity=Vector3.zero end
            end
        end
        if t>=nextUi then nextUi=t+0.75;refresh() end
    end)

    connect(gui.Destroying,function()
        saveConfig()
        alive=false
        settings.farm=false
        stopFlight()
        restoreCollision()
        for _,con in ipairs(connections) do pcall(function() con:Disconnect() end) end
    end)

    -- Noclip switches on automatically while farming; when idle jump is normal.
    if settings.farm then nextScan=0;queueReload() end
    refresh()
end, function(message)
    return tostring(message).."\n"..debug.traceback()
end)
if not ok then warn("[HALLOWEN MM2 v2.3] Startup error: "..tostring(err)) end
]==]
if type(writefile)=="function" then
    pcall(function() writefile("HALLOWEN_MM2_Optimized_v23.lua", CORE) end)
end
local executable, parseError = loadstring(CORE)
if executable then executable()
else warn("[HALLOWEN MM2 v2.3] Load error: "..tostring(parseError)) end
