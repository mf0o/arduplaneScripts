-- land on failsafe script
-- v0.0.1
-- desc: this script will be only activated in a failsafe condition
--       and will reduce altitude after successsful RTL to home or a rally point
--       then, after landing_altitude is reached, turn into wind
--       switch to FBWBA and disarm to touchdown level

-- modes
-- idle             : script is doing nothing
-- failsafe         : failsafe detected and flying
-- decendingAtHome  : we are at home/rally point
-- findWindDir      : landing altitude reached, continue loiter into wind
-- windMatch        : heading into wind, landing


local SITL_wind = false             -- only use with SITL
local scriptmode = 'undef'          -- initial state, dont touch
local alt_offset_default = 0        -- set this same to your ALT_OFFSET in ardupilot

local decent_rate_meter = 1         -- how many meter should we reduce per second?
local landing_altitude = 10         -- default: 10 - at what altitude should we find wind and switch to FBWA?
-- fixme local landing_force_timeout
-- fixme, final landing mode as param?

local safety_disarm = true          -- enable to disarm if altitude below 0 (only in failsafe condition at home)
local debug = true                  -- enable to print wind and heading every 10 seconds on a real plane


--todo:
-- final landing should be done directly into home position and still into wind
-- instead of level FBWA, and risk of a stall, use landing parameter to pitch down
-- or: continue decrease altitude on last mile

function update()

  if rc:has_valid_input() then
    -- reset the alt offset
    if not ( scriptmode == 'idle') then
      param:set('ALT_OFFSET', alt_offset_default)
      gcs:send_text(5, string.format("FSS: %s ALT_OFFSET reset ",scriptmode))
      scriptmode = 'idle'
    end
    if debug then
        local wind = ahrs:wind_estimate()

        -- wind is in NED, convert for readability
        local wind_north = wind:x()
        local wind_east = wind:y()

        wind_dir = (math.deg(math.atan(wind_east,wind_north)))
        if (wind_dir < 0) then
          wind_dir = (wind_dir + 360) % 360
        end
        yaw_rad = ahrs:get_yaw()
        heading = math.deg(yaw_rad)
        if (heading < 0) then
          heading = (heading + 360) % 360
        end

        if wind_dir and heading then
          diff = math.abs(math.fmod((180 + math.abs(wind_dir - heading ) ),360)-180)
          gcs:send_text(5, string.format("FSS: DEBUG: winddir: %0.2f heading %0.2f diff: %0.2f",wind_dir,heading,diff))
        end
    end

    return update, 10000 -- idle for 10 seconds
  end -- fixme make this an else?

  local position = ahrs:get_position()
  local home = ahrs:get_home()

  if position and home and vehicle:get_likely_flying() and not rc:has_valid_input() then
    scriptmode = 'failsafe'

    -- Read altitude
    local dist = ahrs:get_relative_position_NED_home()
    local altitude = -1*dist:z()

    -- Read the radius we expect to circle at when we get home
    local home_reached_rad
    local value = param:get('RTL_RADIUS')
    if value then
      value = math.abs(value)
      if value > 0 then
        home_reached_rad = math.abs(value) * 2
      else 
        value = param:get('WP_LOITER_RAD')
        if value then
          home_reached_rad = math.abs(value) * 2
        else
          error('LUA: get WP_LOITER_RAD failed')
        end
      end
    else
      error('LUA: get RTL_RADIUS failed')
    end

    if (vehicle:get_mode() == 11) and (vehicle:get_wp_distance_m() > home_reached_rad) then
      gcs:send_text(3, string.format("FSS: %s : alt %s approaching",scriptmode, altitude))

    elseif vehicle:get_mode() == 11 and vehicle:get_wp_distance_m() < home_reached_rad then
      scriptmode='decendingAtHome'

      if altitude > landing_altitude then
        gcs:send_text(3, string.format("FSS: %s : alt %s ",scriptmode, altitude))
        target_alt_offset = param:get('ALT_OFFSET') - decent_rate_meter
        param:set('ALT_OFFSET', target_alt_offset)
        return update, 1000  -- decrease altitude each second

      -- fixme add a timeout here  
      -- landing_force_timeout
      -- elseif at_landing_altitude_elaped > landing_force_timeout

      elseif altitude < 0 and safety_disarm then
        arming:disarm()

      else --fixme timeout needed
        scriptmode = 'findWindDir'
        
        -- finding wind
        if home and position then
          local wind = ahrs:wind_estimate()
          
          -- wind is in NED, convert for readability
          local wind_north = wind:x()
          local wind_east = wind:y()

          wind_dir = (math.deg(math.atan(wind_east,wind_north)))
          if (wind_dir < 0) then
            wind_dir = (wind_dir + 360) % 360
          end

          -- hard code wind for testing
          if SITL_wind then
            -- only safe to read from params at a high rate because we are in SITL
            -- don't do this on a real vehicle
            wind_dir = param:get('SIM_WIND_DIR')
          end
            --   gcs:send_text(0, string.format("Wind: north %0.2f, east  %0.2f",wind_north,wind_east))
        end
          
        yaw_rad = ahrs:get_yaw()
        heading = math.deg(yaw_rad)
        if (heading < 0) then
          heading = (heading + 360) % 360
        end

        if wind_dir and heading then
          diff = math.abs(math.fmod((180 + math.abs(wind_dir - heading ) ),360)-180)

          if diff < 10 then
            scriptmode = 'windMatch' 
            vehicle:set_mode(5) -- FBWA
            arming:disarm()
            param:set('ALT_OFFSET', alt_offset_default)
            gcs:send_text(3, string.format("FSS: %s : wind %s yaw %s LANDING", scriptmode, wind_dir, heading))
          else
            --gcs:send_text(0, scriptmode .. ": waiting for wind match")
            gcs:send_text(3, string.format("FSS: %s : wind %s yaw %s", scriptmode, wind_dir, heading))
            return update, 500 -- watch for matching heading twice a second
          end
        else
          gcs:send_text(0, string.format("FSS: %s : could not find wind LANDING", scriptmode))          
          vehicle:set_mode(5)
          arming:disarm()
          param:set('ALT_OFFSET', alt_offset_default)
        end
       
      end

    else
      gcs:send_text(3, string.format("FSS: %s : mode %s ",scriptmode, vehicle:get_mode() ))
      return update, 1000
    end

  else
    gcs:send_text(5, string.format("FSS: %s : not flying", scriptmode))
  end -- end if flying

  return update, 1000 -- fixme
  --  return update, 5000 -- monitor RTL each 5 seconds
end
return update()

