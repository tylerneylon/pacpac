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

tile_size = 20

man_x = 10.5
man_y = 17.5
man_dir = {-1, 0}
pending_dir = nil
speed = 4

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

-- Turns {a, b} into {[str(a)] = true, [str(b)] = true}.
-- This is useful for testing if hash[key] for inclusion.
function hash_from_list(list)
  local hash = {}
  for k, v in pairs(list) do hash[str(v)] = true end
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
  function add_one_dot(x, y) dots[str({x, y})] = {x, y} end

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

function draw_man()
  love.graphics.setColor(255, 255, 0)
  love.graphics.circle('fill', man_x * tile_size, man_y * tile_size, tile_size / 2, 10)
end

function love.draw()
  for x = 1, #map do for y = 1, #(map[1]) do
    if map[x][y] == 1 then
      draw_wall(x, y)
    end
  end end  -- Loop over x, y.

  -- Draw dots.
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end

  draw_man()
end

function pts_hit_by_man_at_xy(x, y)
  local h = 0.45  -- Less than 0.5 to allow turns near intersections.
  local pts = {}
  for dx = -1, 1, 2 do for dy = -1, 1, 2 do
    table.insert(pts, {math.floor(x + dx * h), math.floor(y + dy * h)})
  end end
  return pts
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

function can_go_in_dir(dir)
  local new_x, new_y = man_x + dir[1], man_y + dir[2]
  return not xy_hits_a_wall(new_x, new_y)
end

function snap_into_place()
  if man_dir[1] == 0 then
    man_x = math.floor(2 * man_x + 0.5) / 2
  end
  if man_dir[2] == 0 then
    man_y = math.floor(2 * man_y + 0.5) / 2
  end
end

function love.update(dt)
  --print('At update start, man_xy=(' .. man_x .. ', ' .. man_y .. ')')
  man_x = man_x + man_dir[1] * dt * speed
  man_y = man_y + man_dir[2] * dt * speed
  snap_into_place()
  --print('After xy update, man_xy=(' .. man_x .. ', ' .. man_y .. ')')

  if xy_hits_a_wall(man_x, man_y) then
    man_dir = {0, 0}
    snap_into_place()
  end

  -- This outer guard protects against turns in the side warps.
  if man_x > 1 and man_x < (#map + 1) then
    if pending_dir and can_go_in_dir(pending_dir) then
      man_dir = pending_dir
      pending_dir = nil
    end
  end

  if man_x <= 0.5 then
    man_x = #map + 1.5
    man_dir = {-1, 0}
  elseif man_x >= #map + 1.5 then
    man_x = 0.5
    man_dir = {1, 0}
  end
end

function love.keypressed(key)
  local dirs = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
  local dir = dirs[key]
  if dir == nil then return end
  if can_go_in_dir(dir) then
    man_dir = dir
  else
    pending_dir = dir
  end
end

