--[[ main.lua

     Main code for PacPac, a lua-based pac-man clone.
     There are many pac-man clones. This one is mine.
  ]]

local Character = require('Character')
local events = require('events')
local notes = require('notes')

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
       {1, 1, 1, 1, 0, 1, 1, 1, 0, 3, 2, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1}}

-- This can be 'start screen' or 'playing'.
game_mode = nil

superdots = {} -- Value given below.
num_dots = 0

tile_size = 22

man_x = 10.5
man_y = 17.5
man_dir = {-1, 0}
pending_dir = nil
clock = 0

message = ''
show_message_till = -1
pause_till = -1
game_over = false
super_mode_till = -1

man = nil  -- A Character object for the hero.
red = nil
characters = {}  -- All moving Character objects = man + ghosts.

ghost_mode = 'scatter'

lives_left = 3
life_start_time = 0
next_music_speedup = -1
score = 0

jstick = nil
jstick_img = nil
jstick_overlay = nil
keybd_img = nil

logo = nil
large_font = nil
small_font = nil

-- Sound-related variables.

wata = nil
play_wata_till = -1
weeoo = nil
bwop = nil
death_noise = nil
nomnomz = {}
nomnomz_index = 1
runny = nil
open_noise = nil

start_song_id = nil

-------------------------------------------------------------------------------
-- Define the PacSource class.
-- This is a weird class because we have to wrap instead of subclass, as the
-- object that acts like our base class is userdata instead of a table.
-------------------------------------------------------------------------------

PacSource = {} ; PacSource.__index = PacSource

function PacSource.new(filename)
  local pac_src = {}
  pac_src.src = love.audio.newSource(filename, 'static')
  pac_src.filename = filename
  return setmetatable(pac_src, PacSource)
end

-- This is a workaround for an infrequent but annoying audio bug where clips
-- simply stop playing and need to be recreated as new objects.
function PacSource:play()
  if self.src:isPaused() or self.src:isStopped() then
    self.src:play()
  end
  if self.src:isPaused() then
    -- Here is the workaround. Theoretically, this block should never happen.
    -- But it does.
    local is_looping = self.src:isLooping()
    self.src = love.audio.newSource(self.filename, 'static')
    self.src:setLooping(is_looping)
    self.src:play()
  end
end

function PacSource:pause()
  if not self.src:isPaused() and not self.src:isStopped() then
    self.src:pause()
  end
end

function PacSource:setLooping(should_loop) self.src:setLooping(should_loop) end
function PacSource:isPaused() return self.src:isPaused() end
function PacSource:setVolume(volume) self.src:setVolume(volume) end
function PacSource:stop() self.src:stop() end


-------------------------------------------------------------------------------
-- Non-love functions.
-------------------------------------------------------------------------------

function superdot_eaten()
  for k, c in pairs(characters) do
    if c.shape == 'ghost' then c.eaten = false end
  end
  super_mode_till = clock + 6.0
  score = score + 40  -- An additional +10 is given for every dot.
end

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

-- The input x, y is the center of the dot in tile-based coordinates.
function draw_one_dot(x, y, is_superdot)
  local dot_size = 1
  is_superdot = is_superdot or superdots[str({x, y})]
  if is_superdot then dot_size = 4 end
  local flash_rate = 0.2  -- In seconds.
  -- Don't draw superdots every other cycle.
  if is_superdot and math.floor(clock / flash_rate) % 2 == 1 and
     pause_till <= clock then
    return
  end
  love.graphics.setColor(255, 220, 128)
  love.graphics.circle('fill',
                       x * tile_size,
                       y * tile_size,
                       dot_size, 10)
end

function draw_dots()
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end
end

function draw_wall(x, y)

  -- A shortcut for map[pt[1]][pt[2]].
  function m(pt)
    if math.min(pt[1], pt[2]) < 1 then return 0 end
    if pt[1] > #map or pt[2] > #(map[1]) then return 0 end
    return map[pt[1]][pt[2]]
  end

  -- Avoid accidental line transparency.
  function line(x1, y1, x2, y2)
    love.graphics.line(math.floor(x1 + 0.5) + 0.5, math.floor(y1 + 0.5) + 0.5,
                       math.floor(x2 + 0.5) + 0.5, math.floor(y2 + 0.5) + 0.5)
  end

  local w = 0.7  -- A parameter for how to draw the walls. 0.7 looks good.
  local ww = 1.0 - w
  local map_pt = {x, y}

  if m(map_pt) == 3 then
    love.graphics.setColor(255, 200, 200)
    local z = w - 0.5
    local h = w * 0.2
    love.graphics.rectangle('fill',
                            (x - z) * tile_size + 1,
                            (y + (1 - h) / 2) * tile_size,
                            (1 + 2 * z) * tile_size,
                            tile_size * h)
    return
  end

  love.graphics.setColor(0, 0, 255)
  for coord = 1, 2 do for delta = -1, 1, 2 do
    local other_pt = {map_pt[1], map_pt[2]}
    other_pt[coord] = other_pt[coord] + delta
    local other = m(other_pt)
    if other ~= 1 then
      -- We choose w + ww = 1.0 for a weighted average.
      local c = {(w * map_pt[1] + ww * other_pt[1] + 0.5) * tile_size,
                 (w * map_pt[2] + ww * other_pt[2] + 0.5) * tile_size}

      -- Find the differences from c to draw; longer if wall continues.
      local d = {{0, 0}, {0, 0}}
      for dd = -1, 1, 2 do
        local i = (dd + 3) / 2  -- This is 1, 2 as dd is -1, 1.
        local side = {map_pt[1], map_pt[2]}
        local normal = 3 - coord
        side[normal] = side[normal] + dd
        d[i][normal] = dd * ww * tile_size
        if m(side) == 1 then d[i][normal] = dd * w * tile_size end
      end

      line(c[1] + d[1][1], c[2] + d[1][2],
           c[1] + d[2][1], c[2] + d[2][2])
    end
  end end  -- Loop over coord, delta.
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

function xy_hits_a_wall(x, y, can_pass_hotel_door)
  local pts = pts_hit_by_man_at_xy(x, y)
  for k, v in pairs(pts) do
    if v[1] >= 1 and v[1] <= #map then
      local m = map[v[1]][v[2]] 
      if m == 1 then return true end
      if m == 3 and not can_pass_hotel_door then return true end
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

function play_start_screen_music()
  local ending = 1
  local betw_time = 0.12
  local offset = 0  -- Alternates between 0 and 1.

  function note_played(note)
    if note == 0 then return end

    -- Set up dir to either left or right based on offset.
    local dir = {offset * 2 - 1, 0}
    if note == 'c1' then
      dir = {0, 1}
    elseif note == 'c3' then
      dir = {0, -1}
    end
    character_dance(dir)

    offset = 1 - offset
  end

  function play()
    local last_note = 'c1'
    if ending == 2 then last_note = 'c3' end
    local s = {'c2', 0, 'c2', 0, 'g2', 0, 'g2', 0, 'c2', 0, 'c2', 'c2',
               'g2', 0, 'g2', 0, 'c2', 0, 'g1', 0, 'c2', 0, 0, 'g1',
               'c2', 0, 0, 0, last_note, 0, 0, 0}
    if game_mode == 'start screen' then
      start_song_id = notes.play_song(s, betw_time, play, note_played)
    end
    ending = 3 - ending
  end

  play()
end

function stop_start_screen_music()
  notes.stop_song(start_song_id)
end

function play_game_over_music()
  notes.play_song({'g2', 'g2', 'e2-', 'e2-', 'c2', 'c2', 'c2'}, 0.1)
end

function play_level_won_music()
  local song = {'c1', 'g1', 'c2', 'g2', 'c3', 0, 'g2', 0, {'c3', 'c4'}}
  notes.play_song(song, 0.15)
end

function show_victory()
  message = 'You Win! w00t'
  show_message_till = math.huge
  set_music('none')
  play_level_won_music()
  characters = {}
  game_over = true
end

-- There's a function for this since we might want to play up to 4 overlapping
-- instances at once.
function play_nomnom()
  local n = nomnomz[nomnomz_index]
  n:play()
  nomnomz_index  = (nomnomz_index % 4) + 1
end

function check_for_hit()
  for k, character in pairs(characters) do
    if character ~= man and man:dist(character) < 0.5 then
      if character:is_weak() then
        play_nomnom()
        character.dead_till = math.huge
        character.eaten = true
      else
        death_noise:play()
        lives_left = lives_left - 1
        message = 'oops'
        show_message_till = clock + 3.0
        pause_till = clock + 3.0
        life_start_time = pause_till
        set_weeoo(1)

        if lives_left == 0 then
          message = 'Game Over'
          show_message_till = math.huge
          pause_till = math.huge
          game_over = true
          events.add(1, play_game_over_music)
        end

        -- Move the ghosts and the hero back home.
        for k, character in pairs(characters) do character:reset() end
      end
    end
  end
end

function draw_message()
  if show_message_till < clock then return end 
  love.graphics.setColor(255, 255, 255)
  love.graphics.print(message, 8 * tile_size, 23.5 * tile_size)
end

function draw_score()
  love.graphics.setColor(255, 255, 255)
  love.graphics.print('Score: ' .. score, 16 * tile_size, 23.5 * tile_size)
end

-- Input is similar to {0, 1}, which would be a request to go right.
function dir_request(dir)
  if dir == nil then return end
  if man == nil then return end
  if man:can_go_in_dir(dir) then
    man.dir = dir
  else
    man.next_dir = dir
  end
end

function sign(x)
  if x == 0 then return 0 end
  if x < 0 then return -1 end
  return 1
end

function check_jstick_if_present()
  if not jstick then return end
  x, y = love.joystick.getAxes(1)
  -- Discard low-volume movements.
  if math.max(math.abs(x), math.abs(y)) < 0.5 then return end
  -- Discretize the direction.
  if math.abs(x) < math.abs(y) then
    x = 0
  else
    y = 0
  end
  x, y = sign(x), sign(y)
  dir_request({x, y})
end

-- Expects music to be one of 'none', 'weeoo', 'bwop', or 'runny'.
function set_music(music)
  local clips = {weeoo = weeoo, bwop = bwop, runny = runny}
  for clip_name, clip in pairs(clips) do
    if clip then
      if music == clip_name then clip:play() else clip:pause() end
    end
  end
end

function update_audio()
  if play_wata_till <= clock then
    if not wata:isPaused() then
      wata:pause()
    end
  end

  if game_over or pause_till > clock then
    set_music('none')
    return
  end

  if super_mode_till > clock then
    for k, character in pairs(characters) do
      if character:is_dead() then
        set_music('runny')
        return
      end
    end
    set_music('bwop')
    return
  end

  set_music('weeoo')
  -- Speed up the weeoo over time.
  local music_speedup_cycle = 15  -- In seconds.
  local first_speedup = life_start_time + music_speedup_cycle
  next_music_speedup = math.max(next_music_speedup, first_speedup)
  if clock > next_music_speedup then
    local i = math.floor((clock - life_start_time) / music_speedup_cycle) + 1
    set_weeoo(i)
    next_music_speedup = next_music_speedup + music_speedup_cycle
  end
end

-- Input speed is an integer >= 1. If speed > 6, we still play speed 6.
function set_weeoo(speed)
  if weeoo then weeoo:stop() end
  speed = math.min(speed, 6)
  local filename = 'audio/weeoo' .. speed .. '.ogg'
  weeoo = PacSource.new(filename)
  weeoo:setLooping(true)
  weeoo:setVolume(0.6)
  weeoo:play()
end

function start_new_game()

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

  characters = {}
  events.add(2.55, begin_play)
  pause_till = math.huge
  local song = {{'c2', 'c3'}, 'c3', 'c3', 'c3', {'c2', 'e3'}, 0, 'c3',
                {'g1', 'd3'}, 0, 'c3', {'g1', 'd3'}, 'c3', {'c2', 'e3'},
                0, 'g2', 0, {'c1', 'c4'}}
  notes.play_song(song, 0.15)
end

function begin_play()
  characters = {}
  man = Character.new('hero', 'yellow')
  table.insert(characters, man)

  red = Character.new('ghost', 'red')
  table.insert(characters, red)

  table.insert(characters, Character.new('ghost', 'pink'))
  table.insert(characters, Character.new('ghost', 'blue'))
  table.insert(characters, Character.new('ghost', 'orange'))

  set_weeoo(1)
  pause_till = 0
end

function set_game_mode(new_mode)
  game_mode = new_mode
  if game_mode == 'start screen' then
    setup_start_screen_characters()
    love.draw = draw_start_screen
    love.update = update_start_screen
    love.keypressed = keypressed_start_screen
    love.joystickpressed = nil
  elseif game_mode == 'playing' then
    love.graphics.setFont(small_font)
    love.draw = draw_playing
    love.update = update_playing
    love.keypressed = keypressed_playing
    love.joystickpressed = joystickpressed_playing
  end
end

function character_dance(dir)
  local y = 20
  local tw = math.floor(love.graphics.getWidth() / tile_size)
  for k, c in pairs(characters) do
    local j = k
    if j == 1 or j == 3 then
      j = 4 - j  -- Map 1 -> 3, 3 -> 1 to put the hero in the middle.
    end
    local x = j * 2 + tw / 2 - 6
    c.x = x + 0.4 * dir[1]
    c.y = y + 0.4 * dir[2]
    c.dir = dir
  end
end

function setup_start_screen_characters()
  characters = {}
  local y = 25
  local colors = {'yellow', 'red', 'pink', 'blue', 'orange'}
  local tw = math.floor(love.graphics.getWidth() / tile_size)

  for k, color in pairs(colors) do
    local shape = 'ghost'
    local j = k
    if j == 1 or j == 3 then
      j = 4 - j  -- Map 1 -> 3, 3 -> 1 to put the hero in the middle.
    end
    local x = j * 2 + tw / 2 - 6
    if color == 'yellow' then shape = 'hero' end
    local c = Character.new(shape, color)
    c.x = x
    c.y = y
    table.insert(characters, c)
  end
  character_dance({0, 0})
end

function draw_start_text()
  local w = love.graphics.getWidth()
  local dy = -50
  love.graphics.setFont(large_font)
  love.graphics.setColor(255, 255, 255)
  love.graphics.printf('Start', 0, 400 + dy, w, 'center')

  if math.floor(clock / 0.3) % 2 == 0 then
    love.graphics.setColor(100, 100, 100)
  else
    love.graphics.setColor(0, 0, 0)
  end
  local vertices = {568, 409 + dy, 583, 417 + dy, 568, 425 + dy}
  love.graphics.polygon('fill', vertices)
end

function draw_controls()
  local w = love.graphics.getWidth()
  local x, y = 528, 500
  love.graphics.setColor(255, 255, 255)
  if jstick then
    love.graphics.draw(jstick_img, x, y)
    local alpha = 255 * (math.sin(clock * 5) + 1) / 2
    love.graphics.setColor(alpha, alpha, alpha)
    love.graphics.draw(jstick_overlay, x, y)
  else
    love.graphics.draw(keybd_img, (w - 200) / 2, y)
  end

  love.graphics.setFont(small_font)
  love.graphics.setColor(255, 255, 255)
  if jstick then
    love.graphics.print('Controls', 578, 631)
  else
    love.graphics.printf('Controls', 0, 631, w, 'center')
    love.graphics.setColor(80, 80, 80)
    love.graphics.printf('no gamepad detected', 0, 651, w, 'center')
  end
end


-------------------------------------------------------------------------------
-- Start screen key functions.
-------------------------------------------------------------------------------

function draw_start_screen()

  -- Draw the logo.
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local logo_w = logo:getWidth()
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(logo, math.floor((w - logo_w) / 2), 100)

  -- Draw the dot border.
  local tw, th = math.floor(w / tile_size) - 1, math.floor(h / tile_size) - 1
  superdots = {{.5, .5}, {.5, th + .5}, {tw + .5, .5}, {tw + .5, th + .5}}
  superdots = hash_from_list(superdots)
  for x = 0, tw do for y = 0, th, th do draw_one_dot(x + 0.5, y + 0.5) end end
  for x = 0, tw, tw do for y = 0, th do draw_one_dot(x + 0.5, y + 0.5) end end

  -- Draw the characters.
  for k, c in pairs(characters) do c:draw() end

  draw_start_text()
  draw_controls()
end

function update_start_screen(dt)
  clock = clock + dt
  events.update(dt)
end

function keypressed_start_screen(key)
  stop_start_screen_music()
  start_new_game()
  set_game_mode('playing')
end

-------------------------------------------------------------------------------
-- Playing key functions.
-------------------------------------------------------------------------------

function draw_playing()
  -- Draw walls.
  for x = 1, #map do for y = 1, #(map[1]) do
    if map[x][y] == 1 or map[x][y] == 3 then
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
  draw_score()
end

function update_playing(dt)
  clock = clock + dt

  events.update(dt)
  check_jstick_if_present()
  update_ghost_mode()
  update_audio()
  for k, character in pairs(characters) do
    character:update(dt)
  end
  check_for_hit()
end

function keypressed_playing(key)
  local dirs = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
  dir_request(dirs[key])
end

function joystickpressed_playing(joystick, button)
  -- These button numbers work for the PS3 controller.
  local dirs = {[5] = {0, -1}, [6] = {1, 0}, [7] = {0, 1}, [8] = {-1, 0}}
  dir_request(dirs[button])
end


-------------------------------------------------------------------------------
-- Love functions.
-------------------------------------------------------------------------------

function love.load()
  small_font = love.graphics.newFont('8bitoperator_jve.ttf', 16)
  large_font = love.graphics.newFont('8bitoperator_jve.ttf', 32)

  logo = love.graphics.newImage('img/pacpac_logo.png')
  jstick_img = love.graphics.newImage('img/gamepad.png')
  jstick_overlay = love.graphics.newImage('img/gamepad_overlay.png')
  keybd_img = love.graphics.newImage('img/arrow_keys.png')

  wata = PacSource.new('audio/watawata.ogg')
  wata:setLooping(true)
  bwop = PacSource.new('audio/bwop.ogg')
  bwop:setLooping(true)
  death_noise = PacSource.new('audio/death.ogg')
  death_noise:setVolume(0.3)
  for i = 1, 4 do
    local n = PacSource.new('audio/nomnom.ogg')
    n:setVolume(0.4)
    table.insert(nomnomz, n)
  end
  runny = PacSource.new('audio/runny.ogg')
  runny:setLooping(true)
  runny:setVolume(0.08)
  open_noise = PacSource.new('audio/open.ogg')
  open_noise:setVolume(0.5)
  open_noise:play()
  events.add(0.5, play_start_screen_music)

  jstick = (love.joystick.getNumJoysticks() > 0)
  if jstick then
    print('Detected ' .. love.joystick.getName(1))
  else
    print('No gamepad detected.')
  end

  set_game_mode('start screen')
end
