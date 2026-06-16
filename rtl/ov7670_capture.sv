`timescale 1ns/1ps

module ov7670_capture (
    input  logic        pclk,
    input  logic        rst_n,
    input  logic        vsync,
    input  logic        href,
    input  logic [7:0]  d,
    output logic [18:0] wr_addr,
    output logic [11:0] wr_data,
    output logic        wr_en
);

    logic        byte_sel;
    logic [7:0]  byte0_r;
    logic [18:0] pix_cnt;

    // FIX: Doi sang bat suon am (negedge) de doc data chuan nhat
    always_ff @(negedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            byte_sel <= 1'b0;
            byte0_r  <= 8'd0;
            pix_cnt  <= 19'd0;
            wr_en    <= 1'b0;
            wr_addr  <= 19'd0;
            wr_data  <= 12'd0;
        end else begin
            wr_en <= 1'b0;
            if (vsync) begin
                pix_cnt  <= 19'd0;
                byte_sel <= 1'b0;
                byte0_r  <= 8'd0;   
            end else if (href) begin
                byte_sel <= ~byte_sel;
                if (!byte_sel) begin
                    byte0_r <= d;
                end else begin
                    wr_data <= { byte0_r[7:4], byte0_r[2:0], d[7], d[4:1] };
                    wr_addr <= pix_cnt;
                    wr_en   <= 1'b1;
                    pix_cnt <= pix_cnt + 19'd1;
                end
            end else begin
                byte_sel <= 1'b0;
            end
        end
    end
endmodule