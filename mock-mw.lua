local luassert = require("luassert")
local cargo  = require("cargo")

local node_mt = {}
node_mt.__index = node_mt

function node_mt:addClass(cls)
  luassert.is.string(cls)

  self._class = cls
  return self
end

function node_mt:css(nameOrTable, maybeValue)
  if type(nameOrTable) == "string" then
    luassert.is_string(maybeValue)

    self._css = nameOrTable .. ": " .. maybeValue .. "; "
  else
    luassert.is_table(nameOrTable)
    luassert.is_nil(maybeValue)

    for k, v in pairs(nameOrTable) do
      self._css = k .. ": " .. v .. "; "
    end
  end

  return self
end

function node_mt:attr(name, value)
  luassert.is.string(name)
  luassert.is.string(value)

  self._attr[name] = value
  return self
end

function node_mt:node(node)
  luassert.same(getmetatable(node), getmetatable(self))

  node._parent = self
  table.insert(self._nodes, node)
  return self
end

function node_mt:wikitext(wikitext)
  luassert.is_string(wikitext)

  table.insert(self._nodes, wikitext)
  return self
end

function node_mt:allDone()
  local parent = self._parent

  while parent ~= nil do
    parent = parent._parent
  end

  return parent or self
end

function node_mt:done()
  return self._parent or self
end

function node_mt:__tostring()
  local r = "<" .. self._tag

  if self._class then
    r = r .. " class=\"" .. self._class .. "\""
  end

  if self._css ~= "" then
    r = r .. " style=\""

    if type(self._css) == "string" then
      r = r .. self._css
    else
      for k, v in pairs(self._css) do
        r = r .. k .. ": " .. v .. "; "
      end
    end

    r = r .. "\""
  end

  for k, v in pairs(self._attr) do
    r = r .. " " .. k .. "=\"" .. v .. "\""
  end

  r = r .. ">"

  for k, v in pairs(self._nodes) do
    r = r .. "\n  " .. tostring(v)
  end

  r = r .. "</" .. self._tag .. ">"

  return r
end

_G.mw = {
  html = {
    create = function(tag)
      luassert.is.string(tag)

      return setmetatable({
        _tag = tag,
        _css = "",
        _attr = {},
        _nodes = {},
        _parent = nil
      }, node_mt)
    end
  },
  title = {
    getCurrentTitle = function()
      return {
        rootText = "AFQM",
        subpageText = "Rend"
      }
    end
  },
  getCurrentFrame = function()
    return {
      extensionTag = function(self, tbl)
        return "<extensionTag todo: mock>"
        -- local result = "{{"

        -- local firstIsTbl = type(tbl) == "table"

        -- if firstIsTbl then
        --   result = result
        -- else
        --   result = result .. tbl
        -- end

        -- if tbl.args and tbl.args.src then
        --   result = result .. "|"..tbl.args.src
        -- end

        -- if tbl.content then
        --   result = result .. "|" .. tbl.content
        -- end

        -- result = result .. "}}"
        -- return result
      end
    }
  end,
  ext = {
    cargo = {
      query = cargo
    }
  },
  ustring = {
    find = function(str, pattern, init, plain)
      return string.find(str, pattern, init, plain)
    end
  }
}
