`timescale 1ns/1ps
// =============================================================================
// ov7670_controller.sv  -  Camera initialisation FSM + Register ROM
// =============================================================================
// Chuc nang:
//   1. Giu camera reset trong INIT_DELAY chu ky sau power-on.
//   2. Gui tung entry trong register ROM qua sccb_master.
//   3. Sau soft-reset (reg 0x12=0x80) cho them RESET_DELAY.
//   4. Giua cac register cho INTER_DELAY.
//   5. Phat `cfg_done` khi xong toan bo.
//
// Fix Vivado 2022: khong duoc viet rom(x)[15:8] truc tiep trong always_ff.
// Giai phap: dung wire rom_out lay ket qua combinational, roi assign vao FF.
// =============================================================================
module ov7670_controller #(
    parameter int INIT_DELAY  = 500_000,
    parameter int RESET_DELAY = 125_000,
    parameter int INTER_DELAY = 5_000
) (
    input  logic clk,
    input  logic rst_n,
    input  logic resend,
    output logic cfg_done,
    output logic xclk,
    output logic cam_rst_n,
    output logic pwdn,
    output logic sioc,
    output logic siod_out,
    output logic siod_oe
);

    // =========================================================================
    // Register ROM
    // =========================================================================
    localparam int NUM_ENTRIES = 64;

    function automatic logic [15:0] rom (input logic [5:0] i);
        unique case (i)
            6'd0 : return 16'h1280; // Reset
            
            // -----------------------------------------------------------
            // ?Ã S?A: B?t Color Bar và gi?m t?c ?? PCLK
            // -----------------------------------------------------------
            6'd1 : return 16'h1204; // COM7: B?t RGB và B?t Color Bar (Test Pattern)
            6'd2 : return 16'h1183; // CLKRC: Gi?m xung nh?p PCLK xu?ng 4 l?n (Kh? nhi?u cáp dài)
            // -----------------------------------------------------------

            6'd3 : return 16'h0C00;
            6'd4 : return 16'h3E00;
            6'd5 : return 16'h0400;
            6'd6 : return 16'h40D0;
            6'd7 : return 16'h3A04;
            6'd8 : return 16'h3DC0;
            6'd9 : return 16'h4FB3;
            6'd10: return 16'h50B3;
            6'd11: return 16'h5100;
            6'd12: return 16'h523D;
            6'd13: return 16'h53A7;
            6'd14: return 16'h54E4;
            6'd15: return 16'h589E;
            6'd16: return 16'h1418;
            6'd17: return 16'h13E7;
            6'd18: return 16'h0140;
            6'd19: return 16'h0260;
            6'd20: return 16'h6A40;
            6'd21: return 16'h1714;
            6'd22: return 16'h1802;
            6'd23: return 16'h3280;
            6'd24: return 16'h1903;
            6'd25: return 16'h1A7B;
            6'd26: return 16'h030A;
            6'd27: return 16'h0F41;
            6'd28: return 16'h1E00;
            6'd29: return 16'h6B4A;
            6'd30: return 16'h6900;
            6'd31: return 16'h7410;
            6'd32: return 16'h0E61;
            6'd33: return 16'h1602;
            6'd34: return 16'h2102;
            6'd35: return 16'h2291;
            6'd36: return 16'h2907;
            6'd37: return 16'h330B;
            6'd38: return 16'h350B;
            6'd39: return 16'h371D;
            6'd40: return 16'h3871;
            6'd41: return 16'h392A;
            6'd42: return 16'h3C78;
            6'd43: return 16'h4D40;
            6'd44: return 16'h4E20;
            6'd45: return 16'hB084;
            6'd46: return 16'h8D4F;
            6'd47: return 16'h8E00;
            6'd48: return 16'h8F00;
            6'd49: return 16'h9000;
            6'd50: return 16'h9100;
            6'd51: return 16'h9600;
            6'd52: return 16'h9A00;
            6'd53: return 16'hB10C;
            6'd54: return 16'hB20E;
            6'd55: return 16'hB382;
            6'd56: return 16'hB80A;
            6'd57: return 16'hB60A;
            6'd58: return 16'hB705;
            6'd59: return 16'hB900;
            6'd60: return 16'hBA78;
            6'd61: return 16'hBB88;
            6'd62: return 16'h1500; // COM10: VSYNC/HREF polarity normal
            6'd63: return 16'hFFFF;
            default: return 16'hFFFF;
        endcase
    endfunction

    // =========================================================================
    // FIX: wire combinational lay ket qua rom() TRUOC khi vao FF
    // Vivado 2022 khong chap nhan rom(x)[15:8] truc tiep trong always_ff.
    // rom_out la combinational (cap nhat ngay lap tuc theo reg_idx),
    // nen co the slice bit binh thuong trong always_ff.
    // =========================================================================
    logic [5:0]  reg_idx;
    logic [15:0] rom_out;           // <-- wire trung gian, combinational
    assign rom_out = rom(reg_idx);  // <-- goi function o day, ngoai always_ff

    // =========================================================================
    // FSM states
    // =========================================================================
    typedef enum logic [2:0] {
        ST_INIT,
        ST_LOAD,
        ST_SEND,
        ST_WAIT_DONE,
        ST_DELAY,
        ST_DONE
    } state_t;

    state_t state;

    logic [25:0] dly_cnt;
    logic [25:0] dly_target;
    logic        sccb_start;
    logic        sccb_done;
    logic        sccb_busy;
    logic [15:0] cur_entry;
    logic [7:0]  r_reg_addr;
    logic [7:0]  r_reg_data;

    // =========================================================================
    // SCCB master
    // =========================================================================
    sccb_master #(
        .HALF_PERIOD (1250) // Giam toc do I2C de an toan khi dung day cam roi
    ) u_sccb (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (sccb_start),
        .reg_addr (r_reg_addr),
        .reg_data (r_reg_data),
        .busy     (sccb_busy),
        .done     (sccb_done),
        .sioc     (sioc),
        .siod_out (siod_out),
        .siod_oe  (siod_oe)
    );

    // =========================================================================
    // FSM
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_INIT;
            reg_idx    <= 6'd0;
            dly_cnt    <= 26'd0;
            dly_target <= INIT_DELAY[25:0];
            sccb_start <= 1'b0;
            r_reg_addr <= 8'd0;
            r_reg_data <= 8'd0;
            cur_entry  <= 16'd0;
            cfg_done   <= 1'b0;
            cam_rst_n  <= 1'b0;
            pwdn       <= 1'b0;
        end else begin
            sccb_start <= 1'b0;

            case (state)

                ST_INIT: begin
                    cam_rst_n <= 1'b0;
                    if (dly_cnt == dly_target) begin
                        cam_rst_n  <= 1'b1;
                        dly_cnt    <= 26'd0;
                        reg_idx    <= 6'd0;
                        state      <= ST_LOAD;
                    end else begin
                        dly_cnt <= dly_cnt + 26'd1;
                    end
                end

                // FIX: dung rom_out thay vi rom(reg_idx)[x:y]
                ST_LOAD: begin
                    cur_entry  <= rom_out;
                    r_reg_addr <= rom_out[15:8];  // OK: slice wire, khong phai slice function call
                    r_reg_data <= rom_out[7:0];
                    state      <= ST_SEND;
                end

                ST_SEND: begin
                    if (cur_entry == 16'hFFFF) begin
                        cfg_done <= 1'b1;
                        state    <= ST_DONE;
                    end else begin
                        sccb_start <= 1'b1;
                        state      <= ST_WAIT_DONE;
                    end
                end

                ST_WAIT_DONE: begin
                    if (sccb_done) begin
                        dly_target <= (reg_idx == 6'd0) ? RESET_DELAY[25:0]
                                                        : INTER_DELAY[25:0];
                        dly_cnt    <= 26'd0;
                        reg_idx    <= reg_idx + 6'd1;
                        state      <= ST_DELAY;
                    end
                end

                ST_DELAY: begin
                    if (dly_cnt == dly_target) begin
                        dly_cnt <= 26'd0;
                        state   <= ST_LOAD;
                    end else begin
                        dly_cnt <= dly_cnt + 26'd1;
                    end
                end

                ST_DONE: begin
                    if (resend) begin
                        cfg_done   <= 1'b0;
                        reg_idx    <= 6'd0;
                        dly_cnt    <= 26'd0;
                        dly_target <= INTER_DELAY[25:0];
                        state      <= ST_LOAD;
                    end
                end

                default: state <= ST_INIT;

            endcase
        end
    end

    assign xclk = clk;

endmodule