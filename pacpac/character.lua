-- Character.lua
--
-- A class to work with the hero and ghosts.
--
-- Use like this:
--     local Character = require('Character')
--

local Character = {} ; Character.__index = Character

-- shape is 'hero' or 'ghost'; color is in {'red', 'pink', 'blue', 'orange'}.
function Character.new(shape, color)
  local c = setmetatable({shape = shape, color = color}, Character)
  c.dead_till = -1
  c:go_home()
  return c
end

function Character:is_dead()
  return self.dead_till > clock
end

function Character:go_home()
  if self.shape == 'hero' then
    self.x = 10.5
    self.y = 17.5
    self.dir = {-1, 0}
    self.next_dir = nil
  else
    if self.color == 'red' then
      self.x = 10.5
      self.y = 9.5
      self.dir = {1, 0}
    elseif self.color == 'pink' then
      self.x = 18.5
      self.y = 2.5
      self.dir = {-1, 0}
    elseif self.color == 'blue' then
      self.x = 2.5
      self.y = 2.5
      self.dir = {0, 1}
    elseif self.color == 'orange' then
      self.x = 10.5
      self.y = 5.5
      self.dir = {-1, 0}
    end
  end
end

function Character:speed()
  if self.shape == 'hero' then return 4 end
  if self:is_dead() then return 8 end
  if super_mode_till > clock then
    return 3
  else
    return 4
  end
end

function Character:target()
  if self.shape == 'hero' then return {} end
  if self:is_dead() then return {10.5, 9.5} end
  if super_mode_till > clock then
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
  return not xy_hits_a_wall(new_x, new_y)
end

function Character:dot_prod(dir)
  local target = self:target()
  local target_dir = {target[1] - self.x, target[2] - self.y}
  return target_dir[1] * dir[1] + target_dir[2] * dir[2]
end

function Character:just_turned()
  return self.last_turn and clock - self.last_turn < 0.2
end

-- Input is the direction we were previously going in.
-- We want ghosts to not go directly backwards here.
function Character:did_stop(old_dir)
  if self.shape == 'hero' then return end
  local turn = {old_dir[2], old_dir[1]}
  local sorted_turns = {}  -- First dir here will be our first choice.
  local dot_prod = self:dot_prod(turn)
  local sign = 1
  if dot_prod < 0 then sign = -1 end
  local turns = {{turn[1] * sign, turn[2] * sign},
                 {turn[1] * sign * -1, turn[2] * sign * -1}}
  for k, t in pairs(turns) do
    if self:can_go_in_dir(t) then
      self.dir = t
      self.last_turn = clock
      return
    end
  end
end

function Character:available_turns()
  if self:just_turned() then return {} end
  local turn = {self.dir[2], self.dir[1]}
  local turns = {}
  for sign = -1, 1, 2 do
    local t = {turn[1] * sign, turn[2] * sign}
    if self:can_go_in_dir(t) then table.insert(turns, t) end
  end
  return turns
end

-- Switch self.dir to dir if it is more aligned with getting to the target.
function Character:turn_if_better(turn)
  if self:dot_prod(turn) > self:dot_prod(self.dir) then
    self.dir = turn
    self.last_turn = clock
  end
end

function Character:update(dt)
  if pause_till > clock then return end

  -- Blind movement.
  self.x = self.x + self.dir[1] * dt * self:speed()
  self.y = self.y + self.dir[2] * dt * self:speed()
  self:snap_into_place()

  -- Step back if we hit a wall.
  local did_hit_wall = xy_hits_a_wall(self.x, self.y)
  if did_hit_wall then
    local old_dir = self.dir
    self.dir = {0, 0}
    self:snap_into_place()
    self:did_stop(old_dir)
  end

  -- Check if we should turn.
  -- This outer guard protects against turns in the side warps.
  if self.x > 1 and self.x < (#map + 1) then
    if self.shape == 'hero' and self:can_go_in_dir(self.next_dir) then
      self.dir = self.next_dir
      self.next_dir = nil
    end
    if self.shape == 'ghost' and not did_hit_wall then
      local turns = self:available_turns()
      for k, t in pairs(turns) do self:turn_if_better(t) end
    end
  end

  -- Check for side warps.
  if self.x <= 0.5 then
    self.x = #map + 1.5
    self.dir = {-1, 0}
  elseif self.x >= #map + 1.5 then
    self.x = 0.5
    self.dir = {1, 0}
  end

  if self.shape == 'hero' then
    local dots_hit = dots_hit_by_man_at_xy(self.x, self.y)
    for k, v in pairs(dots_hit) do
      if dots[k] then
        if superdots[k] then superdot_eaten() end
        dots[k] = nil
        num_dots = num_dots - 1
        score = score + 10
        play_wata_till = clock + 0.2
        wata:play()
        if num_dots == 0 then
          game_over = true
          message = "You Win! w00t"
          show_message_till = math.huge
          paused_till = math.huge
        end
      end
    end
  end
end

function Character:draw()
  if game_over then return end
  if not self.always_draw and pause_till > clock then return end
  local colors = {red = {255, 0, 0}, pink = {255, 128, 128},
                  blue = {0, 224, 255}, orange = {255, 128, 0},
                  yellow = {255, 255, 0}}
  local color = colors[self.color]
  love.graphics.setColor(color[1], color[2], color[3])
  if self.shape == 'hero' then
    local p = 0.15
    local max = 1.0
    if self.always_draw then
      local mouth_angle = max
      local start = math.atan2(0, -1)
      love.graphics.arc('fill', self.x * tile_size, self.y * tile_size,
                        tile_size / 2,
                        start + mouth_angle / 2,
                        start + 2 * math.pi - mouth_angle / 2, 10)
    else
      local mouth_angle = max * (math.sin((clock % p) / p * 2 * math.pi) + 1.0)
      local start = math.atan2(self.dir[2], self.dir[1])
      love.graphics.arc('fill', self.x * tile_size, self.y * tile_size,
                        tile_size / 2,
                        start + mouth_angle / 2,
                        start + 2 * math.pi - mouth_angle / 2, 10)
    end
  else
    if super_mode_till > clock then
      love.graphics.setColor(0, 0, 255)
    end
    if not self:is_dead() then
      love.graphics.circle('fill', self.x * tile_size,
                           self.y * tile_size, tile_size / 2, 10)
      local vertices = {(self.x + 0.5) * tile_size, self.y * tile_size,
                        (self.x - 0.5) * tile_size, self.y * tile_size}
      local n = 5
      local left = (self.x - 0.5) * tile_size
      local bottom = (self.y + 0.4) * tile_size
      for i = 0, n - 1 do
        local dy = 2 * (1 - (i % 2) * 2)
        table.insert(vertices, left + (i / (n - 1)) * tile_size)
        table.insert(vertices, bottom + dy)
      end
      love.graphics.polygon('fill', vertices)
    end
    -- Draw the eyes.
    love.graphics.setColor(255, 255, 255)
    for i = -1, 1, 2 do
      local dx = i * 4
      love.graphics.circle('fill', self.x * tile_size + dx,
                           (self.y - 0.1) * tile_size, 3.0, 10)
    end
    if super_mode_till <= clock or self:is_dead() then
      -- Draw the iris/pupil part.
      love.graphics.setColor(0, 0, 192)
      for i = -1, 1, 2 do
        local dx = i * 4
        love.graphics.circle('fill', self.x * tile_size + dx + self.dir[1],
                             (self.y - 0.1) * tile_size + self.dir[2], 2.0, 10)
      end
    else
      -- We're in super mode.
      local base = {self.x * tile_size - 4.5, self.y * tile_size + 5}
      local last_pt = nil
      for i = 0, 6 do
        local dy = (i % 2) * 2 - 1
        local pt = {base[1] + i * 1.5, base[2] - dy}
        if last_pt then
          love.graphics.line(last_pt[1], last_pt[2], pt[1], pt[2])
        end
        last_pt = pt
      end
    end
  end
end

function Character:dist(other)
  if other:is_dead() then return math.huge end
  local dist_v = {other.x - self.x, other.y - self.y}
  return math.sqrt(dist_v[1] * dist_v[1] + dist_v[2] * dist_v[2])
end

return Character
