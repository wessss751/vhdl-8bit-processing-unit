GHDL ?= ghdl
YOSYS ?= yosys
GTKWAVE ?= gtkwave
GHDLFLAGS := --std=08 --workdir=build
RTL := rtl/data_generator.vhd rtl/input_register.vhd rtl/alu8.vhd \
       rtl/output_register.vhd rtl/fifo_sync.vhd rtl/control_fsm.vhd \
       rtl/button_debounce.vhd rtl/system_top.vhd
TB := tb/tb_alu8.vhd tb/tb_fifo_sync.vhd tb/tb_button_debounce.vhd tb/tb_system_top.vhd

.PHONY: all analyze test wave synth clean
all: test

build:
	mkdir -p build

analyze: | build
	$(GHDL) -a $(GHDLFLAGS) $(RTL) $(TB)

test: analyze
	$(GHDL) --elab-run $(GHDLFLAGS) tb_alu8 --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_fifo_sync --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_fifo_sync -gDEPTH=1 --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_fifo_sync -gDEPTH=3 --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_button_debounce --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_button_debounce -gSTABLE_CYCLES=1 --assert-level=error
	$(GHDL) --elab-run $(GHDLFLAGS) tb_system_top --assert-level=error

wave: analyze
	$(GHDL) --elab-run $(GHDLFLAGS) tb_system_top --assert-level=error --wave=build/system.ghw
	$(GTKWAVE) build/system.ghw

synth: | build
	$(GHDL) -a $(GHDLFLAGS) $(RTL)
	$(GHDL) --synth $(GHDLFLAGS) --out=verilog system_top > build/system_top.v
	$(YOSYS) -Q -T -l build/yosys.log -p 'read_verilog build/system_top.v; hierarchy -check -top system_top; synth -top system_top; check -assert; stat'

clean:
	rm -rf build
