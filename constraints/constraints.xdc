## Clock (single domain)
create_clock -name clk -period 12.5 [get_ports clk]

## Bring-up I/O constraints (0 ns budget)
# Exclude clk and async resets from input-delay list
set in_ports  [get_ports -quiet -filter {DIRECTION == IN  && NAME !~ "clk" && NAME !~ "rst.*" && NAME !~ "reset.*"}]
set out_ports [get_ports -quiet -filter {DIRECTION == OUT}]

#set_input_delay  0 -clock [get_clocks clk] $in_ports
#set_output_delay 0 -clock [get_clocks clk] $out_ports

## Async resets: declare as false paths (assert/deassert not timed)
#set rst_ports [get_ports -quiet -filter {DIRECTION == IN && (NAME =~ "rst.*" || NAME =~ "reset.*")}]
#if {[llength $rst_ports] > 0} {
#  set_false_path -from $rst_ports -to [all_registers]
#}
