#!/bin/bash
#
#Generate the button scripts from the list of buttons
buttons_list=("disp_on"  
"disp_mode"  
"shift"  
"filt_to_comp"  
"phase_inv"  
"preset"  
"pg_up"  
"pg_dn"  
"tr1"  
"tr2"  
"tr3"  
"tr4"  
"tr5"  
"tr6"  
"tr7"  
"tr8"  
"tr9"  
"tr10"  
"tr11"  
"tr12"  
"tr13"  
"tr14"  
"tr15"  
"tr16"  
"tr17"  
"tr18"  
"tr19"  
"tr20"  
"shape"  
"hard_gate"  
"eq"  
"hp_shape"  
"lp_shape"  
"comp"  
"tr_grp"  
"tr_copy"  
"order"  
"ext_sidechain"  
"solo"  
"mute"  
) 

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
pwd
cd ../button_scripts || exit
pwd

for i in "${!buttons_list[@]}"; do 

actionId=$(( i+1 )) # actionId from internals/types.lua
button=${buttons_list[$i]}
path="Console1_$button.lua"
 

read -r -d '' lua_text << EOM
--[[
POC -- call the state machine with the current button’s identifier
]]

--@noindex
local info = debug.getinfo(1, "S")
local root_path = info.source:match([[([^@]*Console1[^\\/]*[\\/])]])
package.path = package.path .. ";" .. root_path .. "?.lua"

local doInput = require("perken_controller")

doInput($actionId)
EOM
    echo "$lua_text" > "$path"
done
