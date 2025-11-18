while inotifywait -q -e close_write *.lua; do
    lua main.lua
done
