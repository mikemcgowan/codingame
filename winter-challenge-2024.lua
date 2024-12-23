local next_token = string.gmatch(io.read(), "%S+")
local W = tonumber(next_token())
local H = tonumber(next_token())

local OWNER_ME = 1
local OWNER_ENEMY = 0
local OWNER_NA = -1
local DIRS = { "N", "E", "S", "W" }

local WALL = "WALL"
local ROOT = "ROOT"
local BASIC = "BASIC"
local TENTACLE = "TENTACLE"
local HARVESTER = "HARVESTER"
local SPORER = "SPORER"

local heads = {}
local head
local next_head_pos = { x = -1, y = -1 }
local harvesters = {} -- list of points

local function debug(s)
  s = s and s or ""
  io.stderr:write(s .. "\n")
end

local grid = {
  deltas = function(self, a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx, dy
  end,

  distance_between = function(self, a, b)
    local dx, dy = self:deltas(a, b)
    return math.sqrt(dx * dx + dy * dy)
  end,

  dir_from_deltas = function(self, dx, dy)
    local dir
    if dx > 0 then
      dir = "E"
    elseif dx < 0 then
      dir = "W"
    elseif dy > 0 then
      dir = "S"
    elseif dy < 0 then
      dir = "N"
    end
    return dir
  end,

  move_point_in_dir = function(self, p, dir)
    local x, y = p.x, p.y
    if dir == "N" then
      y = y - 1
    elseif dir == "E" then
      x = x + 1
    elseif dir == "S" then
      y = y + 1
    elseif dir == "W" then
      x = x - 1
    end
    return x, y
  end,
}

local function is_protein(typ)
  return #typ == 1 -- A, B, C, D
end

local function proteins(all_things)
  local ps = {}
  for _, v in ipairs(all_things) do
    if is_protein(v.typ) then
      table.insert(ps, v)
    end
  end
  return ps
end

local function enemies(all_things)
  local es = {}
  for _, v in ipairs(all_things) do
    if v.owner == OWNER_ENEMY then
      table.insert(es, v)
    end
  end
  return es
end

local function can_grow_basic(my_protein_stack)
  return my_protein_stack.A > 0
end

local function can_grow_harvester(my_protein_stack)
  return my_protein_stack.C > 0 and my_protein_stack.D > 0
end

local function can_grow_tentacle(my_protein_stack)
  return my_protein_stack.B > 0 and my_protein_stack.C > 0
end

local function closest_thing(organ, things)
  local ts = things
  local distance
  local thing
  for _, t in ipairs(ts) do
    local d = grid:distance_between(t, organ)
    if not distance or d < distance then
      distance = d
      thing = t
    end
  end
  return distance, thing
end

local function closest_protein(organ, all_things)
  return closest_thing(organ, proteins(all_things))
end

local function closest_enemy(organ, all_things)
  return closest_thing(organ, enemies(all_things))
end

local function get_harvester_direction(all_things, next_head_x, next_head_y)
  for _, v in ipairs(all_things) do
    if is_protein(v.typ) then
      local dx, dy = grid:deltas(v, { x = next_head_x, y = next_head_y })
      if math.abs(dx) == 1 and math.abs(dy) == 0 or math.abs(dx) == 0 and math.abs(dy) == 1 then
        debug("head at " .. next_head_x .. "," .. next_head_y)
        debug("found protein at " .. next_head_x + dx .. "," .. next_head_y + dy)
        local dir = grid:dir_from_deltas(dx, dy)
        if dir then
          return dir
        end
      end
    end
  end
end

local function parse()
  local entityCount = tonumber(io.read())
  local all_things = {}

  for _ = 1, entityCount do
    next_token = string.gmatch(io.read(), "%S+")
    local x = tonumber(next_token())
    local y = tonumber(next_token())
    local typ = next_token() -- WALL, ROOT, BASIC, TENTACLE, HARVESTER, SPORER, A, B, C, D
    local owner = tonumber(next_token()) -- 1 if your organ, 0 if enemy organ, -1 if neither
    local organId = tonumber(next_token()) -- id of this entity if it's an organ, 0 otherwise
    local organDir = next_token() -- N,E,S,W or X if not an organ
    local organParentId = tonumber(next_token())
    local organRootId = tonumber(next_token())

    table.insert(all_things, {
      id = organId,
      x = x,
      y = y,
      typ = typ,
      owner = owner,
      organ_dir = organDir,
      organ_parent_id = organParentId,
      organ_root_id = organRootId,
    })
    local u = all_things[#all_things]

    if #heads == 0 and typ == ROOT then
      heads = { u }
    elseif x == next_head_pos.x and y == next_head_pos.y then
      if u.id ~= 0 and u.owner == OWNER_ME then
        heads[#heads + 1] = u
      end
    end
  end

  head = heads[#heads]
  debug("there are " .. #heads .. " head(s)")
  debug("set head to id " .. head.id)
  return all_things
end

local function protein_stacks()
  next_token = string.gmatch(io.read(), "%S+")
  local myA = tonumber(next_token())
  local myB = tonumber(next_token())
  local myC = tonumber(next_token())
  local myD = tonumber(next_token())
  next_token = string.gmatch(io.read(), "%S+")
  local enA = tonumber(next_token())
  local enB = tonumber(next_token())
  local enC = tonumber(next_token())
  local enD = tonumber(next_token())
  return { A = myA, B = myB, C = myC, D = myD }, { A = enA, B = enB, C = enC, D = enD }
end

local function is_being_harvested(protein)
  for _, h in ipairs(harvesters) do
    local x, y = grid:move_point_in_dir(h, h.dir)
    if protein.x == x and protein.y == y then
      return true
    end
  end
  return false
end

local function get_thing_at(all_things, x, y)
  for _, t in ipairs(all_things) do
    if t.x == x and t.y == y then
      return t
    end
  end
end

local function empty_cells_adjacent_to(all_things, x1, y1)
  local cells = {}
  for _, dir in ipairs(DIRS) do
    local x2, y2 = grid:move_point_in_dir({ x = x1, y = y1 }, dir)
    local t = get_thing_at(all_things, x2, y2)
    if not t then
      table.insert(cells, { x = x2, y = y2 })
    end
  end
  return cells
end

local function grow_from_head(x, y, typ, extra)
  local t = {
    "GROW",
    head.id,
    x,
    y,
    typ,
  }
  if extra then
    t[#t + 1] = extra
  end
  print(table.concat(t, " "))
  next_head_pos = { x = x, y = y }
  debug("grow_from_head(): " .. x .. "," .. y)
end

local function spread_adjacent(thing, all_things)
  for _, dir in ipairs(DIRS) do
    local x, y = grid:move_point_in_dir(thing, dir)
    if not get_thing_at(all_things, x, y) then
      debug("spread_adjacent(): there's nothing at " .. x .. "," .. y .. " so growing from there")
      grow_from_head(x, y, BASIC)
      return true
    end
  end
  return false
end

local function spread_anywhere(all_things)
  for _, o in ipairs(all_things) do
    if o.owner == OWNER_ME then
      local b = spread_adjacent(o, all_things)
      if b then
        return true
      end
    end
  end
  return false
end

local function get_next_head_pos(thing, all_things)
  local empty_cells = {}
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME then
      local cells = empty_cells_adjacent_to(all_things, t.x, t.y)
      for _, v in ipairs(cells) do
        table.insert(empty_cells, v)
      end
    end
  end
  if #empty_cells == 0 then
    return
  end
  table.sort(empty_cells, function(c1, c2)
    local d1 = grid:distance_between(c1, thing)
    local d2 = grid:distance_between(c2, thing)
    return d1 < d2
  end)
  return empty_cells[1].x, empty_cells[1].y
end

local function grow_towards_closest_protein(my_protein_stack, all_things)
  local d, p = closest_protein(head, all_things)
  if d and p and not is_being_harvested(p) then
    debug("distance to closest protein from head is " .. d)
    debug("closest protein is at " .. p.x .. "," .. p.y)
    local next_head_x, next_head_y = get_next_head_pos(p, all_things)
    if next_head_x ~= head.x or next_head_y ~= head.y then
      local harvester_d = get_harvester_direction(all_things, next_head_x, next_head_y)
      if harvester_d and can_grow_harvester(my_protein_stack) then
        grow_from_head(next_head_x, next_head_y, HARVESTER, harvester_d)
        table.insert(harvesters, { x = next_head_x, y = next_head_y, dir = harvester_d })
        return true
      elseif can_grow_basic(my_protein_stack) then
        grow_from_head(next_head_x, next_head_y, BASIC)
        return true
      end
    end
  end
  return false
end

local function grow_towards_closest_enemy(my_protein_stack, all_things)
  local d, e = closest_enemy(head, all_things)
  if d and e then
    debug("distance to closest enemy from head is " .. d)
    debug("closest enemy is at " .. e.x .. "," .. e.y)
    local next_head_x, next_head_y = get_next_head_pos(e, all_things)
    if next_head_x ~= head.x or next_head_y ~= head.y then
      if can_grow_basic(my_protein_stack) then
        grow_from_head(next_head_x, next_head_y, BASIC)
        return true
      end
    end
  end
  return false
end

while true do
  local instr_sent = false
  local all_things = parse()
  local my_protein_stack, enemy_protein_stack = protein_stacks()
  local requiredActionsCount = tonumber(io.read())

  -- grow towards closest protein, maybe planting a harvester
  if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_harvester(my_protein_stack)) then
    debug("calling grow_towards_closest_protein")
    instr_sent = grow_towards_closest_protein(my_protein_stack, all_things)
  end

  -- grow towards closest enemy, maybe planting a tentacle
  if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_tentacle(my_protein_stack)) then
    debug("calling grow_towards_closest_enemy")
    instr_sent = grow_towards_closest_enemy(my_protein_stack, all_things)
  end

  -- spread anywhere
  if not instr_sent and can_grow_basic(my_protein_stack) then
    debug("calling spread anywhere")
    instr_sent = spread_anywhere(all_things)
  end

  if not instr_sent then
    print("WAIT")
  end
end
