local http_request = require "http.request"
local http_util = require "http.util"
local cjson = require "cjson"
local types = require "tableshape".types

local argsTableShape = types.shape{
  where = types.string,
  groupBy = types.string:is_optional(),
  join = types.string:is_optional(),
  orderBy = types.string:is_optional()
}

--- @param tables string
--- @param fields string
--- @param argsTable {
---  where: string,
---  orderBy: string?,
---  join: string?,
---  groupBy: string?,
--- }
--- @return table
local function cargo(tables, fields, argsTable)
  assert(argsTableShape(argsTable))

  local paramsTable = {
    tables = tables,
    fields = fields,
    format = "json",
    formatversion = "2" -- might only have an effect with api.php, not Special:CargoExport like here
  }

  if argsTable.groupBy then
    paramsTable["group+by"] = argsTable.groupBy
  end

  if argsTable.join then
    paramsTable["join+on"] = argsTable.join
  end

  local paramsString = http_util.dict_to_query(paramsTable)

  -- dict_to_query does important encoding stuff,
  -- but we actually need the plus character to not be encoded for CargoExport
  -- so we just kinda patch it "back" like this.
  paramsString = paramsString:gsub("%%2[Bb]", "+")


  local headers, stream = assert(
    http_request.new_from_uri(
    "https://dragdown.wiki/Special:CargoExport?" .. paramsString
    ):go()
  )

  local body = assert(stream:get_body_as_string())

  if headers:get ":status" ~= "200" then
    error(body)
  end

  local ok, json = pcall(function()
    return cjson.decode(body)
  end)

  if not ok then
    error("Failed to decode json. Body:\n\""..body.."\"")
  end

  return json
end

return cargo
