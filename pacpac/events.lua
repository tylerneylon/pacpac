-- events.lua
--
-- Meant to be used as:
--   local events = require('events')
--   events.add(1.0, my_fn)
--
-- It's important to call events.update from love.update:
--   function love.update(dt)
--     events.update(dt)
--     -- other update code
--   end
--

local M = {}


-------------------------------------------------------------------------------
-- Public interface. Definitions are below.
-------------------------------------------------------------------------------

-- Register a callback to be called after a delay.
-- The name is optional, and allows for easier cancellation.
-- Returns an event_id, which is the name if provided.
function M.add(delay, callback, name) end

function M.cancel(event_id) end

-- This must be called often for everything to work; it's designed to be called
-- from love.update.
function M.update(dt) end


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

local clock = 0
local next_number_id = 1
local event_ids_by_time = {}  -- An array with values = an event_id.
local events_by_id = {}  -- A dict with key = event_id, value = event table.

local function insert(event_id)
  local event = events_by_id[event_id]
  local i = 1
  while i <= #events_by_id and events_by_id[i].time < event.time do
    i = i + 1
  end
  table.insert(events_by_id, i, event_id)
end

local function remove(event_id)
  for i = 1, #events_by_id do
    if events_by_id[i] == event_id then
      table.remove(events_by_id, i)
      return
    end
  end
end

-------------------------------------------------------------------------------
-- Public function definitions.
-------------------------------------------------------------------------------

function M.add(delay, callback, name)
  local event_id = name
  if not event_id then
    event_id = next_number_id
    next_number_id = next_number_id + 1
  end
  local event = {time = clock + delay, callback = callback}
  events_by_id[event_id] = event
  insert(event_id)  -- Inserts into event_ids_by_time.
end

function M.cancel(event_id)
  remove(event_id)  -- Removes from event_ids_by_time.
  events_by_id[event_id] = nil
end

function M.update(dt)
  clock = clock + dt
  local e = event_ids_by_time
  while #e > 0 and events_by_id[e[1]].time < clock do
    events_by_id[e[1]].callback()
    M.cancel(e[1])
  end
end

return M

