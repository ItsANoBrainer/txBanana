local bananaing = false
local banana = nil
local target = nil

local function CleanupBanana()
    if not banana then return end

    SetEntityAsMissionEntity(banana)
    DeleteObject(banana)
end

local function StartBanana()
    local ped = PlayerPedId()

    -- Banana Object Handling
    local bananaHash = GetHashKey("ng_proc_food_nana1a")
    RequestModel(bananaHash)
    while (not HasModelLoaded(bananaHash)) do
        Wait(1)
    end

    CleanupBanana()
    banana = CreateObject(bananaHash, x, y, z, true, false, true)
    SetModelAsNoLongerNeeded(bananaHash)

    PlaceObjectOnGroundProperly(banana)
    SetEntityAsMissionEntity(banana)
    AttachEntityToEntity(banana, ped, GetPedBoneIndex(ped, 18905), 0.2, 0.03, 0.03, 20.0, 190.0, -45.0, true, true, false, true, 1, true)

    -- Animation Handling
    RequestAnimDict("anim@mp_point")
    while not HasAnimDictLoaded("anim@mp_point") do Wait(0) end

    SetPedCurrentWeaponVisible(ped, 0, 1, 1, 1)
    SetPedConfigFlag(ped, 36, 1)
	TaskMoveNetworkByName(ped, 'task_mp_pointing', 0.5, false, 'anim@mp_point', 24)
    RemoveAnimDict("anim@mp_point")
end

local function StopBanana()
    local ped = PlayerPedId()
    target = nil

    -- Animation Handling
	RequestTaskMoveNetworkStateTransition(ped, 'Stop')
    if not IsPedInjured(ped) then ClearPedSecondaryTask(ped) end
    if not IsPedInAnyVehicle(ped, 1) then SetPedCurrentWeaponVisible(ped, 1, 1, 1, 1) end

    SetPedConfigFlag(ped, 36, 0)
    ClearPedSecondaryTask(PlayerPedId())
end

-- This crashes the client if used on a Player Ped =(
local function OutlineTarget(enabled)
    SetEntityDrawOutline(banana, enabled)
    SetEntityDrawOutlineColor(255.0, 255.0, 0.0, 0)
    if not enabled then target = nil end
end

local function RotationToDirection(rotation)
	local adjustedRotation = {
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction = {
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function RayCastGamePlayCamera()
	local cameraCoord = GetGameplayCamCoord()
    local entityCoord = GetEntityCoords(PlayerPedId())
	local direction = RotationToDirection(GetGameplayCamRot())
    local distance = 50.0
	local destination = vector3(cameraCoord.x + direction.x * distance, cameraCoord.y + direction.y * distance, cameraCoord.z + direction.z * distance)

	local _, _, _, _, entityHit = GetShapeTestResult(StartShapeTestRay(entityCoord.x, entityCoord.y, entityCoord.z+0.6, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    -- DrawLine(entityCoord.x, entityCoord.y, entityCoord.z+0.6, destination.x, destination.y, destination.z, 255, 255, 0, 0.5)
    return entityHit
end

RegisterCommand('txBanana', function()
    CleanupBanana()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then
        bananaing = not bananaing
        if bananaing then StartBanana() end

        CreateThread(function()
            while bananaing do
                local ped = PlayerPedId()

                local camPitch = GetGameplayCamRelativePitch()
                if camPitch < -70.0 then
                    camPitch = -70.0
                elseif camPitch > 42.0 then
                    camPitch = 42.0
                end
                camPitch = (camPitch + 70.0) / 112.0

                local camHeading = GetGameplayCamRelativeHeading()
                if camHeading < -180.0 then
                    camHeading = -180.0
                elseif camHeading > 180.0 then
                    camHeading = 180.0
                end
                camHeading = (camHeading + 180.0) / 360.0

                -- Raycasting Logic
                local entityHit = RayCastGamePlayCamera()

                -- Point Location Logic
                SetTaskMoveNetworkSignalFloat(ped, "Pitch", camPitch)
                SetTaskMoveNetworkSignalFloat(ped, "Heading", camHeading * -1.0 + 1.0)
                SetTaskMoveNetworkSignalBool(ped, "isBlocked", false)
                SetTaskMoveNetworkSignalBool(ped, "isFirstPerson", GetCamViewModeForContext(GetCamActiveViewModeContext()) == 4)

                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)

                -- Detect Entity Hit
                if entityHit ~= 0 and IsEntityAPed(entityHit) then

                    if entityHit ~= target then
                        if target then OutlineTarget(false) end
                        target = entityHit
                        OutlineTarget(true)
                        print('Pointing at Player ID', GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
                    end

                    if target then
                        -- Handle Left Click
                        if IsDisabledControlJustPressed(0, 24) and target then
                            ExecuteCommand('tx '..GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
                            print('Shot Player ID', GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
                        end

                        -- Handle Right Click
                        if IsDisabledControlJustPressed(0, 25) then
                            print('Right Clicked ID', GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
                        end
                    end
                elseif target then
                    print('Stopped Point at ID', GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
                    target = nil
                    OutlineTarget(false)
                end
                Wait(0)
            end

            -- Once bananaing is done, cleanup
            StopBanana()
        end)
    end
end)

-- Handle Cleanup on Resource Stop
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then CleanupBanana() end
end)

-- Handle Keymapping
RegisterKeyMapping('txBanana', 'Toggles Banana', 'keyboard', 'B')