local mod = get_mod("CustomFlames")




--[[


Mod: Custom Flames

Description: Customize your flames with a variety of styles and colors! 

    Note that only those who have the mod will see this in action. Other unmodded players will not see this.

Author: Seph, a.k.a. Concoction of Constitution


]]--




-- ID for the currently active enemy-type "Ground Fire" VFX particle.
local impact_id = 0

-- Green
local cultistGreen = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"
local cultistGreenImp = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower_hit"
-- White
local renegadeWhite = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"
local renegadeWhiteImp = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower_hit"
-- Vomit
local nurgleVomit = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_projectile"
local nurgleVomitImp = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_splatter"


--[[

    In order to use enemy flame types without a litany of issues, I need to partially rewrite FlamerGasEffects update functions.
    To summarize:
        Added a life time for enemy-type ground fires, so they disappear after one second (Would otherwise last forever)
        Added a cap on maximum ground fires (Only 1) for enemy types, as they are visually extremely noisy.
        Rotates Nurgle Vomit 75 degrees to the left, as for some reason by default Nurgle Vomit spawns moving perpendicular to the forward vector.
        Rotates Nurgle Vomit Ground VFX by 75 degrees as well, so that it's horizontal on the ground and vertical on the wall (Was reversed beforehand)

    I'd really rather not hook_origin these, but I don't believe there's any other way to make this work properly.
    
    If requested, I'll release a seperate version that's more stable without the ability to change flame types (Only styles).

]]

local Action = require("scripts/utilities/weapon/action")
mod:hook_origin("FlamerGasEffects", "_update_effects", function(self, dt, t)
    local world = self._world
	local weapon_action_component = self._weapon_action_component
	local action_settings = Action.current_action_settings_from_component(weapon_action_component, self._weapon_actions)
	local fire_configuration = action_settings and action_settings.fire_configuration
	local fx_source_name = self._fx_source_name
	local spawner_pose = self._fx_extension:vfx_spawner_pose(fx_source_name)
	local from_pos = Matrix4x4.translation(spawner_pose)
	local first_person_rotation = self._first_person_component.rotation
	local position_finder_component = self._action_module_position_finder_component
	local to_pos = position_finder_component.position
	local position_valid = position_finder_component.position_valid
	local stream_effect_id = self._stream_effect_id
	local max_length = self._action_flamer_gas_component.range
	local direction = Vector3.normalize(from_pos + Vector3.multiply(Quaternion.forward(first_person_rotation), max_length) - from_pos)
	local rotation = Quaternion.look(direction)
    
    -- Rotation for when using vomit (Since it is rotated to the right by default)

    
   
	if fire_configuration then
		local effects = action_settings.fx
		local stream_effect_data = effects.stream_effect
		local should_play_husk_effect = self._fx_extension:should_play_husk_effect()
		local stream_effect_name = should_play_husk_effect and stream_effect_data.name_3p or stream_effect_data.name
		local move_after_stop = effects.move_after_stop
		local effect_duration = effects.duration
		local weapon_extension = self._weapon_extension
		local fire_time = 0.3

        if stream_effect_name == nurgleVomit then
            local eulerRot = Vector3(Quaternion.to_euler_angles_xyz(rotation))
            eulerRot[3] = eulerRot[3] + 75
            if eulerRot[3] >= 180 then
                eulerRot[3] = eulerRot[3] - 360
            end
            rotation = Quaternion.from_euler_angles_xyz(eulerRot[1], eulerRot[2], eulerRot[3])
        end

		if weapon_extension then
			local weapon_handling_template = weapon_extension:weapon_handling_template()
			fire_time = weapon_handling_template.fire_rate.fire_time
		end

		fire_time = fire_time * 0.7
		local start_t = weapon_action_component.start_t or t
		local time_in_action = t - start_t

		if fire_time <= time_in_action and (not effect_duration or effect_duration > time_in_action - fire_time) then
			local sound_direction = direction
			local distance = max_length

			if position_valid then
				local direction_vector = to_pos - from_pos
				distance = Vector3.length(direction_vector)
				sound_direction = Vector3.normalize(direction_vector)
			end

			local sound_distance = math.clamp(distance - 0.1, 0, 4)
			local wanted_sound_source_pos = from_pos + sound_direction * sound_distance

			if not stream_effect_id then
				local effect_id = World.create_particles(world, stream_effect_name, from_pos, rotation, nil, self._particle_group_id)
                
				self._stream_effect_id = effect_id
				self._move_after_stop = move_after_stop
				local in_first_person = self._is_in_first_person

				if in_first_person then
					World.set_particles_use_custom_fov(world, effect_id, true)
				end

				local looping_sfx = effects.looping_3d_sound_effect

				if looping_sfx then
					self._looping_source_id = WwiseWorld.make_manual_source(self._wwise_world, wanted_sound_source_pos, rotation)

					WwiseWorld.trigger_resource_event(self._wwise_world, looping_sfx, self._looping_source_id)

					self._source_position = Vector3Box(wanted_sound_source_pos)
					self._stop_looping_sfx_event = effects.stop_looping_3d_sound_effect
				end
			else
				World.move_particles(world, stream_effect_id, from_pos, rotation)
				if self._looping_source_id then
					local current_pos = self._source_position:unbox()
					local new_pos = Vector3.lerp(current_pos, wanted_sound_source_pos, dt * 7)

					self._source_position:store(new_pos)
					WwiseWorld.set_source_position(self._wwise_world, self._looping_source_id, new_pos)
				end
			end
			local speed = stream_effect_data.speed
			local life = distance / speed
            local variable_index
            if stream_effect_name ~= cultistGreen and stream_effect_name ~= renegadeWhite and stream_effect_name ~= nurgleVomit then
    			variable_index = World.find_particles_variable(self._world, stream_effect_name, "life")
            else
                variable_index = 1
            end

			World.set_particles_variable(self._world, self._stream_effect_id, variable_index, Vector3(life, life, life))


			if self._impact_spawn_time == 0 and position_valid then
				local impact_time = t + life * 1.25
				local impact_index = self._impact_index
				local impact_data = self._impact_data
				local data = impact_data[impact_index]
				local normal = position_finder_component.normal

				data.position:store(to_pos)
				data.normal:store(normal)

				data.time = impact_time
				data.effect_name = effects.impact_effect
				local new_impact_index = nil

				if impact_index == #impact_data then
					new_impact_index = 1
				else
					new_impact_index = impact_index + 1
				end

				self._impact_index = new_impact_index
				self._impact_spawn_time = self._impact_spawn_rate
			end
		else
			self:_destroy_effects(true, rotation)
		end
	else
		self:_destroy_effects(true, rotation)
	end

	self:_update_moving_lingering_effects(dt, t)
	self:_update_impact_effects(dt, t)

    
end)
local life_time = 1
mod:hook_origin("FlamerGasEffects", "_update_impact_effects", function(self, dt, t)
    local impact_data = self._impact_data
	local particle_group_id = self._particle_group_id
    local impact_name = ""
    --if impact_name == cultistGreenImp or impact_name == renegadeWhiteImp or impact_name == nurgleVomitImp then
    life_time = life_time - dt
    if life_time <= 0 and World.are_particles_playing(self._world, impact_id) then
        World.stop_spawning_particles(self._world, impact_id)
    end
    --end
	for i = 1, #impact_data do
		local data = impact_data[i]
		local impact_time = data.time

		if impact_time and impact_time < t then
			local position = data.position:unbox()
			local normal = data.normal:unbox()
			local rotation = Quaternion.look(normal)
			local effect_name = data.effect_name
            if effect_name then
                impact_name = effect_name
            end
            
            if impact_name == cultistGreenImp or impact_name == renegadeWhiteImp or impact_name == nurgleVomitImp then
                if World.are_particles_playing(self._world, impact_id) then
                    World.stop_spawning_particles(self._world, impact_id)
                end
            end
            life_time = 1

            if impact_name == nurgleVomitImp then
                local eulerRot = Vector3(Quaternion.to_euler_angles_xyz(rotation))
                eulerRot[1] = eulerRot[1] - 75
                if eulerRot[1] <= -180 then
                    eulerRot[1] = eulerRot[1] + 360
                end
                rotation = Quaternion.from_euler_angles_xyz(eulerRot[1], eulerRot[2], eulerRot[3])
            end

			impact_id = World.create_particles(self._world, effect_name, position, rotation, nil, particle_group_id)
            

			data.time = nil
			data.effect_name = nil
		end
	end
	self._impact_spawn_time = math.max(self._impact_spawn_time - dt, 0)
end)



-- Load in Flamer/Flamestaff objects, which allows us to customize their settings on the fly.
local Flamer = require("scripts/settings/equipment/weapon_templates/flamers/flamer_p1_m1")
local Flamestaff = require("scripts/settings/equipment/weapon_templates/force_staffs/forcestaff_p2_m1")

function loadColors()
    --[[
    
    Pre-load VFX to prevent crashing by caching them into dummy variables under both Flamer and Flamestaff action settings.

    ]]
    -- Flamer preload
    -- Orange
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx1 = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx2 = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx3 = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control"
    -- Blue
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx4 = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx5 = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_code_control"
    -- Green
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx6 = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower_hit"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx7 = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"
    -- White
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx8 = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx9 = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower_hit"
    -- Vomit
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx10 = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_projectile"
    Flamer.actions.action_shoot_braced.fx.stream_effect.name_loadfx11 = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_splatter"

    -- Flamestaff preload
    -- Orange
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx1 = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx2 = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx3 = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control"
    -- Blue
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx4 = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx5 = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_code_control"
    -- Green
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx6 = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower_hit"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx7 = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"
    -- White
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx8 = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx9 = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower_hit"
    -- Vomit
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx10 = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_projectile"
    Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_loadfx11 = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_splatter"
end





--[[

    Change Flame "Color", but it's more like changing the flame "type".

    Default flame is Orange/Blue (Zealot/Psyker fire), which are the intended flame types for players.

    Then there's Cultist Green, Renegade White, and Nurgle Vomit. All of these are enemy types, and not intended for players to use.
    It took a while to get them working properly, as they're missing some key variables and have other strange side effects.

    Fun fact, Beast of Nurgle vomit is actually referred to as a flamer particle, interestingly enough.

    I wonder if there's other VFX that can be used as flames, too. I'm probably not going to test, but feel free to experiment. Let me know how it goes!

    "flame" refers to the primary fire (burst) VFX for the weapon.
    "flameHeld" refers to the secondary fire (braced/charged) VFX for the weapon.
    "iFlame" refers to the "ground fire" VFX that spawn when flames come into contact with the ground or walls.

    Enemy flames have unique ground fire. Cultist/Renegade has a pillar of flames that shoot out of the ground, and Nurgle has a splashing effect.

    These are all visual when applied to the flamer/flamestaff, and function identically to vanilla, unmodded fire.

]]

local flameColors = {
    "Orange", 
    "Blue", 
    "Green", 
    "White", 
    "Vomit",
}

local flameColor
local flame
local flameHeld
local flame3p
local iFlame

function changeFlameColor(flameType, weapon)

    flameColor = flameColors[flameType]

    if flameType == 1 then
        -- Flamer Orange
        flame = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"
        flameHeld = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control"
        iFlame = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"


        changeFlamerBurst(mod:get("flamer_burst"))
        changeFlamerHeld(mod:get("flamer_held"))

        -- TODO: Check if disabling this is safe
        changeFlamestaffBurst(mod:get("flamestaff_burst"))
        changeFlamestaffHeld(mod:get("flamestaff_held"))
    elseif flameType == 2 then
        -- Psyker Blue
        flame = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_code_control"
        flameHeld = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_code_control"
        iFlame = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay"
        
        -- TODO: Check if disabling this is safe
        changeFlamerBurst(mod:get("flamer_burst"))
        changeFlamerHeld(mod:get("flamer_held"))
        changeFlamestaffBurst(mod:get("flamestaff_burst"))
        changeFlamestaffHeld(mod:get("flamestaff_held"))

    elseif flameType == 3 then
        

        -- Cultist Green
        flame = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"
        flameHeld = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"
        iFlame = "content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower_hit"

        Flamer.actions.action_shoot.fx.move_after_stop = true
        Flamer.actions.action_shoot.fx.stream_effect.speed = 50
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 50
    
    elseif flameType == 4 then
        
        -- Renegade White
        flame = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"
        flameHeld = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"
        iFlame = "content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower_hit"

        Flamer.actions.action_shoot.fx.move_after_stop = true
        Flamer.actions.action_shoot.fx.stream_effect.speed = 50
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 50

    elseif flameType == 5 then
        -- Nurgle Vomit
        flame = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_projectile"
        flameHeld = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_projectile"
        iFlame = "content/fx/particles/enemies/beast_of_nurgle/bon_vomit_splatter"

        Flamer.actions.action_shoot.fx.move_after_stop = true
        Flamer.actions.action_shoot.fx.stream_effect.speed = 50
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 50
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 50
    end

    -- Apply flame type changes to both weapons.
    

    -- !!!TODO!!!: See if I can seperate Flamer and Flamestaff type customization.

    if weapon == 1 then
        -- Ground Fire Type
        Flamer.actions.action_shoot.fx.impact_effect = iFlame
        Flamer.actions.action_shoot_braced.fx.impact_effect = iFlame
        -- Burst Fire Type
        Flamer.actions.action_shoot.fx.stream_effect.name = flame
        Flamer.actions.action_shoot.fx.stream_effect.name_3p = flame--3p
        -- Held Fire Type
        Flamer.actions.action_shoot_braced.fx.stream_effect.name = flameHeld
        Flamer.actions.action_shoot_braced.fx.stream_effect.name_3p = flameHeld--3p
    elseif weapon == 2 then
        -- Ground Fire Type
        Flamestaff.actions.action_shoot_flame.fx.impact_effect = iFlame
        Flamestaff.actions.action_shoot_charged_flame.fx.impact_effect = iFlame
        -- Burst Fire Type
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.name = flame
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.name_3p = flame--3p
        -- Charged Fire Type
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name = flame
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.name_3p = flame--3p
    end
end





--[[

Quick explanation for the code below.

This is the code for the different presets you can choose to alter flame behavior with Orange/Blue fire.
Currently, it does not affect enemy fire (Cultist Green, Renegade White, Nurgle Vomit) as I have not yet found control of all particles involving those three.

"Burst" and "Held" refer to the primary and secondary fire of the weapon.
"Flamer" and "Flamestaff" in the function names (E.g. "changeFlamerBurst") refers only to the type of flame being cast out, regardless of the weapon casting them.

However, the Flamer and Flamestaff objects (E.g. Flamer.actions.etc) do, in fact, refer to their respective weapons.

All effects (Rising Flame, Clean Stream, etc.) are only modifications of the speed of the projectile.
Effects such as flame particles rising for orange fire are purely strange side effects as a result of this change, nothing more.

The type of the fire and the weapon they are being cast from (Flamestaff/Flamer) BOTH determine how 'speed' affects the VFX.

]]


-- Change the speed of the flame fx movement, for orange (zealot) flame type.
function changeFlamerBurst(flameType)
    if flameColor ~= "Orange" then
        return
    end
    if flameType == 1 then
        --Pilot Light
        Flamer.actions.action_shoot.fx.stream_effect.speed = -300
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = -300
    elseif flameType == 2 then
        --Small Shots
        Flamer.actions.action_shoot.fx.stream_effect.speed = 10
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 10
    elseif flameType == 3 then
        --Short Blast
        Flamer.actions.action_shoot.fx.stream_effect.speed = 150
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 150
    elseif flameType == 999 then
        --Default Burst
        Flamer.actions.action_shoot.fx.stream_effect.speed = 35
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 35
    end
end

-- Change the speed of the flame fx movement, for orange (zealot) flame type.
function changeFlamerHeld(flameType)
    if flameColor ~= "Orange" then
        return
    end
    if flameType == 1 then
        --Clean Stream
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 0
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 7.5
    elseif flameType == 2 then
        --Forceful Blaze
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 150
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 150
    elseif flameType == 3 then
        --Rising Flame
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 7.5
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 0
    elseif flameType == 999 then
        --Default Spread
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 45
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 45
    end
end

-- Change the speed of the flame fx movement, for blue (psyker) flame type.
function changeFlamestaffBurst(flameType)
    if flameColor ~= "Blue" then
        return
    end
    if flameType == 1 then
        --Quick Puff
        Flamer.actions.action_shoot.fx.stream_effect.speed = -300
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = -300
    elseif flameType == 2 then
        --Rapid Wisps
        Flamer.actions.action_shoot.fx.stream_effect.speed = 5
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 3
    elseif flameType == 3 then
        --Short Blast
        Flamer.actions.action_shoot.fx.stream_effect.speed = 300
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 150
    elseif flameType == 999 then
        --Default Burst
        Flamer.actions.action_shoot.fx.stream_effect.speed = 33
        Flamestaff.actions.action_shoot_flame.fx.stream_effect.speed = 33
    end
end

-- Change the speed of the flame fx movement, for blue (psyker) flame type.
function changeFlamestaffHeld(flameType)
    if flameColor ~= "Blue" then
        return
    end
    if flameType == 1 then
        --Mini Match
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 0
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 0
    elseif flameType == 2 then
        --Octane Flare
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 150
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 150
    elseif flameType == 3 then
        --Intermittent Torch
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 17.5
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 12.5
    elseif flameType == 999 then
        --Default Spread
        Flamer.actions.action_shoot_braced.fx.stream_effect.speed = 35
        Flamestaff.actions.action_shoot_charged_flame.fx.stream_effect.speed = 35
    end
end


-- Apply respective setting when setting is changed.
function mod.on_setting_changed(setting_id)
    if setting_id == "flamer_burst" then
        changeFlamerBurst(mod:get("flamer_burst"))
    elseif setting_id == "flamer_held" then
        changeFlamerHeld(mod:get("flamer_held"))
    elseif setting_id == "flamestaff_burst" then
        changeFlamestaffBurst(mod:get("flamestaff_burst"))
    elseif setting_id == "flamestaff_held" then
        changeFlamestaffHeld(mod:get("flamestaff_held"))
    elseif setting_id == "flamer_color" then
        changeFlameColor(mod:get("flamer_color"), 1)
    elseif setting_id == "flamestaff_color" then
        changeFlameColor(mod:get("flamestaff_color"), 2)
    end
end

-- Apply settings when mod is enabled.
function mod.on_enabled()
    changeFlamerBurst(mod:get("flamer_burst"))
    changeFlamerHeld(mod:get("flamer_held"))
    changeFlamestaffBurst(mod:get("flamestaff_burst"))
    changeFlamestaffHeld(mod:get("flamestaff_held"))
    changeFlameColor(mod:get("flamer_color"), 1)
    changeFlameColor(mod:get("flamestaff_color"), 2)
    loadColors()
end