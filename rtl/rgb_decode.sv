`timescale 1ns/1ps
// =============================================================================
// rgb_decode.sv  -  Bo loc mau & Xuat VGA (RGB444)
// =============================================================================
// Pipeline xu ly mau:
//   1. Tach kenh RGB444 tu BRAM
//   2. Bo loc B&W Threshold (SW2) : luminance > THRESHOLD -> White, else Black
//   3. Bo loc Negative (SW1)      : Dao bit tat ca kenh (~R, ~G, ~B)
//   4. Test Pattern (btnR)        : Ep mau do (12'hF00) khi btnR giu
//   5. Gate active                : Vung blanking -> 0
//
// Parameter:
//   THRESHOLD : Ngưỡng độ sáng cho B&W (default 22, max 45 = 15+15+15)
// =============================================================================
module rgb_decode #(
    parameter int THRESHOLD = 22
) (
    input  logic        active,     // 1 = vung hien thi hop le (in_frame_d2)
    input  logic        test_en,    // 1 = Test Pattern (btnR giu)
    input  logic        neg_en,     // 1 = Negative (SW1)
    input  logic        bw_en,      // 1 = B&W Threshold (SW2)
    input  logic [11:0] din,        // RGB444 tu BRAM
    output logic [3:0]  r,
    output logic [3:0]  g,
    output logic [3:0]  b
);

    // =========================================================================
    // 1. Tach kenh mau goc
    // =========================================================================
    logic [3:0] r_cam, g_cam, b_cam;
    assign r_cam = din[11:8];
    assign g_cam = din[7:4];
    assign b_cam = din[3:0];

    // =========================================================================
    // 2. Lop 1: B&W Threshold (SW2)
    //    Tinh luminance = R + G + B (0..45), so sanh voi THRESHOLD
    // =========================================================================
    logic [5:0] brightness;
    logic       is_white;
    logic [3:0] r_p1, g_p1, b_p1;

    assign brightness = {2'b00, r_cam} + {2'b00, g_cam} + {2'b00, b_cam};
    assign is_white   = (brightness > THRESHOLD);

    assign {r_p1, g_p1, b_p1} = bw_en ? (is_white ? 12'hFFF : 12'h000)
                                       : {r_cam, g_cam, b_cam};

    // =========================================================================
    // 3. Lop 2: Negative (SW1) - Dao bit tren ket qua Lop 1
    // =========================================================================
    logic [3:0] r_p2, g_p2, b_p2;
    assign {r_p2, g_p2, b_p2} = neg_en ? {~r_p1, ~g_p1, ~b_p1}
                                        : {r_p1, g_p1, b_p1};

    // =========================================================================
    // 4. MUX cuoi: Test Pattern > Xu ly anh > Blanking
    // =========================================================================
    always_comb begin
        if (!active) begin
            {r, g, b} = 12'h000;
        end else if (test_en) begin
            {r, g, b} = 12'hF00;  // Mau do test pattern
        end else begin
            {r, g, b} = {r_p2, g_p2, b_p2};
        end
    end

endmodule