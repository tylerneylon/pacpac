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
function M.play_song(song, between_notes) end


-------------------------------------------------------------------------------
-- Singleton wrapper.
-------------------------------------------------------------------------------

local selfname = debug.getinfo(1).source
if not global_singleton then global_singleton = {} end
if global_singleton[selfname] then return global_singleton[selfname] end
global_singleton[selfname] = M


-------------------------------------------------------------------------------
-- Private parts.
-------------------------------------------------------------------------------

local events = require('events')

-- Load in the notes audio.
local note_names = {'c1', 'g1', 'c2', 'g2', 'c3', 'd3', 'e3', 'c4'}
local notes = {}
for k, v in pairs(note_names) do
  notes[v] = love.audio.newSource('audio/notes/' .. v .. '.ogg', 'static')
  notes[v]:setVolume(0.5)
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

-------------------------------------------------------------------------------
-- Public function definitions.
-------------------------------------------------------------------------------

function M.play_song(song, between_notes)
  if #song == 0 then return end
  if not between_notes then between_notes = 0.3 end
  play_note(song[1])
  table.remove(song, 1)

  function play_rest()
    M.play_song(song, between_notes)
  end

  events.add(between_notes, play_rest)
end

return M

