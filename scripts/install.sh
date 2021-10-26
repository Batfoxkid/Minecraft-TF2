mkdir build
cd build

wget --input-file=http://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

cp -r ../addons/sourcemod/scripting addons/sourcemod
cd addons/sourcemod/scripting