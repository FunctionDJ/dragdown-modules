require "mock-mw"

package.path = package.path .. ";./modules/?.lua"

local afqmMoveCard = require "modules.AFQM Move Card"

local args = {
  chara = "Rend",
  attack = "Jab",
  desc = "desc",
  advDesc = "advDesc"
}

print(tostring(afqmMoveCard._main(args)))