# 50 MHz board clock
create_clock -name clk50 -period 20.000 [get_ports MAX10_CLK1_50]

# 25 MHz core clock produced by the toggle flip-flop in de10_lite_top
create_generated_clock -name clk25 -source [get_ports MAX10_CLK1_50] -divide_by 2 [get_registers {clk25}]

derive_clock_uncertainty

# The divider is a toggle flip-flop whose output is also the generated clock; its self-feedback
# path would otherwise be analysed against the clock-network insertion delay of its own output.
set_false_path -from [get_registers {clk25}] -to [get_registers {clk25}]

# Buttons and switches are asynchronous human inputs; LEDs and displays have no timing requirement
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
