- on linux: `apt install lua5.1`
- on linux, to use `watch.sh`: `apt install inotify-tools`
- install luarocks to install dependencies for local execution/testing: `apt install luarocks`

luarocks dependencies:
- `luarocks install luaassert` (used by mock-mw)

## setting up lua debug
- lua-debug must be built in order to use it, not just installing the VSCode extension
- https://github.com/actboy168/lua-debug#build