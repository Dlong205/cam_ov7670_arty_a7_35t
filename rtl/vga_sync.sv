`timescale 1ns/1ps
// =============================================================================
// vga_sync.sv  -  VGA 640x480 @ 60 Hz sync generator
// =============================================================================
// Clock: 25.175 MHz (dung 25 MHz van ok voi phan lon man hinh)
//
// Horizontal timing (don vi: pixel = 1 clock)
//   Sync  : 96  | Back porch : 48  | Active : 640 | Front porch : 16
//   Total : 800 pixels/line
//
// Vertical timing (don vi: line)
//   Sync  : 2   | Back porch : 33  | Active : 480 | Front porch : 10
//   Total : 525 lines/frame
//
// Ca hai sync deu ACTIVE LOW.
// =============================================================================
module vga_sync (
    input  logic        clk_25,
    input  logic        rst_n,
    // VGA outputs
    output logic        h_sync,     // active-low
    output logic        v_sync,     // active-low
    output logic        active,     // HIGH trong vung hien thi
    output logic [9:0]  pixel_x,   // 0-639 khi active, else 0
    output logic [9:0]  pixel_y    // 0-479 khi active, else 0
);

    // =========================================================================
    // Timing parameters
    // =========================================================================
    // Horizontal
    localparam H_SYNC_END  = 10'd96;   // ket thuc xung sync
    localparam H_BP_END    = 10'd144;  // 96 + 48  (het back porch)
    localparam H_ACT_END   = 10'd784;  // 144 + 640 (het vung active)
    localparam H_TOTAL     = 10'd800;

    // Vertical
    localparam V_SYNC_END  = 10'd2;
    localparam V_BP_END    = 10'd35;   // 2 + 33
    localparam V_ACT_END   = 10'd515;  // 35 + 480
    localparam V_TOTAL     = 10'd525;

    // =========================================================================
    // Counters
    // =========================================================================
    logic [9:0] h_cnt;
    logic [9:0] v_cnt;

    // --- Horizontal counter ---------------------------------------------------
    always_ff @(posedge clk_25 or negedge rst_n) begin
        if (!rst_n)
            h_cnt <= 10'd0;
        else if (h_cnt == H_TOTAL - 1)
            h_cnt <= 10'd0;
        else
            h_cnt <= h_cnt + 10'd1;
    end

    // --- Vertical counter (tang moi cuoi 1 dong ngang) -----------------------
    always_ff @(posedge clk_25 or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= 10'd0;
        end else if (h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 10'd1;
        end
    end

    // =========================================================================
    // Output
    // =========================================================================
    // Sync: thap (active) khi o trong vung sync pulse
    assign h_sync  = (h_cnt >= H_SYNC_END);   // low khi h_cnt < 96
    assign v_sync  = (v_cnt >= V_SYNC_END);   // low khi v_cnt < 2

    // Active: chi cao khi ca h va v dang trong vung hien thi
    assign active  = (h_cnt >= H_BP_END) && (h_cnt < H_ACT_END) &&
                     (v_cnt >= V_BP_END) && (v_cnt < V_ACT_END);

    // Toa do pixel (tinh tu goc tren-trai cua vung active)
    assign pixel_x = active ? (h_cnt - H_BP_END) : 10'd0;
    assign pixel_y = active ? (v_cnt - V_BP_END)  : 10'd0;

endmodule