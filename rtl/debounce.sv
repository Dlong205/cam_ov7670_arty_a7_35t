`timescale 1ns/1ps
// =============================================================================
// debounce.sv  -  Chong rung nut nhan (Button Debounce)
// =============================================================================
// Nut nhan co hien tuong "rung" (bounce) khi an/tha: tin hieu dao dong
// lien tuc trong ~5-20 ms truoc khi on dinh. Neu dung thang vao FSM
// se bi dem sai so lan nhan.
//
// Giai phap: chi cong nhan trang thai moi khi tin hieu GIU NGUYEN lien tuc
// trong DEB_TIME chu ky. Neu tin hieu thay doi giua chung, reset bo dem.
//
// Pipeline gom 2 tang:
//   Tang 1: 2 FF dong bo hoa (tranh metastability tu ngoai vao)
//   Tang 2: Counter dem thoi gian on dinh
//
// Tham so:
//   DEB_TIME = 1_250_000  =>  1_250_000 / 25 MHz = 50 ms  (du cho moi nut)
//   Co the giam trong testbench de sim nhanh hon.
//
// Output:
//   btn_out  : muc on dinh (0/1), cap nhat sau DEB_TIME chu ky on dinh
//   btn_rise : pulse 1 chu ky khi co canh len (0->1)
//   btn_fall : pulse 1 chu ky khi co canh xuong (1->0)
//
// Su dung trong top.sv:
//   debounce u_db_resend (.btn_in(btnC), .btn_rise(resend), ...);
//   debounce u_db_res    (.btn_in(btnR), .btn_rise(res_inc), ...);
// =============================================================================
module debounce #(
    parameter int DEB_TIME = 1_250_000      // 50 ms @ 25 MHz
) (
    input  logic clk,
    input  logic rst_n,
    input  logic btn_in,        // tin hieu nut nhan tu pin (co nhieu)
    output logic btn_out,       // trang thai on dinh
    output logic btn_rise,      // pulse 1 clk: canh len
    output logic btn_fall       // pulse 1 clk: canh xuong
);

    // =========================================================================
    // Tang 1: 2-FF synchronizer (chong metastability)
    // =========================================================================
    logic btn_s1, btn_s2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_s1 <= 1'b0;
            btn_s2 <= 1'b0;
        end else begin
            btn_s1 <= btn_in;   // FF thu nhat
            btn_s2 <= btn_s1;   // FF thu hai (da dong bo)
        end
    end

    // =========================================================================
    // Tang 2: Counter dem thoi gian on dinh
    // =========================================================================
    // So bit can thiet cho counter: $clog2(DEB_TIME)
    localparam int CNT_W = $clog2(DEB_TIME);

    logic [CNT_W-1:0] cnt;
    logic             btn_stable;   // trang thai on dinh hien tai

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt        <= '0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_s2 == btn_stable) begin
                // Tin hieu trung voi trang thai on dinh hien tai => reset dem
                cnt <= '0;
            end else begin
                // Tin hieu khac trang thai on dinh => bat dau dem
                if (cnt == DEB_TIME[CNT_W-1:0] - 1) begin
                    // Du thoi gian on dinh => cap nhat trang thai
                    btn_stable <= btn_s2;
                    cnt        <= '0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // Output
    // =========================================================================
    assign btn_out = btn_stable;

    // Phat hien canh: so sanh trang thai hien tai voi truoc do 1 clk
    logic btn_stable_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) btn_stable_prev <= 1'b0;
        else        btn_stable_prev <= btn_stable;
    end

    assign btn_rise = ( btn_stable && !btn_stable_prev);  // 0->1
    assign btn_fall = (!btn_stable &&  btn_stable_prev);  // 1->0

endmodule