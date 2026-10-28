-- fg_view.lua : desenho do STREET DUEL (tela 480x270). Usa so gfx: clear, fill, box, text.
-- Cores em 0xRRGGBB. opts.names = { "J1", "J2" }; opts.title / opts.select = linhas de texto.
local Fight = require("fg_core")
local View = {}
View.W, View.H, View.CHAR_W = 480, 270, 8

local G = Fight.GROUND
local floor, ceil, max = math.floor, math.ceil, math.max

local C = { white = 0xffffff, dim = 0x9badb7, gold = 0xfbf236, ink = 0x222034,
            good = 0x6abe30, bad = 0xd95763, bar = 0x595652, blue = 0x639bff }

-- aparencia de cada lutador (mesma ordem de Fight.CHARS)
local LOOK = {
  { shirt = 0xcbdbfc, shade = 0x9badb7, pants = 0xcbdbfc, shoe = 0x8f563b, skin = 0xeec39a,
    hair = 0x222034, belt = 0x222034, accent = 0xd95763, sleeve = 0xcbdbfc, glove = 0xd95763 },
  { shirt = 0x4b692f, shade = 0x323c39, pants = 0x524b24, shoe = 0x222034, skin = 0xd9a066,
    hair = 0x663931, belt = 0x8a6f30, accent = 0xfbf236, sleeve = 0xd9a066, glove = 0x595652, big = 3 },
  { shirt = 0x76428a, shade = 0x45283c, pants = 0x222034, shoe = 0xd77bba, skin = 0xeec39a,
    hair = 0xd77bba, belt = 0xd77bba, accent = 0xd77bba, sleeve = 0xeec39a, glove = 0x76428a },
  { shirt = 0x306082, shade = 0x3f3f74, pants = 0x222034, shoe = 0xfbf236, skin = 0xd9a066,
    hair = 0xfbf236, belt = 0xfbf236, accent = 0xfbf236, sleeve = 0x306082, glove = 0xfbf236,
    goggle = 0x5fcde4 },
}

local function center(gfx, s, y, c)
  gfx.text(s, floor((View.W - #s * View.CHAR_W) / 2), y, c)
end

-- ---------- cenario ----------
local function stage(gfx)
  gfx.fill(0, 0, 480, 40, 0x222034)
  gfx.fill(0, 40, 480, 50, 0x3f3f74)
  gfx.fill(0, 90, 480, 50, 0x76428a)
  gfx.fill(0, 140, 480, G - 140, 0xd77bba)
  for i = 1, 24 do gfx.fill((i * 97) % 480, (i * 53) % 80, 2, 2, C.white) end
  gfx.fill(392, 26, 24, 24, 0xcbdbfc); gfx.fill(388, 30, 32, 16, 0xcbdbfc); gfx.fill(396, 22, 16, 32, 0xcbdbfc)
  local hs = { 60, 90, 75, 110, 65, 95, 80, 105, 70, 85 }
  for i = 1, 10 do
    local bx, bh = (i - 1) * 48 + 4, hs[i]
    gfx.fill(bx, G - bh - 20, 40, bh + 20, 0x3f3f74)
    gfx.fill(bx, G - bh - 20, 40, 3, 0x306082)
    for wy = 0, floor(bh / 12) do
      for wx = 0, 2 do
        if (i * 7 + wx * 3 + wy * 5) % 3 ~= 0 then
          gfx.fill(bx + 5 + wx * 12, G - bh - 12 + wy * 12, 6, 6, C.gold)
        end
      end
    end
  end
  gfx.fill(0, G, 480, 270 - G, 0x595652)
  gfx.fill(0, G, 480, 3, 0x847e87)
  for x = 0, 480, 48 do gfx.fill(x, G + 3, 2, 270 - G - 3, 0x45283c) end
  gfx.fill(0, G + 22, 480, 2, 0x45283c)
end

-- ---------- lutador ----------
-- R(lx, ly, w, h, cor): lx para frente (+), ly para cima (-), relativo aos pes; espelha por face.
local function mk(gfx, px, py, face, sc, flash)
  return function(lx, ly, w, h, c)
    local x0 = (face > 0) and (px + lx * sc) or (px - (lx + w) * sc)
    gfx.fill(floor(x0), floor(py + ly * sc), max(1, floor(w * sc)), max(1, floor(h * sc)), flash and C.white or c)
  end
end

-- pose.kind: idle walk jump punch kick block special hurt ko | pose.len | pose.step | pose.flash
local function draw_char(gfx, id, px, py, face, sc, pose)
  local L = LOOK[id]
  local R = mk(gfx, px, py, face, sc, pose.flash)
  local k = pose.kind
  local w = L.big or 0

  if k == "ko" then
    R(8, -10, 18, 8, L.pants); R(24, -10, 5, 8, L.shoe)
    R(-12 - w, -12, 22 + w, 12, L.shirt)
    R(-24, -14, 11, 11, L.skin); R(-25, -17, 11, 5, L.hair)
    return
  end

  local lean = (k == "hurt") and -3 or ((k == "kick") and -2 or 0)
  local air = (k == "jump")
  local lh = air and 14 or 24
  local sw = (k == "walk") and ((pose.step == 0) and 2 or -2) or 0
  local top = -lh - 32
  local hx = -6 + lean

  -- braco de tras
  R(-13 - w + lean, -lh - 18, 5 + w, 13, L.sleeve)
  R(-13 - w + lean, -lh - 7, 5 + w, 5, L.glove)
  -- perna de tras
  R(-9 - w - sw, -lh, 8, lh - 4, L.pants)
  R(-11 - w - sw, -4, 11, 4, L.shoe)
  -- tronco
  R(-11 - w + lean, -lh - 20, 22 + 2 * w, 20, L.shirt)
  R(-11 - w + lean, -lh - 20, 5, 20, L.shade)
  R(-11 - w + lean, -lh - 3, 22 + 2 * w, 3, L.belt)
  R(-1 + lean, -lh - 3, 4, 3, L.accent)
  if id == 1 then
    R(2 + lean, -lh - 20, 5, 8, L.skin)                       -- gola do kimono
  elseif id == 2 then
    R(-13 - w + lean, -lh - 23, 7, 6, 0x595652); R(7 + w + lean, -lh - 23, 7, 6, 0x595652)
    R(-3 + lean, -lh - 20, 3, 17, L.belt)
  elseif id == 3 then
    R(-7 + lean, -lh - 23, 16, 4, L.accent); R(-15 + lean, -lh - 23, 9, 3, L.accent)
    R(-11 + lean, -lh, 22, 5, L.shirt)
  elseif id == 4 then
    R(-2 + lean, -lh - 18, 4, 5, L.accent); R(0 + lean, -lh - 14, 4, 5, L.accent)
    R(-6 + lean, -lh - 21, 12, 3, L.shade)
  end
  -- perna da frente
  if k ~= "kick" then
    R(1 + sw, -lh, 8, lh - 4, L.pants)
    R(1 + sw, -4, 12, 4, L.shoe)
  else
    local len = pose.len or 20
    R(2, -28, len, 9, L.pants)
    R(len, -31, 7, 13, L.shoe)
    if pose.active then R(len + 7, -32, 3, 15, C.white) end
  end
  -- cabeca
  R(hx, top, 12, 12, L.skin)
  if k == "hurt" then
    R(hx + 7, top + 5, 3, 1, L.hair)
    R(hx + 8, top + 9, 2, 2, 0xac3232)
  else
    R(hx + 7, top + 4, 3, 3, C.white); R(hx + 8, top + 5, 2, 2, C.ink)
    R(hx + 7, top + 9, 3, 1, 0xac3232)
  end
  -- cabelo e acessorios
  if id == 1 then
    R(hx - 1, top - 2, 14, 5, L.hair); R(hx + 2, top - 4, 4, 3, L.hair); R(hx + 8, top - 3, 4, 3, L.hair)
    R(hx - 1, top + 3, 14, 3, L.accent); R(hx - 9, top + 4, 8, 2, L.accent); R(hx - 11, top + 7, 6, 2, L.accent)
  elseif id == 2 then
    R(hx - 1, top - 1, 14, 3, L.hair)
    R(hx + 4, top + 9, 8, 4, L.hair)
    R(hx + 3, top + 3, 8, 2, L.hair)
  elseif id == 3 then
    R(hx - 1, top - 2, 14, 5, L.hair); R(hx - 3, top, 4, 14, L.hair)
    R(hx - 9, top + 2, 7, 3, L.hair); R(hx - 11, top + 5, 5, 12, L.hair)
  elseif id == 4 then
    R(hx - 1, top - 1, 14, 4, L.hair)
    R(hx + 1, top - 5, 3, 5, L.hair); R(hx + 6, top - 7, 3, 7, L.hair); R(hx + 10, top - 4, 3, 4, L.hair)
    R(hx - 3, top + 1, 3, 6, L.hair)
    R(hx + 1, top + 3, 11, 3, L.goggle); R(hx + 7, top + 4, 4, 2, C.white)
  end
  -- braco da frente
  if k == "punch" then
    local len = pose.len or 16
    R(6, -45, len - 6, 6, L.sleeve); R(len, -46, 7, 8, L.glove)
    if pose.active then R(len + 7, -47, 3, 10, C.white) end
  elseif k == "block" then
    R(5, -lh - 32, 7, 24, L.sleeve); R(4, -lh - 36, 9, 7, L.glove)
    R(10, -lh - 28, 6, 18, L.sleeve)
  elseif k == "special" then
    R(6, -lh - 21, 16, 6, L.sleeve); R(20, -lh - 23, 7, 9, L.glove)
    R(28, -lh - 24, 3, 11, L.accent)
  else
    R(6 + lean, -lh - 17, 7, 5, L.sleeve); R(11 + lean, -lh - 24, 5, 9, L.sleeve)
    R(11 + lean, -lh - 29, 7, 6, L.glove)
  end
end

local function pose_of(f)
  local p = { flash = (f.flash > 0 and f.blk == 0) }
  if f.ko then p.kind = "ko"
  elseif f.blk > 0 or (f.block and f.stun == 0) then p.kind = "block"
  elseif f.stun > 0 then p.kind = "hurt"
  elseif f.atk == "punch" or f.atk == "kick" then
    local m = Fight.MOVES[f.atk]
    p.kind = f.atk
    p.active = f.atkt > m.start and f.atkt <= m.start + m.active
    p.len = p.active and (m.reach + 4) or 16
  elseif f.atk == "special" then p.kind = "special"
  elseif not f.ground then p.kind = "jump"
  elseif f.vx ~= 0 then p.kind = "walk"; p.step = floor(f.x / 7) % 2
  else p.kind = "idle" end
  return p
end

local function fighter(gfx, f)
  local x, y = floor(f.x), floor(f.y)
  local wd = max(8, 28 - floor((G - y) / 6))
  gfx.fill(x - floor(wd / 2), G + 4, wd, 3, 0x323c39)
  draw_char(gfx, f.c.id, x, y, f.face, 1, pose_of(f))
  if f.atk == "special" and f.c.special == "dash" and math.abs(f.vx) > 3 then
    local d = -f.face
    gfx.fill(x + d * 16 - (d < 0 and 16 or 0), y - 40, 16, 2, C.white)
    gfx.fill(x + d * 24 - (d < 0 and 20 or 0), y - 28, 20, 2, C.white)
  end
end

local function draw_shot(gfx, s)
  local x, y = floor(s.x), floor(s.y)
  if s.kind == "fire" then
    gfx.fill(x - 7, y - 6, 14, 12, 0xdf7126); gfx.fill(x - 5, y - 4, 10, 8, C.gold); gfx.fill(x - 2, y - 2, 5, 4, C.white)
  elseif s.kind == "twin" then
    gfx.fill(x - 6, y - 3, 12, 6, 0xd77bba); gfx.fill(x - 3, y - 1, 6, 2, C.white)
  else
    gfx.fill(x - 3, 0, 6, y, C.gold); gfx.fill(x - 1, 0, 2, y, C.white)
    gfx.fill(x - 8, y - 4, 16, 6, 0x5fcde4)
  end
end

-- ---------- HUD ----------
local function bar(gfx, x, y, hp, maxhp, from_right)
  gfx.fill(x, y, 190, 12, C.bar)
  local len = floor(190 * hp / maxhp)
  local col = (hp * 2 > maxhp) and C.good or ((hp * 4 > maxhp) and C.gold or C.bad)
  if len > 0 then gfx.fill(from_right and (x + 190 - len) or x, y, len, 12, col) end
  gfx.box(x - 1, y - 1, 192, 14, C.white)
end

local function hud(gfx, g, names)
  local a, b = g.f[1], g.f[2]
  bar(gfx, 20, 14, a.hp, a.maxhp, true)
  bar(gfx, 270, 14, b.hp, b.maxhp, false)
  gfx.text(names[1] .. " - " .. a.c.name, 20, 30, C.blue)
  local s2 = names[2] .. " - " .. b.c.name
  gfx.text(s2, 460 - #s2 * View.CHAR_W, 30, C.bad)
  for i = 1, Fight.ROUNDS do
    gfx.box(20 + (i - 1) * 12, 42, 8, 8, C.gold)
    if a.wins >= i then gfx.fill(21 + (i - 1) * 12, 43, 6, 6, C.gold) end
    gfx.box(452 - (i - 1) * 12, 42, 8, 8, C.gold)
    if b.wins >= i then gfx.fill(453 - (i - 1) * 12, 43, 6, 6, C.gold) end
  end
  local t = max(0, ceil(g.clock / 60))
  center(gfx, (t < 10 and "0" or "") .. t, 16, C.white)
end

local function banner(gfx, g, names, frame)
  local s = g.state
  if s == "intro" then
    if g.timer > 60 then center(gfx, "ROUND " .. g.round, 100, C.gold)
    else center(gfx, "FIGHT!", 100, C.white) end
  elseif s == "roundend" then
    local ko = g.f[1].ko or g.f[2].ko
    center(gfx, ko and "K.O.!" or "TEMPO ESGOTADO", 90, C.bad)
    local w = g.round_winner
    center(gfx, w and (names[w] .. " VENCE O ROUND") or "EMPATE", 110, C.white)
  elseif s == "matchover" then
    gfx.fill(110, 80, 260, 80, C.ink)
    gfx.box(110, 80, 260, 80, C.gold)
    center(gfx, names[g.winner] .. " VENCEU A LUTA!", 98, C.gold)
    center(gfx, g.f[1].wins .. " x " .. g.f[2].wins, 118, C.white)
    if g.timer >= 60 and floor(frame / 30) % 2 == 0 then center(gfx, "Z: VOLTAR", 138, C.gold) end
  end
end

-- ---------- selecao de personagem ----------
local function draw_select(gfx, app, frame, names, hint)
  center(gfx, "ESCOLHA O LUTADOR", 8, C.gold)
  for i, l in ipairs(hint) do center(gfx, l, 20 + (i - 1) * 10, C.dim) end
  local PX0, PW, PH, PY = 15, 108, 190, 54
  for i, ch in ipairs(Fight.CHARS) do
    local x = PX0 + (i - 1) * (PW + 6)
    gfx.fill(x, PY, PW, PH, 0x323c39)
    gfx.fill(x, PY + 122, PW, PH - 122, 0x222034)
    local s1, s2 = (app.sel[1] == i), (app.sel[2] == i)
    local bc = (s1 and s2) and C.gold or (s1 and C.blue or (s2 and C.bad or C.bar))
    gfx.box(x, PY, PW, PH, bc)
    if s1 or s2 then gfx.box(x + 1, PY + 1, PW - 2, PH - 2, bc) end
    local pose = { kind = "idle" }
    if (s1 or s2) and floor(frame / 40) % 3 == 0 then pose = { kind = "punch", active = true, len = 36 } end
    draw_char(gfx, i, x + 46, PY + 120, 1, 2, pose)
    gfx.text(ch.name, x + floor((PW - #ch.name * 8) / 2), PY + 128, C.white)
    gfx.text(ch.sname, x + floor((PW - #ch.sname * 8) / 2), PY + 139, C.gold)
    local rows = { { "FOR", ch.dmg / 1.25 }, { "VEL", ch.speed / 2.2 }, { "VID", ch.hp / 125 } }
    for r, row in ipairs(rows) do
      local y = PY + 154 + (r - 1) * 11
      gfx.text(row[1], x + 5, y, C.dim)
      gfx.fill(x + 34, y + 1, 68, 6, C.bar)
      gfx.fill(x + 34, y + 1, floor(68 * row[2]), 6, C.good)
    end
    if s1 then gfx.text(names[1], x + 4, PY - 9, C.blue) end
    if s2 then gfx.text(names[2], x + PW - 4 - #names[2] * 8, PY - 9, C.bad) end
    if s1 and app.ready[1] then gfx.text("PRONTO", x + 4, PY + 4, C.blue) end
    if s2 and app.ready[2] then gfx.text("PRONTO", x + PW - 52, PY + 4, C.bad) end
  end
  if app.go then center(gfx, "VAMOS LUTAR!", 254, C.gold) end
end

View.TITLE = {
  { "JOGADOR 1: A D MOVER  W PULAR  S DEFENDER", 100 },
  { "F SOCO   G CHUTE   H PODER ESPECIAL", 112 },
  { "JOGADOR 2: SETAS (CIMA PULA, BAIXO DEFENDE)", 134 },
  { ", SOCO   . CHUTE   / PODER ESPECIAL", 146 },
}
View.SELECT = {
  "J1: A D ESCOLHE  F CONFIRMA  G CANCELA",
  "J2: SETAS ESCOLHEM  , CONFIRMA  . CANCELA",
}
View.NAMES = { "JOGADOR 1", "JOGADOR 2" }

function View.draw(app, gfx, frame, opts)
  opts = opts or {}
  local names = opts.names or View.NAMES
  gfx.clear(0x000000)
  if app.screen == "title" then
    gfx.box(8, 8, 464, 254, 0x595652)
    center(gfx, "STREET DUEL", 40, C.gold)
    center(gfx, "LUTA 2D - 4 LUTADORES - MELHOR DE 3", 58, C.dim)
    for _, l in ipairs(opts.title or View.TITLE) do gfx.text(l[1], 40, l[2], l[3] or C.white) end
    center(gfx, "DICA: DEFENDER REDUZ O DANO A QUASE ZERO", 190, C.dim)
    if floor(frame / 30) % 2 == 0 then center(gfx, "Z: INICIAR", 230, C.gold) end
    return
  end
  if app.screen == "select" then
    draw_select(gfx, app, frame, names, opts.select or View.SELECT)
    return
  end
  local g = app.game
  stage(gfx)
  for i = 1, 2 do fighter(gfx, g.f[i]) end
  for _, s in ipairs(g.shots) do draw_shot(gfx, s) end
  hud(gfx, g, names)
  banner(gfx, g, names, frame)
end

return View
