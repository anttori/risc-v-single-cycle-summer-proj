# Constrain main clock to 50 MHz (period 20.0 ns)
create_clock -name clk -period 20.000 [get_ports clk]
derive_clock_uncertainty