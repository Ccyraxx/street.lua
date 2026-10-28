-- fg_app.lua : telas (titulo -> selecao -> luta). Sem LOVE.
local Fight = require("fg_core")
local App = {}
App.__index = App

-- auto2 = true: o jogador 2 e controlado pelo programa (console): escolhe sozinho.
function App.new(auto2)
  return setmetatable({
    screen = "title", game = nil, auto2 = auto2 and true or false,
    sel = { 1, 2 }, ready = { false, false }, pv = { {}, {} }, st = 0, go = nil,
  }, App)
end

-- Botao de iniciar (Z): titulo -> selecao; fim da luta -> titulo.
function App:ok()
  if self.screen == "title" then
    self.screen, self.st, self.go = "select", 0, nil
    self.sel, self.ready, self.pv = { 1, 2 }, { false, false }, { {}, {} }
  elseif self.screen == "play" and self.game.state == "matchover" and self.game.timer >= 60 then
    self.screen, self.game = "title", nil
  end
end

function App:update_select(h1, h2)
  self.st = self.st + 1
  local n = #Fight.CHARS
  local hs = { h1, h2 }
  for i = 1, 2 do
    local h, pv = hs[i], self.pv[i]
    if self.st > 15 and not (i == 2 and self.auto2) then
      if not self.ready[i] then
        if h.left and not pv.left then self.sel[i] = (self.sel[i] - 2) % n + 1 end
        if h.right and not pv.right then self.sel[i] = self.sel[i] % n + 1 end
        if h.punch and not pv.punch then self.ready[i] = true end
      elseif h.kick and not pv.kick then
        self.ready[i] = false
      end
    end
    pv.left, pv.right, pv.punch, pv.kick = h.left, h.right, h.punch, h.kick
  end
  if self.auto2 then
    if not self.ready[1] then
      self.ready[2] = false
      if self.st % 25 == 0 then self.sel[2] = self.sel[2] % n + 1 end
    elseif not self.ready[2] then
      self.ready[2] = true
    end
  end
  if self.ready[1] and self.ready[2] then
    self.go = (self.go or 0) + 1
    if self.go > 40 then
      self.game, self.screen, self.go = Fight.new(self.sel[1], self.sel[2]), "play", nil
    end
  else
    self.go = nil
  end
end

function App:update(h1, h2)
  if self.screen == "select" then self:update_select(h1, h2)
  elseif self.screen == "play" then self.game:update(h1, h2) end
end

return App
