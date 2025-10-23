# RTL Synthesis Script for LyteSICS Scrypt Mining ASIC
# Compatible with MinerSICS architecture
# Process node agnostic design

# Set design name
set design_name "lyte_miner_top"

# Set target process (configurable)
set target_process "generic"

# Create project
create_project $design_name ./build -process $target_process -force

# Add RTL source files
add_files -norecurse {
    ../rtl/sha256_core.sv
    ../rtl/hmac_sha256.sv
    ../rtl/pbkdf2_sha256.sv
    ../rtl/romix_memory.sv
    ../rtl/lyte_miner_core.sv
    ../rtl/lyte_miner_top.sv
}

# Add constraint files
add_files -fileset constrs_1 -norecurse {
    ../constraints/timing.sdc
}

# Set top module
set_property top $design_name [current_fileset]

# Set synthesis options for Scrypt mining
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {
    -mode out_of_context 
    -retiming 
    -power 
    -resource_sharing 
    -memory_optimization
    -clock_gating
    -voltage_scaling
} -objects [get_runs synth_1]

# Set implementation options
set_property -name {STEPS.OPT_DESIGN.ARGS.MORE OPTIONS} -value {
    -retarget 
    -power 
    -area
    -memory_optimization
} -objects [get_runs impl_1]

set_property -name {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} -value {
    -directive Explore 
    -power
    -memory_optimization
} -objects [get_runs impl_1]

set_property -name {STEPS.ROUTE_DESIGN.ARGS.MORE OPTIONS} -value {
    -directive Explore 
    -power
    -memory_optimization
} -objects [get_runs impl_1]

# Set Scrypt-specific optimizations
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {
    -retiming 
    -power 
    -resource_sharing 
    -memory_optimization
    -clock_gating
    -voltage_scaling
    -area_optimization
} -objects [get_runs synth_1]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

# Run implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation results
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

# Generate reports
report_utilization -file ./build/utilization_report.txt
report_timing -file ./build/timing_report.txt
report_power -file ./build/power_report.txt
report_area -file ./build/area_report.txt

# Generate netlist
write_verilog -mode funcsim ./build/${design_name}_netlist.v

# Generate constraints
write_sdc ./build/${design_name}_constraints.sdc

# Generate GDSII for tapeout
write_gds -file ./build/${design_name}.gds

puts "RTL Synthesis completed successfully!"
puts "Netlist: ./build/${design_name}_netlist.v"
puts "GDSII: ./build/${design_name}.gds"
puts "Reports: ./build/*_report.txt"
