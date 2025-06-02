# 
# Copyright (C) 2024 Vedad Hadžić
# Modified by Feng Zhou, 2025
# 
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# 

set IN_FILES       [regexp -all -inline {\S+} $::env(IN_FILES)]
set TOP_MODULE     $::env(TOP_MODULE)
set OUT_BASE       $::env(OUT_BASE)
set LIBERTY        $::env(LIBERTY)
set FV_DEF        $::env(FV_DEF)

if {[info exists env(SHARES)]} {
    set SHARES $::env(SHARES)
} else {
    set SHARES ""
}

set MACRO_DEF [list]

if {[info exists env(FV_DEF)] && $::env(FV_DEF) == 1} {
    lappend MACRO_DEF -D FV
}
if {[info exists env(IA_DEF)] && $::env(IA_DEF) == 1} {
    lappend MACRO_DEF -D IA
}

# if {[info exists env(FV_DEF)] && $::env(FV_DEF) == 1} {
#     set MACRO_DEF "-D FV"
# } else {
#     set MACRO_DEF ""
# }


set order [expr {$SHARES - 1}]

set VLOG_PRE_MAP   $OUT_BASE/o$order/pre.v
set VLOG_POST_MAP  $OUT_BASE/o$order/post.v
set JSON_PRE_MAP   $OUT_BASE/o$order/pre.json
set JSON_POST_MAP  $OUT_BASE/o$order/post.json
set STATS_FILE     $OUT_BASE/o$order/stats.txt

foreach file $IN_FILES {
    yosys read_verilog -defer {*}$MACRO_DEF $file
}

yosys log "SHARES = $SHARES"
if {![string equal "" $SHARES]} {
    # yosys chparam -set d [expr $SHARES] $TOP_MODULE
    if {[string equal $TOP_MODULE "aes_sbox"]} {
        yosys chparam -set SHARES [expr $SHARES] $TOP_MODULE
    } else {
        yosys chparam -set d [expr $SHARES] $TOP_MODULE
    }
}
# yosys log "LATENCY = $LATENCY"
# if {![string equal "" $LATENCY]} {
#     yosys chparam -set LATENCY [expr $LATENCY] $TOP_MODULE
# }
# yosys log "CHOSEN_STAGE_TYPE = $CHOSEN_STAGE_TYPE"
# if {![string equal "" $CHOSEN_STAGE_TYPE]} {
#     yosys chparam -set CHOSEN_STAGE_TYPE [expr $CHOSEN_STAGE_TYPE] $TOP_MODULE
# }
# yosys log "CHOSEN_INVERTER_TYPE = $CHOSEN_INVERTER_TYPE"
# if {![string equal "" $CHOSEN_INVERTER_TYPE]} {
#     yosys chparam -set CHOSEN_INVERTER_TYPE [expr $CHOSEN_INVERTER_TYPE] $TOP_MODULE
# }

yosys synth -top $TOP_MODULE -flatten
yosys tee -o $STATS_FILE stat
yosys clean
yosys stat

yosys write_verilog $VLOG_PRE_MAP
yosys write_json    $JSON_PRE_MAP

yosys dfflibmap -liberty $LIBERTY
yosys abc -liberty $LIBERTY
yosys clean -purge

yosys write_verilog $VLOG_POST_MAP
yosys write_json    $JSON_POST_MAP
yosys tee -o $STATS_FILE stat -liberty $LIBERTY