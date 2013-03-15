--[[ main.lua

     Main code for PacPac, a lua-based pac-man clone.
     There are many pac-man clones. This one is mine.
  ]]

-------------------------------------------------------------------------------
-- Declare all globals here.
-------------------------------------------------------------------------------

map = {{1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1},
       {1, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1}}

superdots = nil -- Value given below.
num_dots = 0

tile_size = 20

man_x = 10.5
man_y = 17.5
man_dir = {-1, 0}
pending_dir = nil
clock = 0

message = ""
show_message_till = -1
pause_till = -1
game_over = false
super_mode_till = -1

man = nil  -- A Character object for the hero.
red = nil
characters = {}  -- All moving Character objects = man + ghosts.

ghost_mode = 'scatter'

lives_left = 3

-------------------------------------------------------------------------------
-- Define the Character class.
-------------------------------------------------------------------------------

Character = {} ; Character.__index = Character

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
        if superdots[k] then
          super_mode_till = clock + 6.0
        end
        dots[k] = nil
        num_dots = num_dots - 1
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

man = Character.new('hero', 'yellow')
table.insert(characters, man)

red = Character.new('ghost', 'red')
table.insert(characters, red)

table.insert(characters, Character.new('ghost', 'pink'))
table.insert(characters, Character.new('ghost', 'blue'))
table.insert(characters, Character.new('ghost', 'orange'))

-------------------------------------------------------------------------------
-- Non-love functions.
-------------------------------------------------------------------------------

-- Sets ghost_mode to either 'scatter' or 'pursue', based on a 26-second cycle,
-- where the first 6 seconds are scatter, and the next 20 are pursue.
function update_ghost_mode()
  local cycle_point = clock % 26
  if cycle_point < 6 then
    ghost_mode = 'scatter'
  else
    ghost_mode = 'pursue'
  end
end

function str(t)
  if type(t) == 'table' then
    local s = '{'
    for i, v in ipairs(t) do
      if #s > 1 then s = s .. ', ' end
      s = s .. str(v)
    end
    s = s .. '}'
    return s
  elseif type(t) == 'number' then
    return tostring(t)
  elseif type(t) == 'boolean' then
    return tostring(t)
  end
  return 'unknown type'
end

-- Turns {a, b} into {[str(a)] = a, [str(b)] = b}.
-- This is useful for testing if hash[key] for inclusion.
function hash_from_list(list)
  local hash = {}
  for k, v in pairs(list) do hash[str(v)] = v end
  return hash
end

function love.load()
  superdots = hash_from_list({{2.5, 4}, {18.5, 4}, {2.5, 17.5}, {18.5, 17.5}})

  -- This will be a hash set of all dot locations.
  dots = {}
 
  -- Inner functions to help find the dot locations.
  -- The input x, y is the integer square location in tile coordinates.
  function add_dots(x, y)
    if map[x][y] ~= 0 then return end
    add_one_dot(x + 0.5, y + 0.5)
    if x + 1 <= #map and map[x + 1][y] == 0 then
      add_one_dot(x + 1, y + 0.5)
    end
    if y + 1 <= #(map[1]) and map[x][y + 1] == 0 then
      add_one_dot(x + 0.5, y + 1)
    end
  end
  function add_one_dot(x, y)
    dots[str({x, y})] = {x, y}
    num_dots = num_dots + 1
  end

  for x = 1, #map do for y = 1, #(map[1]) do add_dots(x, y) end end
end

-- The input x, y is the center of the dot in tile-based coordinates.
function draw_one_dot(x, y)
  local dot_size = 1
  if superdots[str({x, y})] then dot_size = 4 end
  love.graphics.setColor(255, 255, 255)
  love.graphics.circle('fill',
                       x * tile_size,
                       y * tile_size,
                       dot_size, 10)
end

function draw_dots()
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end
end

function draw_wall(x, y)
  -- print('draw_wall(' .. x .. ', ' .. y .. ')')
  love.graphics.setColor(255, 255, 255)
  love.graphics.rectangle('fill', x * tile_size, y * tile_size,
                          tile_size, tile_size)
end

function pts_hit_by_man_at_xy(x, y)
  local h = 0.45  -- Less than 0.5 to allow turns near intersections.
  local pts = {}
  for dx = -1, 1, 2 do for dy = -1, 1, 2 do
    table.insert(pts, {math.floor(x + dx * h), math.floor(y + dy * h)})
  end end
  return pts
end

-- Returns a hash set of the dot pts nearby, whether or not a dot is there.
function dots_hit_by_man_at_xy(x, y)
  local pts = pts_hit_by_man_at_xy(2 * x + 0.5, 2 * y + 0.5)
  local dots = {}
  for k, v in pairs(pts) do
    local pt = {v[1] / 2, v[2] / 2}
    dots[str(pt)] = pt
  end
  return dots
end

function xy_hits_a_wall(x, y)
  local pts = pts_hit_by_man_at_xy(x, y)
  for k, v in pairs(pts) do
    if v[1] >= 1 and v[1] <= #map then
      if map[v[1]][v[2]] == 1 then return true end
    end
  end
  return false
end

function draw_lives_left()
  local char = Character.new('hero', 'yellow')
  char.y = 24
  char.always_draw = true
  for i = 1, lives_left - 1 do
    char.x = 0.5 + 1.2 * i
    char:draw()
  end
end

function check_for_hit()
  for k, character in pairs(characters) do
    if character ~= man and man:dist(character) < 0.5 then
      if super_mode_till > clock then
        character.dead_till = clock + 6.0
      else
        lives_left = lives_left - 1
        message = "oops"
        show_message_till = clock + 3.0
        pause_till = clock + 3.0

        if lives_left == 0 then
          message = "Game Over"
          show_message_till = math.huge
          pause_till = math.huge
          game_over = true
        end

        -- Move the ghosts and the hero back home.
        for k, character in pairs(characters) do character:go_home() end
      end
    end
  end
end

function draw_message()
  if show_message_till < clock then return end 
  love.graphics.setColor(255, 255, 255)
  love.graphics.print(message, 8 * tile_size, 23.5 * tile_size)
end

-------------------------------------------------------------------------------
-- Love functions.
-------------------------------------------------------------------------------

function love.draw()
  for x = 1, #map do for y = 1, #(map[1]) do
    if map[x][y] == 1 then
      draw_wall(x, y)
    end
  end end  -- Loop over x, y.

  -- Draw dots.
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end

  for k, character in pairs(characters) do
    character:draw()
  end

  draw_lives_left()
  draw_message()
end

function love.keypressed(key)
  local dirs = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
  local dir = dirs[key]
  if dir == nil then return end
  if man:can_go_in_dir(dir) then
    man.dir = dir
  else
    man.next_dir = dir
  end
end

function love.update(dt)
  clock = clock + dt
  update_ghost_mode()
  for k, character in pairs(characters) do
    character:update(dt)
  end
  check_for_hit()
end
