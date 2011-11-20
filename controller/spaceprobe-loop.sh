cd `dirname $0`
while [ 1 ]; do
	/usr/bin/lua main.lua
	echo "lua died, restarting in 5..."
	sleep 5
done


