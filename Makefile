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

YOSYS = yosys
VERILATOR = verilator
CXX = g++

SV_DIR = rtl
V_DIR = gen
TB_DIR = tb
CPP_DIR = cpp
OBJ_DIR = obj
SYN_DIR = syn

VERILATOR_FLAGS = --Mdir $(OBJ_DIR) -CFLAGS -I$(shell pwd)/$(CPP_DIR) -cc -sv -I$(SV_DIR) --exe --build -Wall
VERILATOR_SYN_FLAGS = --Mdir $(OBJ_DIR) -CFLAGS -I$(shell pwd)/$(CPP_DIR) -cc --exe --build -Wall -Wno-unused -Wno-declfilename -Wno-unoptflat -Wno-undriven -O0


clean:
	rm -rf $(V_DIR) $(OBJ_DIR) $(SYN_DIR)

SHARES ?= 2
ORDER := $(shell expr $(SHARES) - 1)

N ?= 5
MAX_ORDER = $(shell expr $(N) - 1)

resdir:
	bash -c '\
	for variant in aes_hdl_41_noia aes_hdl_51_noia; do \
	  for i in `seq 1 $(MAX_ORDER)`; do \
	    dir=o$$i; \
	    mkdir -p "syn/$${variant}/sbox/$${dir}"; \
	    mkdir -p "syn/$${variant}/full_aes/wrapper_aes128/$${dir}"; \
	    mkdir -p "syn/$${variant}/full_aes/MSKaes_128bits_round_based/$${dir}"; \
	  done; \
	done'


aes_hdl_%/sbox/aes_sbox:
	IN_FILES="$(shell find aes_hdl_$* -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v")" \
	SHARES=$(SHARES) \
	TOP_MODULE="aes_sbox" \
	OUT_BASE="syn/aes_hdl_$*/sbox/" \
	LIBERTY="stdcells.lib" \
	yosys synth.tcl -t -l "syn/aes_hdl_$*/sbox/o$(ORDER)/log.txt"

aes_hdl_%/full_aes/wrapper_aes128:
	IN_FILES="$(shell find aes_hdl_$* -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v")" \
	SHARES=$(SHARES) \
	TOP_MODULE="wrapper_aes128" \
	OUT_BASE="syn/aes_hdl_$*/full_aes/wrapper_aes128/" \
	LIBERTY="stdcells.lib" \
	yosys synth.tcl -t -l "syn/aes_hdl_$*/full_aes/wrapper_aes128/o$(ORDER)/log.txt"

aes_hdl_%/full_aes/MSKaes_128bits_round_based:
	IN_FILES="$(shell find aes_hdl_$* -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v")" \
	SHARES=$(SHARES) \
	TOP_MODULE="MSKaes_128bits_round_based" \
	OUT_BASE="syn/aes_hdl_$*/full_aes/MSKaes_128bits_round_based/" \
	LIBERTY="stdcells.lib" \
	yosys synth.tcl -t -l "syn/aes_hdl_$*/full_aes/MSKaes_128bits_round_based/o$(ORDER)/log.txt"

.PHONY: syn_sbox

syn_sbox:
	@for i in $$(seq 2 $(N)); do \
		echo "=== Building SHARES=$$i ==="; \
		make aes_hdl_41_noia/sbox/aes_sbox SHARES=$$i || exit 1; \
		make aes_hdl_51_noia/sbox/aes_sbox SHARES=$$i || exit 1; \
	done

syn_aes_core:
	@for i in $$(seq 2 $(N)); do \
		echo "=== Building SHARES=$$i ==="; \
		make aes_hdl_51_noia/full_aes/MSKaes_128bits_round_based SHARES=$$i || exit 1; \
	done
# 		make aes_hdl_41_noia/full_aes/MSKaes_128bits_round_based SHARES=$$i || exit 1; \

syn_aes_wrapper:
	@for i in $$(seq 2 $(N)); do \
		echo "=== Building SHARES=$$i ==="; \
		make aes_hdl_51_noia/full_aes/wrapper_aes128 SHARES=$$i || exit 1; \
	done

# 		make aes_hdl_41_noia/full_aes/wrapper_aes128 SHARES=$$i || exit 1; \


# verilate_%_noia: 
# 	VERILATOR_IN_FILES=$$(find aes_hdl_$*_noia -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v"); \
# 	verilator -Wno-fatal -cc $$VERILATOR_IN_FILES \
# 		--exe aes_hdl_51_noia/tb.cpp \
# 		--top-module wrapper_aes128 \
# 		-CFLAGS "-O2 -Wall" \
# 		--trace \
# 		-Iaes_hdl_$*_noia\
# 		-DDEFAULTSHARES=3 -DLATENCY=4 \
# 		-Iaes_hdl_$*_noia/sbox
# 	$(MAKE) -C obj_dir -f Vwrapper_aes128.mk
# 	./obj_dir/Vwrapper_aes128

# verilate_%_noia:
# 	@MODULE=aes_hdl_$*_noia; \
# 	VERILATOR_IN_FILES=$$(find $$MODULE -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v"); \
# 	verilator -Wno-fatal -cc $$VERILATOR_IN_FILES \
# 		--exe $$MODULE/tb.cpp \
# 		--top-module wrapper_aes128 \
# 		-CFLAGS "-O2 -Wall" \
# 		--trace \
# 		-I$$MODULE \
# 		-I$$MODULE/sbox \
# 		-DDEFAULTSHARES=3 -DLATENCY=4
# 	$(MAKE) -C obj_dir -f Vwrapper_aes128.mk
# 	./obj_dir/Vwrapper_aes128


verilate_%_noia:
	@ID=$*; \
	MODULE=aes_hdl_$${ID}_noia; \
	if [ "$$ID" = "41" ]; then LATENCY=3; else LATENCY=4; fi; \
	VERILATOR_IN_FILES=$$(find $$MODULE -type f -name "*.v" ! -name "tb_*.v" ! -name "final*.v"); \
	verilator -Wno-fatal -cc $$VERILATOR_IN_FILES \
		--exe aes_hdl_51_noia/tb.cpp \
		--top-module wrapper_aes128 \
		-CFLAGS "-O2 -Wall" \
		--trace \
		-I$$MODULE \
		-I$$MODULE/sbox \
		-DDEFAULTSHARES=3 -DLATENCY=$$LATENCY
	$(MAKE) -C obj_dir -f Vwrapper_aes128.mk
	./obj_dir/Vwrapper_aes128

# 		--exe $$MODULE/tb.cpp \
