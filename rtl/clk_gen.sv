`timescale 1ns/1ps
// =============================================================================
// clk_gen.sv  -  Clock generator 100 MHz â†’ 25 MHz cho Arty A7-35T
// =============================================================================
// Dung MMCME2_BASE primitive cua Artix-7 (khong can Clocking Wizard IP).
// Vivado nhan truc tiep file nay ma khong can generate IP.
//
// Tinh toan PLL:
//   Input  : 100 MHz  (period = 10 ns)
//   VCO    : 100 MHz x CLKFBOUT_MULT_F=10 = 1000 MHz
//             (nam trong range 600-1200 MHz cua Artix-7 MMCM)
//   Output : 1000 MHz / CLKOUT0_DIVIDE_F=40 = 25 MHz  âœ“
//
// Port:
//   clk_100  : input  clock 100 MHz tu oscillator tren board
//   rst_n    : input  reset (active-low); top.sv noi vao 1'b1
//   clk_25   : output clock 25 MHz cho VGA + toan bo logic
//   locked   : output HIGH khi PLL da lock (dung lam rst_n toan he thong)
//
// Luu y:
//   - BUFG duoc them vao output clk_25 de drive global clock network.
//   - locked tu MMCM la synchronous reset source an toan nhat.
//   - rst_n cua MMCM la active-HIGH (RESETIN), nen khi top.sv truyen 1'b1
//     thi MMCM khong bi reset â€” dung y do.
// =============================================================================
module clk_gen (
    input  logic clk_100,   // 100 MHz oscillator (chan E3 tren Arty A7)
    input  logic rst_n,     // active-low reset (top.sv noi 1'b1 = khong reset)
    output logic clk_25,    // 25 MHz ra
    output logic locked     // HIGH khi MMCM da lock
);

    // =========================================================================
    // Day noi noi bo
    // =========================================================================
    logic clk_25_unbuf;     // clk_25 truoc BUFG
    logic clkfb_out;        // feedback tu MMCM ra
    logic clkfb_in;         // feedback vao MMCM (qua BUFG)
    logic mmcm_reset;       // MMCM reset (active-HIGH)

    // rst_n la active-low, MMCM reset la active-HIGH
    assign mmcm_reset = ~rst_n;

    // =========================================================================
    // MMCME2_BASE: PLL chinh
    // =========================================================================
    MMCME2_BASE #(
        // --- Input clock ---
        .CLKIN1_PERIOD      (10.0),     // 100 MHz = 10 ns

        // --- VCO: 100 MHz x 10 = 1000 MHz ---
        .CLKFBOUT_MULT_F    (10.0),     // VCO multiplier
        .CLKFBOUT_PHASE     (0.0),

        // --- Output 0: 1000 MHz / 40 = 25 MHz ---
        .CLKOUT0_DIVIDE_F   (40.0),
        .CLKOUT0_PHASE      (0.0),
        .CLKOUT0_DUTY_CYCLE (0.5),

        // --- Cac output khac: disable ---
        .CLKOUT1_DIVIDE     (1),
        .CLKOUT2_DIVIDE     (1),
        .CLKOUT3_DIVIDE     (1),
        .CLKOUT4_DIVIDE     (1),
        .CLKOUT5_DIVIDE     (1),

        // --- Divider input ---
        .DIVCLK_DIVIDE      (1),        // khong chia input

        // --- Bandwidth ---
        .BANDWIDTH          ("OPTIMIZED"),

        // --- Startup wait ---
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        // Inputs
        .CLKIN1     (clk_100),
        .CLKFBIN    (clkfb_in),
        .RST        (mmcm_reset),
        .PWRDWN     (1'b0),

        // Outputs
        .CLKOUT0    (clk_25_unbuf),
        .CLKOUT0B   (),
        .CLKOUT1    (),
        .CLKOUT1B   (),
        .CLKOUT2    (),
        .CLKOUT2B   (),
        .CLKOUT3    (),
        .CLKOUT3B   (),
        .CLKOUT4    (),
        .CLKOUT5    (),
        .CLKOUT6    (),
        .CLKFBOUT   (clkfb_out),
        .CLKFBOUTB  (),
        .LOCKED     (locked)
    );

    // =========================================================================
    // BUFG cho feedback va output
    // =========================================================================
    // Feedback BUFG: bat buoc de MMCM hoat dong chinh xac
    BUFG u_bufg_fb (
        .I (clkfb_out),
        .O (clkfb_in)
    );

    // Output BUFG: drive global clock network
    BUFG u_bufg_clk25 (
        .I (clk_25_unbuf),
        .O (clk_25)
    );

endmodule