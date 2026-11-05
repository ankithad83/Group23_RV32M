# create_vivado_project.tcl -- builds the Vivado project in one step.
#   Vivado GUI:  Tools > Run Tcl Script...  (or in the Tcl Console: source <path>/create_vivado_project.tcl)
#   Batch:       vivado -mode batch -source scripts/create_vivado_project.tcl
# Set PART for your board: Nexys A7-100T = xc7a100tcsg324-1, Nexys A7-50T = xc7a50tcsg324-1
set PART xc7a100tcsg324-1

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]
create_project rv32m_group23 [file join $root vivado_proj] -part $PART -force

add_files -fileset sources_1 [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [file join $root constraints nexys_a7.xdc]
add_files -fileset sim_1     [list [file join $root tb tb_soc.v] [file join $root tb tb_pipeline.v]]

set_property top top_nexys_a7 [get_filesets sources_1]
set_property top tb_soc       [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
puts "Project created. Simulation top = tb_soc (change to tb_pipeline in Sources > Simulation Sources)."
