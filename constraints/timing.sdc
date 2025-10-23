# Timing Constraints for LyteSICS Scrypt Mining ASIC
# Process node agnostic design
# Target frequency will be determined by synthesis

# Clock constraints
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty -setup 0.5 [get_clock clk]
set_clock_uncertainty -hold 0.25 [get_clock clk]

# Clock tree synthesis
set_clock_tree_options -target_skew 0.2 -max_transition 1.0

# Input delay constraints (process agnostic)
set_input_delay -clock clk -max 2.0 [get_ports start_mining]
set_input_delay -clock clk -max 2.0 [get_ports stop_mining]
set_input_delay -clock clk -max 2.0 [get_ports reset_miner]
set_input_delay -clock clk -max 2.0 [get_ports core_count]
set_input_delay -clock clk -max 2.0 [get_ports n_param]
set_input_delay -clock clk -max 2.0 [get_ports r_param]
set_input_delay -clock clk -max 2.0 [get_ports p_param]
set_input_delay -clock clk -max 2.0 [get_ports difficulty_target]
set_input_delay -clock clk -max 2.0 [get_ports block_version]
set_input_delay -clock clk -max 2.0 [get_ports prev_block_hash]
set_input_delay -clock clk -max 2.0 [get_ports merkle_root]
set_input_delay -clock clk -max 2.0 [get_ports block_timestamp]
set_input_delay -clock clk -max 2.0 [get_ports block_bits]

# Output delay constraints
set_output_delay -clock clk -max 1.0 [get_ports solution_nonce]
set_output_delay -clock clk -max 1.0 [get_ports solution_hash]
set_output_delay -clock clk -max 1.0 [get_ports solution_found]
set_output_delay -clock clk -max 1.0 [get_ports mining_active]
set_output_delay -clock clk -max 1.0 [get_ports miner_ready]
set_output_delay -clock clk -max 1.0 [get_ports error]
set_output_delay -clock clk -max 1.0 [get_ports hash_rate]
set_output_delay -clock clk -max 1.0 [get_ports active_cores]
set_output_delay -clock clk -max 1.0 [get_ports total_hashes]

# False paths
set_false_path -from [get_ports rst_n] -to [all_registers]
set_false_path -from [get_ports start_mining] -to [get_ports stop_mining]

# Scrypt-specific timing constraints for ASIC
# ROMix memory operations require multiple cycles
set_multicycle_path -setup 4 -from [get_cells *romix*] -to [get_cells *romix*]
set_multicycle_path -hold 1 -from [get_cells *romix*] -to [get_cells *romix*]

# PBKDF2 iterations
set_multicycle_path -setup 2 -from [get_cells *pbkdf2*] -to [get_cells *pbkdf2*]
set_multicycle_path -hold 1 -from [get_cells *pbkdf2*] -to [get_cells *pbkdf2*]

# High-speed memory access for Scrypt
set_multicycle_path -setup 2 -from [get_cells *memory*] -to [get_cells *memory*]
set_multicycle_path -hold 1 -from [get_cells *memory*] -to [get_cells *memory*]

# Critical path constraints for mining
set_max_delay -from [get_ports clk] -to [get_ports solution_found] 0.8
set_max_delay -from [get_ports clk] -to [get_ports hash_rate] 0.8

# Power constraints (process agnostic)
set_max_dynamic_power 100.0  # 100W max dynamic power
set_max_leakage_power 10.0   # 10W max leakage power

# Area constraints (process agnostic)
set_max_area 100000000  # 100mm² target die size

# Voltage domains (process agnostic)
create_voltage_domain -name VDD_CORE -voltage 1.2
create_voltage_domain -name VDD_IO -voltage 3.3
create_voltage_domain -name VDD_MEM -voltage 1.8

# Clock gating constraints
set_clock_gating_style -sequential_cell latch -positive_edge_logic {integrated}
set_clock_gating_style -sequential_cell latch -negative_edge_logic {integrated}

# Timing exceptions
set_case_analysis 0 [get_ports rst_n]
set_case_analysis 1 [get_ports clk]

# Design rule constraints
set_max_fanout 100 [all_inputs]
set_max_transition 0.5 [all_outputs]
set_max_capacitance 0.5 [all_outputs]

# Wire load model
set_wire_load_mode top
set_wire_load_model -name "10x10" -library work

# Operating conditions
set_operating_conditions -library work -min "slow_125_1.62" -max "fast_0_1.98"
