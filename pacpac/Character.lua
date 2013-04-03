-- Character.lua
--
-- A class to work with the hero and ghosts.
--
-- Use like this:
--     local Character = require('Character')
--

local draw = require('draw')

local Character = {} ; Character.__index = Character

-- shape is 'hero' or 'ghost'; color is in {'red', 'pink', 'blue', 'orange'}.
function Character.new(shape, color)
  local c = setmetatable({shape = shape, color = color}, Character)
  c.is_fake = false
  c:reset()
  return c
end

function Character:is_dead()
  return self.dead_till > clock
end

function Character:is_weak()
  return super_mode_till > clock and not self.eaten
end

function Character:reset()
  self.dead_till = -1
  self.mode = 'normal'  -- Can be 'freemove' for ghosts through the hotel door.
  self.eaten = false  -- To avoid ghosts being double eaten.
  local start_pos = level.start_pos[self.color]
  self.x = start_pos[1]
  self.y = start_pos[2]
  if self.shape == 'hero' then
    self.dir = {-1, 0}
    self.next_dir = nil
  else
    -- It's a ghost.
    if self.color == 'red' then
      self.dir = {1, 0}
      self.exit_time = math.huge
    elseif self.color == 'pink' then
      self.dir = {0, 0}
      self.exit_time = clock + 6
    elseif self.color == 'blue' then
      self.dir = {0, 0}
      self.exit_time = clock + 12
    elseif self.color == 'orange' then
      self.dir = {0, 0}
      self.exit_time = clock + 18
    end
  end
end

function Character:speed()
  local hotel_pos = level.ghost_hotel.outside
  if self.shape == 'hero' then return 4 end
  if self:is_dead() then
    -- The dead move fast, except near the hotel so they don't miss the door.
    if self:dist_to_pt(hotel_pos) < 1 then return 4 end
    return 8
  end
  if self:is_weak() then
    return 2.5
  else
    return 4
  end
end

function Character:target()
  local hotel = level.ghost_hotel
  if self.shape == 'hero' then return {} end
  if self:is_dead() then return hotel.inside end
  if self.mode == 'freemove' then return hotel.outside end
  if self:is_weak() then
    return {math.random() * 19, math.random() * 22}
  end
  if self.color == 'red' then
    if ghost_mode == 'scatter' then return {18.5, 2.5} end
    if ghost_mode == 'pursue' then
      return {man.x, man.y}
    end
  elseif self.color == 'pink' then
    if ghost_mode == 'scatter' then return {2.5, 2.5} end
    if ghost_mode == 'pursue' then
      return {man.x + man.dir[1] * 2, man.y + man.dir[2] * 2}
    end
  elseif self.color == 'blue' then
    if ghost_mode == 'scatter' then return {18.5, 21.5} end
    if ghost_mode == 'pursue' then
      local v1 = {man.x + man.dir[1], man.y + man.dir[2]}
      local v2 = {v1[1] - red.x, v1[2] - red.y}
      return {v1[1] + v2[1], v1[2] + v2[2]}
    end
  elseif self.color == 'orange' then
    local default = {2.5, 21.5}
    if ghost_mode == 'scatter' then return default end
    if ghost_mode == 'pursue' then
      local dist_v = {self.x - man.x, self.y - man.y}
      local dist_sq = dist_v[1] * dist_v[1] + dist_v[2] * dist_v[2]
      if dist_sq > 16 then
        return {man.x, man.y}
      else
        return default
      end
    end
  end
end

function Character:snap_into_place()
  if self.dir[1] == 0 then
    self.x = math.floor(2 * self.x + 0.5) / 2
  end
  if self.dir[2] == 0 then
    self.y = math.floor(2 * self.y + 0.5) / 2
  end
end

function Character:can_go_in_dir(dir)
  if dir == nil then return false end
  local new_x, new_y = self.x + dir[1], self.y + dir[2]
  local can_pass_hotel_door = (self.mode == 'freemove' or self:is_dead())
  return not xy_hits_a_wall(new_x, new_y, can_pass_hotel_door)
end

function Character:dot_prod(dir)
  local target = self:target()
  local target_dir = {target[1] - self.x, target[2] - self.y}
  return target_dir[1] * dir[1] + target_dir[2] * dir[2]
end

-- Returns available directions, skipping u-turns unless it's the only choice.
-- This is for use by ghosts.
function Character:available_dirs()
  local turn = {self.dir[2], self.dir[1]}
  local turns = {}
  if self:can_go_in_dir(self.dir) then turns = {self.dir} end
  for sign = -1, 1, 2 do
    local t = {turn[1] * sign, turn[2] * sign}
    if self:can_go_in_dir(t) then table.insert(turns, t) end
  end
  if #turns == 0 then table.insert(turns, {-self.dir[1], -self.dir[2]}) end
  return turns
end

-- Switch self.dir to dir if it is more aligned with getting to the target.
function Character:turn_if_better(turn)
  if self:dot_prod(turn) > self:dot_prod(self.dir) then
    self.dir = turn
    self.last_turn = {self.x, self.y}
  end
end

function Character:next_grid_point()
  local pt = {self.x, self.y}
  for i = 1, 2 do
    -- This if block is more readable than a short but opaque mathy summary.
    if self.dir[i] == 1 then
      pt[i] = math.floor(pt[i] + 0.5) + 0.5
    elseif self.dir[i] == -1 then
      pt[i] = math.ceil(pt[i] - 0.5) - 0.5
    elseif self.dir[i] ~= 0 then
      print('Error: Unexpected dir value (' .. self.dir[i] .. ') found.')
    end
  end
  return pt
end

function Character:update(dt)
  if pause_till > clock then return end

  -- Check if it's time for a ghost to exit the ghost hotel.
  if self.shape == 'ghost' and self.exit_time < clock then
    self.mode = 'freemove'
    self.exit_time = math.huge
    self.dir = {0, -1}
  end


  local movement = dt * self:speed()
  while movement > 0 do
    -- This is inside the loop because the hero can hit a wall and stop.
    if self.dir[1] == 0 and self.dir[2] == 0 then return end

    local pt = self:next_grid_point()
    local dist = self:dist_to_pt(pt)
    if dist <= movement then
      self.x, self.y = pt[1], pt[2]
      self:reached_grid_point()
    else
      self.x = self.x + self.dir[1] * movement
      self.y = self.y + self.dir[2] * movement
    end
    movement = movement - dist  -- May end up below 0; that's ok.
  end

  self:check_for_side_warps()
  self:check_if_done_exiting_hotel()
  self:register_dots_eaten()
end

function Character:reached_grid_point()
  if self.x < 1 or self.x > (#map + 1) then return end

  if self.shape == 'hero' then
    if self:can_go_in_dir(self.next_dir) then
      self.dir = self.next_dir
      self.next_dir = nil
    elseif not self:can_go_in_dir(self.dir) then
      self.dir = {0, 0}
    end
  end

  if self.shape == 'ghost' then
    local dirs = self:available_dirs()
    self.dir = dirs[1]
    for k, t in pairs(dirs) do self:turn_if_better(t) end
  end

end

-- If a character is far to the left right, they jump across the map.
function Character:check_for_side_warps()
  if self.x <= 0.5 then
    self.x = #map + 1.5
    self.dir = {-1, 0}
  elseif self.x >= #map + 1.5 then
    self.x = 0.5
    self.dir = {1, 0}
  end
end

function Character:check_if_done_exiting_hotel()
  if self.shape ~= 'ghost' then return end
  local can_pass_hotel_door = (self.mode == 'freemove' or self:is_dead())
  if can_pass_hotel_door and self:dist_to_pt(self:target()) < 0.1 then
    if self:is_dead() then
      self.dir = {0, -1}
      self.dead_till = clock
      self.mode = 'freemove'
      self.eaten = true
    else
      self.mode = 'normal'
    end
  end
end

function Character:register_dots_eaten()
  if self.shape ~= 'hero' then return end
  local dots_hit = dots_hit_by_man_at_xy(self.x, self.y)
  for k, v in pairs(dots_hit) do
    if dots[k] then
      if superdots[k] then superdot_eaten() end
      dots[k] = nil
      num_dots = num_dots - 1
      add_to_score(10)
      play_wata_till = clock + 0.2
      wata:play()
      if num_dots <= dots_at_end then
        pause_till = math.huge
        level_won()
      end
    end
  end
end

function Character:draw_death_anim()
  local t = death_anim_time - (death_anim_till - clock)
  local start, stop = 1.0, 2 * math.pi
  local erase_time = 0.5
  -- From time_left, map 3 -> start, 1 -> stop.
  local angle = (t / erase_time) * (stop - start) + start
  if angle > stop then
    if (death_anim_time - t) < 1.1 then
      love.graphics.setLineWidth(1)
      draw.setColor(255, 255, 255)
      local n = 7
      local r1, r2 = 0.15 * tile_size, 0.3 * tile_size
      for a = 0, 2 * math.pi, 2 * math.pi / n do
        local c, s = math.cos(a), math.sin(a)
        local x, y = self.x * tile_size, self.y * tile_size
        love.graphics.line(c * r1 + x, s * r1 + y,
                           c * r2 + x, s * r2 + y)
      end
    end
    return
  end
  draw.setColor(255, 255, 0)
  local offset = math.atan2(-1, 0)
  local r = 0.45
  love.graphics.arc('fill', self.x * tile_size, self.y * tile_size,
                    tile_size * r,
                    offset + angle / 2,
                    offset + 2 * math.pi - angle / 2, 16)
end

function Character:draw()
  local draw_opts = {is_live = not self.is_fake}
  if not self.always_draw then
    if self.shape == 'hero' and death_anim_till > clock then
      self:draw_death_anim()
      return
    end
    if pause_till > clock then return end
  end
  local colors = {red = {255, 0, 0}, pink = {255, 128, 128},
                  blue = {0, 224, 255}, orange = {255, 128, 0},
                  yellow = {255, 255, 0}}
  local color = colors[self.color]
  draw.setColor(color[1], color[2], color[3], 255, draw_opts)
  if self.shape == 'hero' then
    local p = 0.15  -- Period, in seconds, of chomps.
    local max = 1.0  -- Max mouth angle, in radians.
    local r = 0.45  -- Fraction of tile_size to use as a radius.
    if self.always_draw then
      local mouth_angle = max
      local start = math.atan2(0, -1)
      love.graphics.arc('fill', self.x * tile_size, self.y * tile_size,
                        tile_size * r,
                        start + mouth_angle / 2,
                        start + 2 * math.pi - mouth_angle / 2, 16)
    else
      local mouth_angle = max * (math.sin((clock % p) / p * 2 * math.pi) + 1.0)
      local start = math.atan2(self.dir[2], self.dir[1])
      love.graphics.arc('fill', self.x * tile_size, self.y * tile_size,
                        tile_size * r,
                        start + mouth_angle / 2,
                        start + 2 * math.pi - mouth_angle / 2, 16)
    end
  else  -- It's a ghost.
    local is_inverted_weak = false
    if self:is_weak() then
      draw.setColor(0, 0, 255, 255, draw_opts)
      local time_left = super_mode_till - clock
      is_inverted_weak = time_left < 2 and
          (math.floor(time_left * 3) % 2 == 0)
      if is_inverted_weak then
        draw.setColor(255, 255, 255, 255, draw_opts)
      end
    end
    if not self:is_dead() then
      -- Draw the ghost body.
      local r = 0.45
      love.graphics.circle('fill', self.x * tile_size,
                           self.y * tile_size, tile_size * r, 14)

      local vertices = {self.x * tile_size, self.y * tile_size,
                        (self.x - r) * tile_size, self.y * tile_size}
      local n = 7
      local left = (self.x - r) * tile_size
      local bottom = (self.y + 0.45) * tile_size
      for i = 0, n - 1 do
        local dy = 2 * (1 - (i % 2) * 2)
        table.insert(vertices, left + (i / (n - 1)) * tile_size * (2 * r))
        table.insert(vertices, bottom + dy)
      end
      table.insert(vertices, (self.x + r) * tile_size)
      table.insert(vertices, self.y * tile_size)
      love.graphics.polygon('fill', vertices)
    end
    -- Draw the eyes.
    draw.setColor(255, 255, 255, 255, draw_opts)
    if is_inverted_weak then draw.setColor(0, 0, 255, 255, draw_opts) end
    for i = -1, 1, 2 do
      local dx = i * 5
      local radius = 4
      if self:is_weak() then radius = 2 end
      love.graphics.circle('fill', self.x * tile_size + dx,
                           (self.y - 0.1) * tile_size, radius, 10)
    end
    if self:is_dead() or not self:is_weak() then
      -- Draw the pupils.
      draw.setColor(0, 0, 192, 255, draw_opts)
      for i = -1, 1, 2 do
        local dx = i * 5
        love.graphics.circle('fill', self.x * tile_size + dx + 1.5 * self.dir[1],
                             (self.y - 0.1) * tile_size + self.dir[2], 2.5, 10)
      end
    elseif self:is_weak() then
      -- We're in super mode; draw a wavy mouth.
      love.graphics.setLineWidth(1)
      local base = {self.x * tile_size - 7.5, self.y * tile_size + 5}
      local last_pt = nil
      for i = 0, 6 do
        local dy = (i % 2) * 2 - 1
        local pt = {base[1] + i * 2.5, base[2] - dy}
        if last_pt then
          love.graphics.line(last_pt[1], last_pt[2], pt[1], pt[2])
        end
        last_pt = pt
      end
    end
  end
end

function Character:dist_to_pt(pt)
  local dist_v = {self.x - pt[1], self.y - pt[2]}
  -- Using L1 makes it easier to survive close-pursuit turns.
  return math.abs(dist_v[1]) + math.abs(dist_v[2])
end

function Character:dist(other)
  if other:is_dead() then return math.huge end
  return self:dist_to_pt({other.x, other.y})
end

return Character
