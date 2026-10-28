-- fg_bot.lua : rival simples para o console (um controle so). Lua puro.
-- Devolve uma tabela de botoes {left,right,up,block,punch,kick,special}.
local Bot = {}
Bot.__index = Bot

-- level 1 (facil) a 3 (dificil): muda a chance de defender
function Bot.new(level)
  return setmetatable({
    h = { left = false, right = false, up = false, block = false,
          punch = false, kick = false, special = false },
    seed = 4242, hold = 0, mode = "idle", level = level or 2,
  }, Bot)
end

local function rnd(self, n)
  self.seed = (self.seed * 16807) % 2147483647
  return self.seed % n
end

-- cada poder funciona melhor numa distancia
local function special_ok(me, dist)
  if me.cd > 0 or not me.ground then return false end
  local k = me.c.special
  if k == "dash" then return dist > 50 and dist < 120 end
  if k == "bolt" then return dist > 40 end
  return dist > 110
end

function Bot:think(g, me, op)
  local h = self.h
  h.left, h.right, h.up, h.block = false, false, false, false
  h.punch, h.kick, h.special = false, false, false
  if g.state ~= "fight" or me.ko or me.stun > 0 then return h end

  local dist = math.abs(op.x - me.x)
  local toward = (op.x > me.x) and 1 or -1
  local fresh = false
  if self.hold <= 0 then
    fresh = true
    local r = rnd(self, 100)
    if op.atk and dist < 80 and r < self.level * 20 then
      self.mode, self.hold = "block", 20
    elseif r < 22 and special_ok(me, dist) then
      self.mode, self.hold = "special", 20
    elseif dist > 80 then
      self.mode, self.hold = "approach", 8
    elseif r < 30 then self.mode, self.hold = "punch", 12
    elseif r < 55 then self.mode, self.hold = "kick", 18
    elseif r < 65 then self.mode, self.hold = "block", 20
    elseif r < 78 then self.mode, self.hold = "retreat", 12
    elseif r < 88 then self.mode, self.hold = "jump", 24
    else self.mode, self.hold = "idle", 8 end
  end
  self.hold = self.hold - 1

  local m = self.mode
  local function go(d) if d > 0 then h.right = true else h.left = true end end
  if m == "approach" then go(toward)
  elseif m == "retreat" then go(-toward)
  elseif m == "block" then h.block = true
  elseif m == "jump" then
    if fresh then h.up = true; go(toward) end
  elseif m == "punch" then h.punch = fresh
  elseif m == "kick" then h.kick = fresh
  elseif m == "special" then h.special = fresh
  end
  return h
end

return Bot
