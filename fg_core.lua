-- fg_core.lua : regras do STREET DUEL (luta 2D, 4 lutadores, melhor de 3).
-- Lua puro: nao conhece LOVE nem tela. Sem math.random. Tudo em quadros (60 por segundo).
-- Coordenadas em pixels de uma tela 480x270. f.x = centro do lutador, f.y = pes.
local Fight = {}
Fight.__index = Fight

-- remove t[i] deslocando o resto (nao depende da biblioteca table)
local function remove_at(t, i)
  local n = #t
  for k = i, n - 1 do t[k] = t[k + 1] end
  t[n] = nil
end

Fight.W, Fight.H = 480, 270
Fight.GROUND = 224
Fight.ROUNDS = 2            -- rounds para vencer a luta
Fight.CLOCK = 60 * 60       -- 60 segundos por round
Fight.BW, Fight.BH = 24, 56 -- tamanho do corpo

local G = Fight.GROUND
local GRAV, JUMPV = 0.45, -7.5
local BW, BH = Fight.BW, Fight.BH

-- Lutadores. dmg multiplica o dano de soco/chute; speed = velocidade de caminhada;
-- special: "fire" bola de fogo | "dash" investida | "twin" tiro duplo | "bolt" raio do ceu.
Fight.CHARS = {
  { id = 1, name = "KENJI",  hp = 100, speed = 1.7,  dmg = 1.00, special = "fire", sname = "BOLA DE FOGO", cd = 90 },
  { id = 2, name = "BRUTUS", hp = 125, speed = 1.35, dmg = 1.25, special = "dash", sname = "INVESTIDA",    cd = 110 },
  { id = 3, name = "LUNA",   hp = 85,  speed = 2.2,  dmg = 0.90, special = "twin", sname = "DUPLO TIRO",   cd = 100 },
  { id = 4, name = "VOLT",   hp = 95,  speed = 1.8,  dmg = 1.00, special = "bolt", sname = "RAIO",         cd = 130 },
}

-- start: quadros antes de acertar | active: quadros com golpe ativo | recover: recuperacao
-- hy: altura do golpe acima dos pes | hh: espessura | reach: alcance | stun: tempo de tontura
Fight.MOVES = {
  punch = { start = 4, active = 3, recover = 9,  dmg = 6,  reach = 30, hy = 48, hh = 14, stun = 14, push = 2.5 },
  kick  = { start = 7, active = 4, recover = 13, dmg = 11, reach = 40, hy = 26, hh = 16, stun = 18, push = 4 },
}
Fight.SPECIALS = {
  fire = { start = 12, active = 0,  recover = 20 },
  twin = { start = 8,  active = 0,  recover = 26 },
  bolt = { start = 14, active = 0,  recover = 24 },
  dash = { start = 6,  active = 14, recover = 20, dmg = 12, reach = 24, hy = 50, hh = 40, stun = 22, push = 5 },
}
local MOVES, SPECIALS = Fight.MOVES, Fight.SPECIALS

local NOH = {}

local function newf(id, x, face, ci)
  local c = Fight.CHARS[ci] or Fight.CHARS[id]
  return { id = id, c = c, maxhp = c.hp, hp = c.hp, speed = c.speed,
           x = x, y = G, vx = 0, vy = 0, face = face,
           ground = true, atk = nil, atkt = 0, hit = false, stun = 0, block = false,
           blk = 0, cd = 0, flash = 0, ko = false, wins = 0, prev = {} }
end

function Fight:reset_round()
  for i = 1, 2 do
    local f = self.f[i]
    f.x = (i == 1) and 150 or 330
    f.face = (i == 1) and 1 or -1
    f.y, f.vx, f.vy, f.hp = G, 0, 0, f.maxhp
    f.ground, f.atk, f.atkt, f.hit = true, nil, 0, false
    f.stun, f.block, f.blk, f.cd, f.flash, f.ko = 0, false, 0, 0, 0, false
  end
  self.shots = {}
  self.clock = Fight.CLOCK
  self.state, self.timer = "intro", 120
  self.round_winner = nil
end

-- c1, c2: indices em Fight.CHARS
function Fight.new(c1, c2)
  local g = setmetatable({}, Fight)
  g.f = { newf(1, 150, 1, c1 or 1), newf(2, 330, -1, c2 or 2) }
  g.round, g.winner = 1, nil
  g:reset_round()
  return g
end

local function start_atk(f, kind)
  f.atk, f.atkt, f.hit = kind, 0, false
end

local function dmgx(f, d) return math.floor(d * f.c.dmg + 0.5) end

local function rect_hit(f, m, o)
  local x1, x2 = f.x + f.face * 8, f.x + f.face * (8 + m.reach)
  local ax0, ax1 = math.min(x1, x2), math.max(x1, x2)
  local ay0, ay1 = f.y - m.hy, f.y - m.hy + m.hh
  return ax0 < o.x + BW / 2 and ax1 > o.x - BW / 2 and ay0 < o.y and ay1 > o.y - BH
end

function Fight:shoot(f, kind, x, y, vx, vy, dmg)
  self.shots[#self.shots + 1] = { x = x, y = y, vx = vx, vy = vy, owner = f.id, kind = kind, dmg = dmg }
end

function Fight:hurt(o, dmg, stun, push, dir)
  if o.block and o.ground and o.stun == 0 and not o.atk then
    dmg, stun, push = math.floor(dmg * 0.15), 6, push * 0.6
    o.blk = 8
  else
    o.flash = 8
    o.atk, o.atkt, o.hit = nil, 0, false
  end
  o.hp = math.max(0, o.hp - dmg)
  o.stun, o.vx = stun, dir * push
  if o.hp <= 0 then
    o.ko, o.stun = true, 0
    o.vx, o.vy, o.ground = dir * 3, -4, false
  end
end

function Fight:step(f, o, h)
  local pr = f.prev
  if not f.ground then
    f.vy = f.vy + GRAV
    f.y = f.y + f.vy
    if f.y >= G then f.y, f.vy, f.ground = G, 0, true end
  end
  f.x = f.x + f.vx
  if f.cd > 0 then f.cd = f.cd - 1 end
  if f.flash > 0 then f.flash = f.flash - 1 end
  if f.blk > 0 then f.blk = f.blk - 1 end

  if f.ko then
    f.vx = f.vx * 0.9
  elseif f.stun > 0 then
    f.stun = f.stun - 1
    f.vx = f.vx * 0.85
    f.block = false
  elseif f.atk then
    f.atkt = f.atkt + 1
    local m, dashing = nil, false
    if f.atk == "special" then
      local sp = f.c.special
      m = SPECIALS[sp]
      if sp == "fire" then
        if f.atkt == m.start then
          self:shoot(f, "fire", f.x + f.face * 18, f.y - 38, f.face * 3.2, 0, 8)
          f.cd = f.c.cd
        end
      elseif sp == "twin" then
        if f.atkt == m.start or f.atkt == m.start + 8 then
          self:shoot(f, "twin", f.x + f.face * 18, f.y - 36, f.face * 4.8, 0, 5)
        end
        if f.atkt == m.start then f.cd = f.c.cd end
      elseif sp == "bolt" then
        if f.atkt == m.start then
          self:shoot(f, "bolt", o.x, 0, 0, 9, 14)
          f.cd = f.c.cd
        end
      elseif sp == "dash" then
        if f.atkt == 1 then f.cd = f.c.cd end
        if f.atkt > m.start and f.atkt <= m.start + m.active then
          dashing = true
          f.vx = f.face * 5
          if not f.hit and rect_hit(f, m, o) then
            f.hit = true
            self:hurt(o, dmgx(f, m.dmg), m.stun, m.push, f.face)
            f.atkt = m.start + m.active
            dashing, f.vx = false, 0
          end
        end
      end
    else
      m = MOVES[f.atk]
      if f.atkt > m.start and f.atkt <= m.start + m.active and not f.hit then
        if rect_hit(f, m, o) then
          f.hit = true
          self:hurt(o, dmgx(f, m.dmg), m.stun, m.push, f.face)
        end
      end
    end
    if f.atkt >= m.start + m.active + m.recover then f.atk, f.atkt, f.hit = nil, 0, false end
    if f.ground and not dashing then f.vx = 0 end
  else
    local dir = (h.right and 1 or 0) - (h.left and 1 or 0)
    f.block = (h.block and f.ground) and true or false
    if f.ground then
      if o.x ~= f.x then f.face = (o.x > f.x) and 1 or -1 end
      f.vx = f.block and 0 or dir * f.speed
      if h.up and not f.block then f.vy, f.ground, f.vx = JUMPV, false, dir * f.speed end
    end
    if not f.block then
      if h.punch and not pr.punch then start_atk(f, "punch")
      elseif h.kick and not pr.kick then start_atk(f, "kick")
      elseif h.special and not pr.special and f.cd == 0 and f.ground then start_atk(f, "special")
      end
    end
  end
  pr.punch, pr.kick, pr.special = h.punch, h.kick, h.special
  if f.x < 20 then f.x = 20 elseif f.x > Fight.W - 20 then f.x = Fight.W - 20 end
end

function Fight:update_shots()
  for i = #self.shots, 1, -1 do
    local s = self.shots[i]
    s.x, s.y = s.x + s.vx, s.y + s.vy
    local o = self.f[s.owner == 1 and 2 or 1]
    local gone = s.x < -10 or s.x > Fight.W + 10 or s.y > G + 10
    local reach = (s.kind == "bolt") and (BW / 2 + 8) or (BW / 2 + 6)
    if not gone and not o.ko and math.abs(s.x - o.x) < reach and s.y > o.y - BH and s.y < o.y then
      self:hurt(o, s.dmg, 16, 3, (s.vx >= 0) and 1 or -1)
      gone = true
    end
    if gone then remove_at(self.shots, i) end
  end
end

function Fight:separate()
  local a, b = self.f[1], self.f[2]
  local d = b.x - a.x
  if math.abs(a.y - b.y) < 40 and math.abs(d) < 22 then
    local push = (22 - math.abs(d)) / 2
    local s = (d >= 0) and 1 or -1
    a.x, b.x = a.x - s * push, b.x + s * push
    if a.x < 20 then a.x = 20 elseif a.x > Fight.W - 20 then a.x = Fight.W - 20 end
    if b.x < 20 then b.x = 20 elseif b.x > Fight.W - 20 then b.x = Fight.W - 20 end
  end
end

-- h1, h2: tabelas {left,right,up,block,punch,kick,special} = true/false
function Fight:update(h1, h2)
  local a, b = self.f[1], self.f[2]
  local s = self.state
  if s == "intro" then
    self:step(a, b, NOH); self:step(b, a, NOH)
    self.timer = self.timer - 1
    if self.timer <= 0 then self.state = "fight" end
  elseif s == "fight" then
    self:step(a, b, h1 or NOH)
    self:step(b, a, h2 or NOH)
    self:update_shots()
    self:separate()
    self.clock = self.clock - 1
    if a.hp <= 0 or b.hp <= 0 or self.clock <= 0 then
      local w
      if a.hp > b.hp then w = 1 elseif b.hp > a.hp then w = 2 end
      self.round_winner = w
      if w then self.f[w].wins = self.f[w].wins + 1 end
      self.state, self.timer = "roundend", 150
    end
  elseif s == "roundend" then
    self:step(a, b, NOH); self:step(b, a, NOH)
    self:update_shots()
    self.timer = self.timer - 1
    if self.timer <= 0 then
      if a.wins >= Fight.ROUNDS or b.wins >= Fight.ROUNDS then
        self.winner = (a.wins > b.wins) and 1 or 2
        self.state, self.timer = "matchover", 0
      else
        self.round = self.round + 1
        self:reset_round()
      end
    end
  elseif s == "matchover" then
    self.timer = self.timer + 1
  end
end

return Fight
