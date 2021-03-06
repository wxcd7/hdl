###################################################################################################
###################################################################################################

variable sys_cpu_interconnect_index
variable sys_hp0_interconnect_index
variable sys_hp1_interconnect_index
variable sys_hp2_interconnect_index
variable sys_hp3_interconnect_index
variable sys_mem_interconnect_index

variable xcvr_index
variable xcvr_tx_index
variable xcvr_rx_index
variable xcvr_instance

###################################################################################################
###################################################################################################

set sys_cpu_interconnect_index 0
set sys_hp0_interconnect_index -1
set sys_hp1_interconnect_index -1
set sys_hp2_interconnect_index -1
set sys_hp3_interconnect_index -1
set sys_mem_interconnect_index -1

set xcvr_index -1
set xcvr_tx_index 0
set xcvr_rx_index 0
set xcvr_instance NONE

###################################################################################################
###################################################################################################

proc ad_connect_type {p_name} {

  set m_name ""

  if {$m_name eq ""} {set m_name [get_bd_intf_pins  -quiet $p_name]}
  if {$m_name eq ""} {set m_name [get_bd_pins       -quiet $p_name]}
  if {$m_name eq ""} {set m_name [get_bd_intf_ports -quiet $p_name]}
  if {$m_name eq ""} {set m_name [get_bd_ports      -quiet $p_name]}
  if {$m_name eq ""} {set m_name [get_bd_intf_nets  -quiet $p_name]}
  if {$m_name eq ""} {set m_name [get_bd_nets       -quiet $p_name]}

  return $m_name
}

proc ad_connect {p_name_1 p_name_2} {

  if {($p_name_2 eq "GND") || ($p_name_2 eq "VCC")} {
    set p_size 1
    set p_msb [get_property left [get_bd_pins $p_name_1]]
    set p_lsb [get_property right [get_bd_pins $p_name_1]]
    if {($p_msb ne "") && ($p_lsb ne "")} {
      set p_size [expr (($p_msb + 1) - $p_lsb)]
    }
    set p_cell_name [regsub -all {/} $p_name_1 "_"]
    set p_cell_name "${p_cell_name}_${p_name_2}"
    if {$p_name_2 eq "VCC"} {
      set p_value -1
    } else {
      set p_value 0
    }
    puts "create_bd_cell(xlconstant) size($p_size) value($p_value) name($p_cell_name)"
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $p_cell_name
    set_property CONFIG.CONST_WIDTH $p_size [get_bd_cells $p_cell_name]
    set_property CONFIG.CONST_VAL $p_value [get_bd_cells $p_cell_name]
    puts "connect_bd_net $p_cell_name/dout $p_name_1"
    connect_bd_net [get_bd_pins $p_cell_name/dout] [get_bd_pins $p_name_1]
    return
  }

  set m_name_1 [ad_connect_type $p_name_1]
  set m_name_2 [ad_connect_type $p_name_2]

  if {$m_name_1 eq ""} {
    if {[get_property CLASS $m_name_2] eq "bd_intf_pin"} {
      puts "create_bd_intf_net $p_name_1"
      create_bd_intf_net $p_name_1
    }
    if {[get_property CLASS $m_name_2] eq "bd_pin"} {
      puts "create_bd_net $p_name_1"
      create_bd_net $p_name_1
    }
    set m_name_1 [ad_connect_type $p_name_1]
  }

  if {[get_property CLASS $m_name_1] eq "bd_intf_pin"} {
    puts "connect_bd_intf_net $m_name_1 $m_name_2"
    connect_bd_intf_net $m_name_1 $m_name_2
    return
  }

  if {[get_property CLASS $m_name_1] eq "bd_pin"} {
    puts "connect_bd_net $m_name_1 $m_name_2"
    connect_bd_net $m_name_1 $m_name_2
    return
  }

  if {[get_property CLASS $m_name_1] eq "bd_net"} {
    puts "connect_bd_net -net $m_name_1 $m_name_2"
    connect_bd_net -net $m_name_1 $m_name_2
    return
  }
}

proc ad_disconnect {p_name_1 p_name_2} {

  set m_name_1 [ad_connect_type $p_name_1]
  set m_name_2 [ad_connect_type $p_name_2]

  if {[get_property CLASS $m_name_1] eq "bd_net"} {
    disconnect_bd_net $m_name_1 $m_name_2
    return
  }

}

proc ad_reconct {p_name_1 p_name_2} {

  set m_name_1 [ad_connect_type $p_name_1]
  set m_name_2 [ad_connect_type $p_name_2]

  if {[get_property CLASS $m_name_1] eq "bd_pin"} {
    delete_bd_objs -quiet [get_bd_nets -quiet -of_objects \
      [find_bd_objs -relation connected_to $m_name_1]]
    delete_bd_objs -quiet [get_bd_nets -quiet -of_objects \
      [find_bd_objs -relation connected_to $m_name_2]]
  }

  if {[get_property CLASS $m_name_1] eq "bd_intf_pin"} {
    delete_bd_objs -quiet [get_bd_intf_nets -quiet -of_objects \
      [find_bd_objs -relation connected_to $m_name_1]]
    delete_bd_objs -quiet [get_bd_intf_nets -quiet -of_objects \
      [find_bd_objs -relation connected_to $m_name_2]]
  }

  ad_connect $p_name_1 $p_name_2
}

###################################################################################################
###################################################################################################

proc ad_xcvrcon {u_xcvr a_xcvr a_jesd} {
  
  global xcvr_index
  global xcvr_tx_index
  global xcvr_rx_index
  global xcvr_instance

  set no_of_lanes [get_property CONFIG.NUM_OF_LANES [get_bd_cells $a_xcvr]]
  set qpll_enable [get_property CONFIG.QPLL_ENABLE [get_bd_cells $a_xcvr]]
  set tx_or_rx_n [get_property CONFIG.TX_OR_RX_N [get_bd_cells $a_xcvr]]

  if {$xcvr_instance ne $u_xcvr} {
    set xcvr_index [expr ($xcvr_index + 1)]
    set xcvr_tx_index 0
    set xcvr_rx_index 0
    set xcvr_instance $u_xcvr
  }

  set txrx "rx"
  set data_dir "I"
  set ctrl_dir "O"
  set index $xcvr_rx_index

  if {$tx_or_rx_n == 1} {

    set txrx "tx"
    set data_dir "O"
    set ctrl_dir "I"
    set index $xcvr_tx_index
  }

  set m_sysref ${txrx}_sysref_${index}
  set m_sync ${txrx}_sync_${index}
  set m_data ${txrx}_data

  if {$xcvr_index >= 1} {

    set m_sysref ${txrx}_sysref_${xcvr_index}_${index}
    set m_sync ${txrx}_sync_${xcvr_index}_${index}
    set m_data ${txrx}_data_${xcvr_index}
  }

  create_bd_port -dir I $m_sysref
  create_bd_port -dir ${ctrl_dir} $m_sync
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ${a_jesd}_rstgen

  for {set n 0} {$n < $no_of_lanes} {incr n} {

    set m [expr ($n + $index)]

    if {$tx_or_rx_n == 0} {
      ad_connect  ${a_xcvr}/up_es_${n} ${u_xcvr}/up_es_${m}
      ad_connect  ${a_jesd}/rxencommaalign_out ${u_xcvr}/${txrx}_calign_${m}
    }

    if {(($m%4) == 0) && ($qpll_enable == 1)} {
      ad_connect  ${a_xcvr}/up_cm_${n} ${u_xcvr}/up_cm_${m}
    }

    ad_connect  ${a_xcvr}/up_ch_${n} ${u_xcvr}/up_${txrx}_${m}
    ad_connect  ${u_xcvr}/${txrx}_${m} ${a_jesd}/gt${n}_${txrx}
    ad_connect  ${u_xcvr}/${txrx}_out_clk_${index} ${u_xcvr}/${txrx}_clk_${m}

    create_bd_port -dir ${data_dir} ${m_data}_${m}_p
    create_bd_port -dir ${data_dir} ${m_data}_${m}_n
    ad_connect  ${u_xcvr}/${txrx}_${m}_p ${m_data}_${m}_p
    ad_connect  ${u_xcvr}/${txrx}_${m}_n ${m_data}_${m}_n
  }

  ad_connect  ${a_jesd}/${txrx}_sysref $m_sysref
  ad_connect  ${a_jesd}/${txrx}_sync $m_sync
  ad_connect  ${u_xcvr}/${txrx}_out_clk_${index} ${a_jesd}/${txrx}_core_clk
  ad_connect  ${a_xcvr}/up_status ${a_jesd}/${txrx}_reset_done
  ad_connect  ${u_xcvr}/${txrx}_out_clk_${index} ${a_jesd}_rstgen/slowest_sync_clk
  ad_connect  sys_cpu_resetn ${a_jesd}_rstgen/ext_reset_in
  ad_connect  sys_cpu_reset ${a_jesd}/${txrx}_reset

  if {$tx_or_rx_n == 0} {
    set xcvr_rx_index [expr ($xcvr_rx_index + $no_of_lanes)]
  }

  if {$tx_or_rx_n == 1} {
    set xcvr_tx_index [expr ($xcvr_tx_index + $no_of_lanes)]
  }
}

proc ad_xcvrpll {m_src m_dst} {

  foreach p_dst [get_bd_pins -quiet $m_dst] {
    connect_bd_net [ad_connect_type $m_src] $p_dst
  }
}

###################################################################################################
###################################################################################################

proc ad_mem_hp0_interconnect {p_clk p_name} {

  global sys_zynq

  if {($sys_zynq == 0) && ($p_name eq "sys_ps7/S_AXI_HP0")} {return}
  if {$sys_zynq == 0} {ad_mem_hpx_interconnect "MEM" $p_clk $p_name}
  if {$sys_zynq >= 1} {ad_mem_hpx_interconnect "HP0" $p_clk $p_name}
}

proc ad_mem_hp1_interconnect {p_clk p_name} {

  global sys_zynq

  if {($sys_zynq == 0) && ($p_name eq "sys_ps7/S_AXI_HP1")} {return}
  if {$sys_zynq == 0} {ad_mem_hpx_interconnect "MEM" $p_clk $p_name}
  if {$sys_zynq >= 1} {ad_mem_hpx_interconnect "HP1" $p_clk $p_name}
}

proc ad_mem_hp2_interconnect {p_clk p_name} {

  global sys_zynq

  if {($sys_zynq == 0) && ($p_name eq "sys_ps7/S_AXI_HP2")} {return}
  if {$sys_zynq == 0} {ad_mem_hpx_interconnect "MEM" $p_clk $p_name}
  if {$sys_zynq >= 1} {ad_mem_hpx_interconnect "HP2" $p_clk $p_name}
}

proc ad_mem_hp3_interconnect {p_clk p_name} {

  global sys_zynq

  if {($sys_zynq == 0) && ($p_name eq "sys_ps7/S_AXI_HP3")} {return}
  if {$sys_zynq == 0} {ad_mem_hpx_interconnect "MEM" $p_clk $p_name}
  if {$sys_zynq >= 1} {ad_mem_hpx_interconnect "HP3" $p_clk $p_name}
}

###################################################################################################
###################################################################################################

proc ad_mem_hpx_interconnect {p_sel p_clk p_name} {

  global sys_zynq
  global sys_ddr_addr_seg
  global sys_hp0_interconnect_index
  global sys_hp1_interconnect_index
  global sys_hp2_interconnect_index
  global sys_hp3_interconnect_index
  global sys_mem_interconnect_index

  set p_name_int $p_name
  set p_clk_source [get_bd_pins -filter {DIR == O} -of_objects [get_bd_nets $p_clk]]

  if {$p_sel eq "MEM"} {
    if {$sys_mem_interconnect_index < 0} {
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_interconnect
    }
    set m_interconnect_index $sys_mem_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_mem_interconnect]
    set m_addr_seg [get_bd_addr_segs -of_objects [get_bd_cells axi_ddr_cntrl]]
  }

  if {($p_sel eq "HP0") && ($sys_zynq == 1)} {
    if {$sys_hp0_interconnect_index < 0} {
      set p_name_int sys_ps7/S_AXI_HP0
      set_property CONFIG.PCW_USE_S_AXI_HP0 {1} [get_bd_cells sys_ps7]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp0_interconnect
    }
    set m_interconnect_index $sys_hp0_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp0_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps7/S_AXI_HP0/HP0_DDR_LOWOCM]
  }

  if {($p_sel eq "HP1") && ($sys_zynq == 1)} {
    if {$sys_hp1_interconnect_index < 0} {
      set p_name_int sys_ps7/S_AXI_HP1
      set_property CONFIG.PCW_USE_S_AXI_HP1 {1} [get_bd_cells sys_ps7]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp1_interconnect
    }
    set m_interconnect_index $sys_hp1_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp1_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps7/S_AXI_HP1/HP1_DDR_LOWOCM]
  }

  if {($p_sel eq "HP2") && ($sys_zynq == 1)} {
    if {$sys_hp2_interconnect_index < 0} {
      set p_name_int sys_ps7/S_AXI_HP2
      set_property CONFIG.PCW_USE_S_AXI_HP2 {1} [get_bd_cells sys_ps7]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp2_interconnect
    }
    set m_interconnect_index $sys_hp2_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp2_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps7/S_AXI_HP2/HP2_DDR_LOWOCM]
  }

  if {($p_sel eq "HP3") && ($sys_zynq == 1)} {
    if {$sys_hp3_interconnect_index < 0} {
      set p_name_int sys_ps7/S_AXI_HP3
      set_property CONFIG.PCW_USE_S_AXI_HP3 {1} [get_bd_cells sys_ps7]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp3_interconnect
    }
    set m_interconnect_index $sys_hp3_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp3_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps7/S_AXI_HP3/HP3_DDR_LOWOCM]
  }

  if {($p_sel eq "HP0") && ($sys_zynq == 2)} {
    if {$sys_hp0_interconnect_index < 0} {
      set p_name_int sys_ps8/S_AXI_HP0_FPD
      set_property CONFIG.PSU__USE__S_AXI_GP2 {1} [get_bd_cells sys_ps8]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp0_interconnect
    }
    set m_interconnect_index $sys_hp0_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp0_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps8/S_AXI_HP0_FPD/PLLPD_DDR_LOW]
  }

  if {($p_sel eq "HP1") && ($sys_zynq == 2)} {
    if {$sys_hp1_interconnect_index < 0} {
      set p_name_int sys_ps8/S_AXI_HP1_FPD
      set_property CONFIG.PSU__USE__S_AXI_GP3 {1} [get_bd_cells sys_ps8]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp1_interconnect
    }
    set m_interconnect_index $sys_hp1_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp1_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps8/S_AXI_HP1_FPD/HP0_DDR_LOW]
  }

  if {($p_sel eq "HP2") && ($sys_zynq == 2)} {
    if {$sys_hp2_interconnect_index < 0} {
      set p_name_int sys_ps8/S_AXI_HP2_FPD
      set_property CONFIG.PSU__USE__S_AXI_GP4 {1} [get_bd_cells sys_ps8]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp2_interconnect
    }
    set m_interconnect_index $sys_hp2_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp2_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps8/S_AXI_HP2_FPD/HP1_DDR_LOW]
  }

  if {($p_sel eq "HP3") && ($sys_zynq == 2)} {
    if {$sys_hp3_interconnect_index < 0} {
      set p_name_int sys_ps8/S_AXI_HP3_FPD
      set_property CONFIG.PSU__USE__S_AXI_GP5 {1} [get_bd_cells sys_ps8]
      create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp3_interconnect
    }
    set m_interconnect_index $sys_hp3_interconnect_index
    set m_interconnect_cell [get_bd_cells axi_hp3_interconnect]
    set m_addr_seg [get_bd_addr_segs sys_ps8/S_AXI_HP3_FPD/HP2_DDR_LOW]
  }

  set i_str "S$m_interconnect_index"
  if {$m_interconnect_index < 10} {
    set i_str "S0$m_interconnect_index"
  }

  set m_interconnect_index [expr $m_interconnect_index + 1]

  set p_intf_name [lrange [split $p_name_int "/"] end end]
  set p_cell_name [lrange [split $p_name_int "/"] 0 0]
  set p_intf_clock [get_bd_pins -filter "TYPE == clk && (CONFIG.ASSOCIATED_BUSIF == ${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ ${p_intf_name}:* || CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name}:*)" -quiet -of_objects [get_bd_cells $p_cell_name]]
  if {[find_bd_objs -quiet -relation connected_to $p_intf_clock] ne "" ||
      $p_intf_clock eq $p_clk_source} {
    set p_intf_clock ""
  }

  regsub clk $p_clk resetn p_rst
  if {[get_bd_nets -quiet $p_rst] eq ""} {
    set p_rst sys_cpu_resetn
  }

  if {$m_interconnect_index == 0} {
    set_property CONFIG.NUM_MI 1 $m_interconnect_cell
    set_property CONFIG.NUM_SI 1 $m_interconnect_cell
    ad_connect $p_rst $m_interconnect_cell/ARESETN
    ad_connect $p_clk $m_interconnect_cell/ACLK
    ad_connect $p_rst $m_interconnect_cell/M00_ARESETN
    ad_connect $p_clk $m_interconnect_cell/M00_ACLK
    ad_connect $m_interconnect_cell/M00_AXI $p_name_int
    if {$p_intf_clock ne ""} {
      ad_connect $p_clk $p_intf_clock
    }
  } else {
    set_property CONFIG.NUM_SI $m_interconnect_index $m_interconnect_cell
    ad_connect $p_rst $m_interconnect_cell/${i_str}_ARESETN
    ad_connect $p_clk $m_interconnect_cell/${i_str}_ACLK
    ad_connect $m_interconnect_cell/${i_str}_AXI $p_name_int
    if {$p_intf_clock ne ""} {
      ad_connect $p_clk $p_intf_clock
    }
    assign_bd_address $m_addr_seg
  }

  if {$m_interconnect_index > 1} {
    set_property CONFIG.STRATEGY {2} $m_interconnect_cell
  }

  if {$p_sel eq "MEM"} {set sys_mem_interconnect_index $m_interconnect_index}
  if {$p_sel eq "HP0"} {set sys_hp0_interconnect_index $m_interconnect_index}
  if {$p_sel eq "HP1"} {set sys_hp1_interconnect_index $m_interconnect_index}
  if {$p_sel eq "HP2"} {set sys_hp2_interconnect_index $m_interconnect_index}
  if {$p_sel eq "HP3"} {set sys_hp3_interconnect_index $m_interconnect_index}

}

###################################################################################################
###################################################################################################

proc ad_cpu_interconnect {p_address p_name} {

  global sys_zynq
  global sys_cpu_interconnect_index

  set i_str "M$sys_cpu_interconnect_index"
  if {$sys_cpu_interconnect_index < 10} {
    set i_str "M0$sys_cpu_interconnect_index"
  }

  if {$sys_cpu_interconnect_index == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_cpu_interconnect
    if {$sys_zynq == 2} {
      ad_connect sys_cpu_clk sys_ps8/maxihpm0_lpd_aclk
      ad_connect sys_cpu_clk axi_cpu_interconnect/ACLK
      ad_connect sys_cpu_clk axi_cpu_interconnect/S00_ACLK
      ad_connect sys_cpu_resetn axi_cpu_interconnect/ARESETN
      ad_connect sys_cpu_resetn axi_cpu_interconnect/S00_ARESETN
      ad_connect axi_cpu_interconnect/S00_AXI sys_ps8/M_AXI_HPM0_LPD
    }
    if {$sys_zynq == 1} {
      ad_connect sys_cpu_clk sys_ps7/M_AXI_GP0_ACLK
      ad_connect sys_cpu_clk axi_cpu_interconnect/ACLK
      ad_connect sys_cpu_clk axi_cpu_interconnect/S00_ACLK
      ad_connect sys_cpu_resetn axi_cpu_interconnect/ARESETN
      ad_connect sys_cpu_resetn axi_cpu_interconnect/S00_ARESETN
      ad_connect axi_cpu_interconnect/S00_AXI sys_ps7/M_AXI_GP0
    }
    if {$sys_zynq == 0} {
      ad_connect sys_cpu_clk axi_cpu_interconnect/ACLK
      ad_connect sys_cpu_clk axi_cpu_interconnect/S00_ACLK
      ad_connect sys_cpu_resetn axi_cpu_interconnect/ARESETN
      ad_connect sys_cpu_resetn axi_cpu_interconnect/S00_ARESETN
      ad_connect axi_cpu_interconnect/S00_AXI sys_mb/M_AXI_DP
    }
  }

  if {$sys_zynq == 2} {
    set sys_addr_cntrl_space [get_bd_addr_spaces sys_ps8/Data]
  }
  if {$sys_zynq == 1} {
    set sys_addr_cntrl_space [get_bd_addr_spaces sys_ps7/Data]
  }
  if {$sys_zynq == 0} {
    set sys_addr_cntrl_space [get_bd_addr_spaces sys_mb/Data]
  }

  set sys_cpu_interconnect_index [expr $sys_cpu_interconnect_index + 1]
  set p_intf [get_bd_intf_pins -filter "MODE == Slave && VLNV == xilinx.com:interface:aximm_rtl:1.0"\
    -of_objects [get_bd_cells $p_name]]
  set p_intf_name [lrange [split $p_intf "/"] end end]
  set p_intf_clock [get_bd_pins -filter "TYPE == clk && (CONFIG.ASSOCIATED_BUSIF == ${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ ${p_intf_name}:* || CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name}:*)" -quiet -of_objects [get_bd_cells $p_name]]
  set p_intf_reset [get_bd_pins -filter "TYPE == rst && (CONFIG.ASSOCIATED_BUSIF == ${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ ${p_intf_name}:* || CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name} || \
    CONFIG.ASSOCIATED_BUSIF =~ *:${p_intf_name}:*)" -quiet -of_objects [get_bd_cells $p_name]]
  if {($p_intf_clock ne "") && ($p_intf_reset eq "")} {
    set p_intf_reset [get_property CONFIG.ASSOCIATED_RESET [get_bd_pins ${p_intf_clock}]]
    if {$p_intf_reset ne ""} {
      set p_intf_reset [get_bd_pins $p_name/$p_intf_reset]
    }
  }
  if {[find_bd_objs -quiet -relation connected_to $p_intf_clock] ne ""} {
    set p_intf_clock ""
  }
  if {$p_intf_reset ne ""} {
    if {[find_bd_objs -quiet -relation connected_to $p_intf_reset] ne ""} {
      set p_intf_reset ""
    }
  }

  set_property CONFIG.NUM_MI $sys_cpu_interconnect_index [get_bd_cells axi_cpu_interconnect]

  ad_connect sys_cpu_clk axi_cpu_interconnect/${i_str}_ACLK
  if {$p_intf_clock ne ""} {
    ad_connect sys_cpu_clk ${p_intf_clock}
  }
  ad_connect sys_cpu_resetn axi_cpu_interconnect/${i_str}_ARESETN
  if {$p_intf_reset ne ""} {
    ad_connect sys_cpu_resetn ${p_intf_reset}
  }
  ad_connect axi_cpu_interconnect/${i_str}_AXI ${p_intf}

  set p_seg [get_bd_addr_segs -of_objects [get_bd_cells $p_name]]
  set p_index 0
  foreach p_seg_name $p_seg {
    if {$p_index == 0} {
      set p_seg_range [get_property range $p_seg_name]
      if {$p_seg_range < 0x1000} {
        set p_seg_range 0x1000
      }
      if {$sys_zynq == 2} {
        if {($p_address >= 0x40000000) && ($p_address <= 0x4fffffff)} {
          set p_address [expr ($p_address + 0x40000000)]
        }
        if {($p_address >= 0x70000000) && ($p_address <= 0x7fffffff)} {
          set p_address [expr ($p_address + 0x20000000)]
        }
      }
      create_bd_addr_seg -range $p_seg_range \
        -offset $p_address $sys_addr_cntrl_space \
        $p_seg_name "SEG_data_${p_name}"
    } else {
      assign_bd_address $p_seg_name
    }
    incr p_index
  }
}

###################################################################################################
###################################################################################################

proc ad_cpu_interrupt {p_ps_index p_mb_index p_name} {

  global sys_zynq

  if {$sys_zynq == 0} {set p_index_int $p_mb_index}
  if {$sys_zynq >= 1} {set p_index_int $p_ps_index}

  set p_index [regsub -all {[^0-9]} $p_index_int ""]
  set m_index [expr ($p_index - 8)]

  if {($sys_zynq == 2) && ($p_index <= 7)} {
    set p_net [get_bd_nets -of_objects [get_bd_pins sys_concat_intc_0/In$p_index]]
    set p_pin [find_bd_objs -relation connected_to [get_bd_pins sys_concat_intc_0/In$p_index]]

    puts "delete_bd_objs $p_net $p_pin"
    delete_bd_objs $p_net $p_pin
    ad_connect sys_concat_intc_0/In$p_index $p_name
  }

  if {($sys_zynq == 2) && ($p_index >= 8)} {
    set p_net [get_bd_nets -of_objects [get_bd_pins sys_concat_intc_1/In$m_index]]
    set p_pin [find_bd_objs -relation connected_to [get_bd_pins sys_concat_intc_1/In$m_index]]

    puts "delete_bd_objs $p_net $p_pin"
    delete_bd_objs $p_net $p_pin
    ad_connect sys_concat_intc_1/In$m_index $p_name
  }

  if {$sys_zynq <= 1} {

    set p_net [get_bd_nets -of_objects [get_bd_pins sys_concat_intc/In$p_index]]
    set p_pin [find_bd_objs -relation connected_to [get_bd_pins sys_concat_intc/In$p_index]]

    puts "delete_bd_objs $p_net $p_pin"
    delete_bd_objs $p_net $p_pin
    ad_connect sys_concat_intc/In$p_index $p_name
  }
}

###################################################################################################
###################################################################################################

