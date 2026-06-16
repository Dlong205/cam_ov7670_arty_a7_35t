## Clock 100 MHz
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk]

## PCLK tu camera OV7670
set_property -dict { PACKAGE_PIN E15 IOSTANDARD LVCMOS33 } [get_ports ov_pclk]
create_clock -add -name ov_pclk_pin -period 40.000 -waveform {0 20} [get_ports ov_pclk]
set_clock_groups -asynchronous -group [get_clocks sys_clk_pin] -group [get_clocks ov_pclk_pin]

## Nut nhan (btnC, btnR)
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports btnC]
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports btnR]

## Cong tac (sw)
set_property -dict { PACKAGE_PIN A8 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]

## LED
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## VGA (PMOD JC & JD) - B?t SLEW FAST de chong nhi?u mau
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_r[0]}]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_r[1]}]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_r[2]}]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_r[3]}]

set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_g[0]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_g[1]}]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_g[2]}]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_g[3]}]

set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_b[0]}]
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_b[1]}]
set_property -dict { PACKAGE_PIN F4 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_b[2]}]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {vga_b[3]}]

set_property -dict { PACKAGE_PIN E2 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports vga_hs]
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports vga_vs]

## CAMERA DATA (PMOD JA)
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[0]}]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[1]}]
set_property -dict { PACKAGE_PIN A11 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[2]}]
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[3]}]
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[4]}]
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[5]}]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[6]}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {ov_d[7]}]

## CAMERA CONTROL (PMOD JB)
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports ov_href]
set_property -dict { PACKAGE_PIN D15 IOSTANDARD LVCMOS33 } [get_ports ov_vsync]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports ov_reset_n]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports ov_xclk]
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports ov_pwdn]

## BAT PULLUP CHO I2C DE CAMERA NHAN DIEN VA KHONG BI TREO
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports ov_sioc]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports ov_siod]

## Bo qua loi dinh tuyen Clock cua Vivado
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets ov_pclk_IBUF]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]