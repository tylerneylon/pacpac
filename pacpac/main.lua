--[[ main.lua

     Main code for PacPac, a lua-based pac-man clone.
     There are many pac-man clones. This one is mine.
  ]]

local Character = require('Character')
local draw = require('draw')
local events = require('events')
local levelreader = require('levelreader')
local notes = require('notes')
local util = require('util')

-------------------------------------------------------------------------------
-- Declare all globals here.
-------------------------------------------------------------------------------

version = "0.301"

map = nil
num_levels = 3

-- This can be 'start screen' or 'playing'.
game_mode = nil

superdots = {} -- Value given below.
num_dots = 0

tile_size = 28

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
death_anim_till = -1

man = nil  -- A Character object for the hero.
red = nil
characters = {}  -- All moving Character objects = man + ghosts.

ghost_mode = 'scatter'

lives_left = 0
life_start_time = 0
next_music_speedup = -1
score = 0
hi_score = 0
ghost_eaten_scores = {}
next_ghost_score = 200
death_anim_time = 2

jstick = nil
jstick_img = nil
jstick_overlay = nil
keybd_img = nil

logo = nil
large_font = nil
small_font = nil

say_ready_till = 0

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
thunder = {}
thunder_index = 1

start_song_id = nil

start_lives = 3
dots_at_end = 0
easy_mode = false
is_invincible = false

if easy_mode then
  start_lives = 10
  dots_at_end = 250
end

-- Potential debug settings.
--[[
dots_at_end = -1
is_invincible = true
]]

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
function PacSource:rewind() self.src:rewind() end


-------------------------------------------------------------------------------
-- Non-love functions.
-------------------------------------------------------------------------------

function superdot_eaten()
  for k, c in pairs(characters) do
    if c.shape == 'ghost' then c.eaten = false end
  end
  super_mode_till = clock + 6.0
  add_to_score(40)  -- An additional +10 is given for every dot.
  next_ghost_score = 200
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

-- The input x, y is the center of the dot in tile-based coordinates.
function draw_one_dot(x, y, is_superdot)
  local dot_size = 2
  is_superdot = is_superdot or superdots[util.str({x, y})]
  if is_superdot then dot_size = 6 end
  local flash_rate = 0.2  -- In seconds.
  -- Don't draw superdots every other cycle.
  if is_superdot and math.floor(clock / flash_rate) % 2 == 1 and
     pause_till <= clock then
    return
  end
  draw.setColor(255, 220, 128)
  love.graphics.circle('fill',
                       x * tile_size,
                       y * tile_size,
                       dot_size, 10)
end

function draw_dots()
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end
end

function draw_wall(x, y)
  love.graphics.setLineWidth(3)

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
    -- Draw the ghost hotel door.
    draw.setColor(255, 200, 200, 255, {is_wall = true})
    local z = w - 0.5
    local h = w * 0.2
    love.graphics.rectangle('fill',
                            (x - z) * tile_size + 1,
                            (y + (1 - h) / 2) * tile_size,
                            (1 + 2 * z) * tile_size,
                            tile_size * h)
    return
  end

  local wc = level.wall_color
  draw.setColor(wc.r, wc.g, wc.b, 255, {is_wall = true})
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

function lightning_strike()
  play_thunder()
  last_lightning = clock
end

function lightning_sequence()
  lightning_strike()
  events.add(0.2, lightning_strike)
  events.add(1.5, lightning_strike)
  events.add(math.random() * 10 + 6, lightning_sequence, 'lightning')
end

function stop_lightning()
  events.cancel('lightning')
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
    dots[util.str(pt)] = pt
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
  char.is_fake = true
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
  if start_song_id then
    notes.stop_song(start_song_id)
  end
end

function play_game_over_music()
  notes.play_song({'g2', 'g2', 'e2-', 'e2-', 'c2', 'c2', 'c2'}, 0.1)
end

function play_level_won_music()
  local song = {'c1', 'g1', 'c2', 'g2', 'c3', 0, 'g2', 0, {'c3', 'c4'}}
  notes.play_song(song, 0.15)
end

function level_won()
  message = 'Level Complete!'
  show_message_till = math.huge
  set_music('none')
  play_level_won_music()
  if level_num == num_levels then
    show_victory()
  else
    events.add(3, next_level)
  end
  characters = {}
end

function show_victory()
  message = 'You Win! w00t'
  game_ended()
end

-- There's a function for this since we might want to play up to 4 overlapping
-- instances at once.
function play_nomnom()
  local n = nomnomz[nomnomz_index]
  n:play()
  nomnomz_index  = (nomnomz_index % 4) + 1
end

function play_thunder()
  local t = thunder[thunder_index]
  t:play()
  thunder_index  = (thunder_index % 9) + 1
end

function check_for_hit()
  for k, character in pairs(characters) do
    if character ~= man and man:dist(character) < 0.5 then
      if character:is_weak() then
        play_nomnom()
        character.dead_till = math.huge
        character.eaten = true
        add_ghost_eaten_score(next_ghost_score, character.x, character.y)
        next_ghost_score = next_ghost_score * 2
      elseif not is_invincible then
        death_noise:play()
        lives_left = lives_left - 1
        message = 'oops'
        show_message_till = math.huge
        pause_till = math.huge

        characters = {man}
        
        death_anim_till = clock + death_anim_time
        life_start_time = pause_till
        set_weeoo(1)

        if lives_left == 0 then
          message = 'Game Over'
          events.add(1, play_game_over_music)
          game_ended()
        else
          events.add(death_anim_time, begin_play)
        end
      end
    end
  end
end

function game_ended()
  game_over = true
  save_hi_score()
  stop_lightning()

  function show_start_screen()
    pause_till = 0
    events.add(0.5, play_start_screen_music)
    set_game_mode('start screen')
  end

  events.add(3, show_start_screen)
end

function draw_message()
  if show_message_till < clock then return end 
  draw.setColor(255, 255, 255)
  love.graphics.setFont(large_font)
  local t = 14  -- Tweak the positioning.
  love.graphics.printf(message, t, 23.25 * tile_size,
                       21 * tile_size - t, 'center')
end

function draw_score()
  draw.setColor(255, 255, 255)
  love.graphics.setFont(large_font)
  love.graphics.printf(score, 0, 23.25 * tile_size, 20 * tile_size, 'right')

  if hi_score == score then
    draw.setColor(255, 255, 0)
  end
  local x, y = 9, -5
  love.graphics.print('High Score', tile_size + x, y)
  love.graphics.printf(hi_score, tile_size, y, 19 * tile_size, 'right')
end

function add_ghost_eaten_score(points, x, y)
  add_to_score(points)
  local s = {score = points,
             x = (x - 0.4) * tile_size,
             y = (y - 0.3) * tile_size}
  local event_id = nil

  -- Register the score to disappear in 2 seconds.
  function remove_ghost_eaten_score()
    ghost_eaten_scores[event_id] = nil
  end
  event_id = events.add(2, remove_ghost_eaten_score)

  ghost_eaten_scores[event_id] = s
end

function draw_ghost_eaten_scores()
  love.graphics.setFont(small_font)
  draw.setColor(0, 255, 255)
  for k, v in pairs(ghost_eaten_scores) do
    love.graphics.print(v.score, v.x, v.y)
  end
end

function add_to_score(points)
  score = score + points
  if score > hi_score then hi_score = score end
end

-- Input is similar to {0, 1}, which would be a request to go right.
function dir_request(dir)
  if dir == nil then return end
  if man == nil then return end
  if man:can_turn_right_now(dir) then
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

function next_level()
  level_num = level_num + 1
  setup_level()
end

-- Loads the level corresponding to level_num.
function setup_level()
  local filename = 'level' .. level_num .. '.txt'
  level = levelreader.read(filename)
  map = level.map

  show_message_till = 0
  num_dots = 0

  superdots = util.hash_from_list(level.superdots)

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
    dots[util.str({x, y})] = {x, y}
    num_dots = num_dots + 1
  end

  for x = 1, #map do for y = 1, #(map[1]) do add_dots(x, y) end end

  characters = {}
  local startup_time = 2.55
  events.add(1, show_character_preview)
  events.add(startup_time, begin_play)
  pause_till = math.huge
  local song = {{'c2', 'c3'}, 'c3', 'c3', 'c3', {'c2', 'e3'}, 0, 'c3',
                {'g1', 'd3'}, 0, 'c3', {'g1', 'd3'}, 'c3', {'c2', 'e3'},
                0, 'g2', 0, {'c1', 'c4'}}
  say_ready_till = clock + startup_time
  notes.play_song(song, 0.15)

  if level_num == 3 then
    events.add(5, lightning_sequence)
  end
end

function start_new_game()
  lives_left = start_lives
  game_over = false
  score = 0

  level_num = 1
  setup_level()
end

function setup_characters()
  characters = {}
  man = Character.new('hero', 'yellow')
  table.insert(characters, man)

  red = Character.new('ghost', 'red')
  table.insert(characters, red)

  table.insert(characters, Character.new('ghost', 'pink'))
  table.insert(characters, Character.new('ghost', 'blue'))
  table.insert(characters, Character.new('ghost', 'orange'))
end

-- This displays stationary characters in position before play starts.
function show_character_preview()
  setup_characters()
  for k, c in pairs(characters) do
    c.dir = {0, 0}
    c.always_draw = true
  end
end

function begin_play()
  setup_characters()
  set_weeoo(1)
  pause_till = 0
  show_message_till = 0
end

-- This is similar to love.graphics.rectangle, except that the rectangle has
-- rounded corners. r = radius of the corners, n ~ #points used in the polygon.
function rounded_rectangle(mode, x, y, w, h, r, n)
  n = n or 20  -- Number of points in the polygon.
  if n % 4 > 0 then n = n + 4 - (n % 4) end  -- Include multiples of 90 degrees.
  local pts, c, d, i = {}, {x + w / 2, y + h / 2}, {w / 2 - r, r - h / 2}, 0
  while i < n do
    local a = i * 2 * math.pi / n
    local p = {r * math.cos(a), r * math.sin(a)}
    for j = 1, 2 do
      table.insert(pts, c[j] + d[j] + p[j])
      if p[j] * d[j] <= 0 and (p[1] * d[2] < p[2] * d[1]) then
        d[j] = d[j] * -1
        i = i - 1
      end
    end
    i = i + 1
  end
  love.graphics.polygon(mode, pts)
end

function draw_ready_text()
  if say_ready_till <= clock then return end

  -- Draw the rounded rect background.
  local x, y, w, h = 206, 361, 176, 75
  draw.setColor(0, 0, 0, 200)
  rounded_rectangle('fill', x, y, w, h, 10, 30)
  draw.setColor(50, 50, 50)
  rounded_rectangle('line', x, y, w, h, 10, 30)

  -- Draw the text.
  love.graphics.setFont(large_font)
  draw.setColor(200, 200, 200)
  love.graphics.printf('Level ' .. level_num, x + 6, y + 2, w, 'center')
  draw.setColor(255, 200, 0)
  love.graphics.printf('Ready!', x + 6, y + 35, w, 'center')
end

function character_dance(dir)
  local y = 16
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
  draw.setColor(255, 255, 255)
  love.graphics.printf('Start', 0, 400 + dy, w, 'center')

  if math.floor(clock / 0.3) % 2 == 0 then
    draw.setColor(100, 100, 100)
  else
    draw.setColor(0, 0, 0)
  end
  local vertices = {568, 409 + dy, 583, 417 + dy, 568, 425 + dy}
  love.graphics.polygon('fill', vertices)
end

function draw_controls()
  local w = love.graphics.getWidth()
  local x, y = 528, 500
  draw.setColor(255, 255, 255)
  if jstick then
    love.graphics.draw(jstick_img, x, y)
    local alpha = 255 * (math.sin(clock * 5) + 1) / 2
    draw.setColor(alpha, alpha, alpha)
    love.graphics.draw(jstick_overlay, x, y)
  else
    love.graphics.draw(keybd_img, (w - 200) / 2, y)
  end

  love.graphics.setFont(small_font)
  draw.setColor(255, 255, 255)
  if jstick then
    love.graphics.print('Controls', 578, 631)
  else
    love.graphics.printf('Controls', 0, 631, w, 'center')
    draw.setColor(80, 80, 80)
    love.graphics.printf('no gamepad detected', 0, 651, w, 'center')
  end
end

function load_hi_score()
  if not love.filesystem.exists('hi_score') then
    hi_score = 1000
    return
  end
  local file = love.filesystem.newFile('hi_score')
  file:open('r')
  local score_str = file:read()
  hi_score = tonumber(score_str)
  file:close()
end

function save_hi_score()
  local file = love.filesystem.newFile('hi_score')
  file:open('w')
  file:write(tostring(hi_score))
  file:close()
end

function set_game_mode(new_mode)
  game_mode = new_mode
  if game_mode == 'start screen' then
    setup_start_screen_characters()
    love.draw = draw_start_screen
    love.update = update_start_screen
    love.keypressed = keypressed_start_screen
    love.joystickpressed = joystickpressed_start_screen
  elseif game_mode == 'playing' then
    love.graphics.setFont(small_font)
    love.draw = draw_playing
    love.update = update_playing
    love.keypressed = keypressed_playing
    love.joystickpressed = joystickpressed_playing
  end
end


-------------------------------------------------------------------------------
-- Start screen key functions.
-------------------------------------------------------------------------------

function draw_start_screen()

  -- Draw the logo.
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local logo_w = logo:getWidth()
  draw.setColor(255, 255, 255)
  love.graphics.draw(logo, math.floor((w - logo_w) / 2), 100)

  -- Draw the dot border.
  local tw, th = math.floor(w / tile_size) - 1, math.floor(h / tile_size) - 1
  superdots = {{.5, .5}, {.5, th + .5}, {tw + .5, .5}, {tw + .5, th + .5}}
  superdots = util.hash_from_list(superdots)
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

function joystickpressed_start_screen(joystick, button)
  keypressed_start_screen()  -- Start a game.
end

-------------------------------------------------------------------------------
-- Playing key functions.
-------------------------------------------------------------------------------

function draw_playing()
  love.graphics.translate(345, 15)

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
  draw_ready_text()
  draw_score()
  draw_ghost_eaten_scores()
end

function update_playing(dt)
  -- Uncomment this bit to see what kind of dt's we're getting.
  --[[
  local s = ''
  for i = 1, dt * 1000 do s = s .. '-' end
  print('dt=' .. dt .. s)
  ]]

  local max_dt = 0.06  -- Useful to avoid bugs that happen for large dt's.
  dt = math.min(dt, max_dt)
  clock = clock + dt

  check_jstick_if_present()
  update_ghost_mode()
  update_audio()
  for k, character in pairs(characters) do
    character:update(dt)
  end
  check_for_hit()
  events.update(dt)
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
  level = levelreader.read('level1.txt')
  load_hi_score()

  small_font = love.graphics.newFont('8bitoperator_jve.ttf', 16)
  large_font = love.graphics.newFont('8bitoperator_jve.ttf', 32)

  logo = love.graphics.newImage('img/pacpac_logo.png')
  jstick_img = love.graphics.newImage('img/gamepad.png')
  jstick_overlay = love.graphics.newImage('img/gamepad_overlay.png')
  keybd_img = love.graphics.newImage('img/arrow_keys.png')

  open_noise = PacSource.new('audio/open.ogg')
  open_noise:setVolume(0.5)
  open_noise:play()

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
  for i = 1, 9 do
    local t = PacSource.new('audio/thunder.ogg')
    table.insert(thunder, t)
  end

  events.add(0.5, play_start_screen_music)

  jstick = (love.joystick.getNumJoysticks() > 0)
  if jstick then
    print('Detected ' .. love.joystick.getName(1))
  else
    print('No gamepad detected.')
  end

  set_game_mode('start screen')
end
