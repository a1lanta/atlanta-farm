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
