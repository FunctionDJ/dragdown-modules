- see `scripts/setup.sh`
- copy `.env.example` to `.env` and adjust it

## setting up lua debug
- lua-debug must be built in order to use it, not just installing the VSCode extension
- https://github.com/actboy168/lua-debug#build

various docs with useful info that are usually not on the first page of google:
- https://community.fandom.com/wiki/Help:Tabber
- https://community.fandom.com/wiki/Help:Scribunto
- https://river.me/blog/cargo-list-type-fields/

to-dos and things to consider:
- https://github.com/lunarmodules/luacheck
- https://lunarmodules.github.io/busted/
- https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#strict

## general workflow

0. depending on your setup, you may need to edit package.path/package.cpath, see `framework/reference-lib.lua`
1. use `scripts/write-reference-output.lua` to render module output HTML to `./reference-output`
(slow on first run, repeat cargo queries are cached in `.cache`)
2. use `scripts/compare-reference-output.lua` to render modules and compare their output to `./reference-output`
3. optional: use `scripts/watch-compare.sh` to automatically run the compare script when `.lua` files are changed