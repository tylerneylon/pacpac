-- notes.lua
--
-- Used to play songs composed programmatically of notes.
-- The notes themselves are prerecorded as small audio files.
--

local M = {}


-------------------------------------------------------------------------------
-- Public interface. Definitions are below.
-------------------------------------------------------------------------------

-- Play a song, which is an array of notes. A note is either a string like
-- "c3" or an array of strings which will be played simulateneously.
-- between_notes is an optional parameter specifying time between note starts.
-- The default 0.3 seconds.
-- done_cb is an optional callback called at the end of a song.
-- note_db is an optional callback called as each note is played; it receives
-- the note begin played as a parameter.
-- The return value is a song_id that can be used to stop the song early.
function M.play_song(song, between_notes, done_cb, note_cb) end

function M.stop_song(song_id) end


-------------------------------------------------------------------------------
-- Private parts.
-------------------------------------------------------------------------------

local events = require('events')
local next_song_id = 1
local event_ids_per_song_id = {}

-- Load in the notes audio.
local note_names = {'c1', 'g1', 'c2', 'e2-', 'g2', 'c3', 'd3', 'e3', 'c4'}
local notes = {}
for k, v in pairs(note_names) do
  notes[v] = love.audio.newSource('audio/notes/' .. v .. '.ogg', 'static')
  notes[v]:setVolume(0.7)
end

local function play_note(note)
  if type(note) == 'string' then
    if notes[note] then
      notes[note]:play()
    else
      print('Error: No audio data for note named "' .. note .. '"')
    end
  elseif type(note) == 'number' then
    return  -- It's a rest.
  else
    -- It's an array of notes.
    for k, v in pairs(note) do play_note(v) end
  end
end

local function _play_song(song_id, song, between_notes, done_cb, note_cb)
  if #song == 0 then
    if done_cb then done_cb() end
    return
  end
  if note_cb then note_cb(song[1]) end
  if not between_notes then between_notes = 0.3 end

  play_note(song[1], note_cb)
  table.remove(song, 1)

  function play_rest()
    _play_song(song_id, song, between_notes, done_cb, note_cb)
  end

  local e_id = events.add(between_notes, play_rest)
  event_ids_per_song_id[song_id] = e_id
  return song_id
end

-- Useful for debugging.
local function traceback()
  local level = 1
  while true do
    local info = debug.getinfo(level, "Sl")
    if not info then break end
    if info.what == "C" then   -- is a C function?
      print(level, "C function")
    else   -- a Lua function
      print(string.format("[%s]:%d",
                          info.short_src, info.currentline))
    end
    level = level + 1
  end
end

-------------------------------------------------------------------------------
-- Public function definitions.
-------------------------------------------------------------------------------


function M.play_song(song, between_notes, done_cb, note_cb)
  local song_id = next_song_id
  next_song_id = next_song_id + 1
  _play_song(song_id, song, between_notes, done_cb, note_cb)
  return song_id
end

function M.stop_song(song_id)
  events.cancel(event_ids_per_song_id[song_id])
end


return M

