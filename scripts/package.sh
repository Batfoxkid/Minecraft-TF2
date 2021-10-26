cd build

mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs

cp -r addons/sourcemod/plugins/minecraft_tf2.smx package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/configs/mc package/addons/sourcemod/configs
cp -r ../maps package
cp -r ../materials package
cp -r ../models package
cp -r ../sound package