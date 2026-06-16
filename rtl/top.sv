`timescale 1ns/1ps

module top (
    input  logic       clk,         // 100 MHz tu Arty A7
    
    // Nut nhan & Cong tac
    input  logic       btnC,        // Center: Resend config camera
    input  logic       btnR,        // Right: Test Pattern (giu de xuat mau do)
    input  logic [3:0] sw,          // SW[0]: Zoom, SW[1]: Negative, SW[2]: B&W, SW[3]: Mirror
    
    // VGA Outputs (PMOD)
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       vga_hs,
    output logic       vga_vs,
    
    // Camera OV7670 IOs
    input  logic       ov_pclk,
    input  logic       ov_href,
    input  logic       ov_vsync,
    input  logic [7:0] ov_d,
    output logic       ov_xclk,
    output logic       ov_pwdn,
    output logic       ov_reset_n,
    output logic       ov_sioc,
    inout  wire        ov_siod,
    
    // LEDs Debug
    output logic [3:0] led
);

    // =========================================================================
    // 1. Tao xung nhip 25MHz cho he thong
    // =========================================================================
    logic clk_25, locked;
    clk_gen u_clk_gen (
        .clk_100 (clk),
        .rst_n   (1'b1),
        .clk_25  (clk_25),
        .locked  (locked)
    );

    logic rst_n;
    assign rst_n = locked; // Chi chay khi clock da on dinh

    // =========================================================================
    // 2. Chong rung nut nhan
    // =========================================================================
    logic resend_cfg;
    logic btnR_out;  // btnR debounced output (Test Pattern hold)
    debounce u_db_btnC (.clk(clk_25), .rst_n(rst_n), .btn_in(btnC), .btn_out(), .btn_rise(resend_cfg), .btn_fall());
    debounce u_db_btnR (.clk(clk_25), .rst_n(rst_n), .btn_in(btnR), .btn_out(btnR_out), .btn_rise(), .btn_fall());

    // =========================================================================
    // 3. Cau hinh Camera (SCCB Controller)
    // =========================================================================
    logic cfg_done;
    logic siod_out, siod_oe;
    assign ov_siod = siod_oe ? siod_out : 1'bz;

    ov7670_controller u_cam_ctrl (
    
        .clk       (clk_25), 
        .rst_n     (rst_n),
        .resend    (resend_cfg),
        .cfg_done  (cfg_done),
        .xclk      (ov_xclk),
        .cam_rst_n (ov_reset_n),
        .pwdn      (ov_pwdn),
        .sioc      (ov_sioc),
        .siod_out  (siod_out),
        .siod_oe   (siod_oe)
    );

    // =========================================================================
    // 3.5. CDC Reset Synchronizer cho domain PCLK
    // =========================================================================
    logic rst_n_pclk_s1, rst_n_pclk;
    always_ff @(posedge ov_pclk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_pclk_s1 <= 1'b0;
            rst_n_pclk    <= 1'b0;
        end else begin
            rst_n_pclk_s1 <= 1'b1;
            rst_n_pclk    <= rst_n_pclk_s1;
        end
    end

    // =========================================================================
    // 4. Bat du lieu tu Camera (Capture)
    // =========================================================================
    logic [18:0] wr_addr;
    logic [11:0] wr_data;
    logic        wr_en;

   ov7670_capture u_capture (
        .pclk    (ov_pclk),
        .rst_n   (rst_n_pclk),
        .vsync   (ov_vsync),
        .href    (ov_href),
        .d       (ov_d),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .wr_en   (wr_en)
   
    );

    // =========================================================================
    // 5. Bo nho BRAM (Frame Buffer) - Giai quyet Clock Domain Crossing
    // =========================================================================
    logic [16:0] rd_addr;
    logic [11:0] rd_data;

    frame_buffer u_fb (
        .clka  (ov_pclk),
        .wea   (wr_en),
        .addra (wr_addr[18:2]), // Ghi ti le 1/4 (chia 4) de vua dung luong BRAM
        .dina  (wr_data),
        .clkb  (clk_25),
        .addrb (rd_addr),
        .doutb (rd_data)
    );

    // =========================================================================
    // 6. Tao xung dong bo VGA
    // =========================================================================
    logic h_sync, v_sync, active;
    logic [9:0] pixel_x, pixel_y;

    vga_sync u_vga (
        .clk_25  (clk_25),
        .rst_n   (rst_n),
        .h_sync  (h_sync),
        .v_sync  (v_sync),
        .active  (active),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y)
    );

    // Tao dia chi doc va ap dung hieu ung Zoom/Mirror
    logic in_frame;
    addr_generator u_addr_gen (
        .clk_25    (clk_25),
        .rst_n     (rst_n),
        .active    (active),
        .pixel_x   (pixel_x),
        .pixel_y   (pixel_y),
        .zoom_en   (sw[0]),
        .mirror_en (sw[3]),
        .rd_addr   (rd_addr),
        .in_frame  (in_frame)
    );

    // =========================================================================
    // 7. FIX NHIEU HINH: Pipeline delay 2 clock bu vao latency BRAM
    // (addr_generator 1 clk + frame_buffer 1 clk = 2 clk total)
    // =========================================================================
    logic h_sync_d1, v_sync_d1, in_frame_d1;
    logic h_sync_d2, v_sync_d2, in_frame_d2;

    always_ff @(posedge clk_25 or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_d1   <= 1'b1;
            v_sync_d1   <= 1'b1;
            in_frame_d1 <= 1'b0;
            h_sync_d2   <= 1'b1;
            v_sync_d2   <= 1'b1;
            in_frame_d2 <= 1'b0;
        end else begin
            h_sync_d1   <= h_sync;
            v_sync_d1   <= v_sync;
            in_frame_d1 <= in_frame;
            h_sync_d2   <= h_sync_d1;
            v_sync_d2   <= v_sync_d1;
            in_frame_d2 <= in_frame_d1;
        end
    end

    assign vga_hs = h_sync_d2;
    assign vga_vs = v_sync_d2;

    // =========================================================================
    // 8. Bo loc mau & Xuat VGA
    // =========================================================================
    rgb_decode #(
        .THRESHOLD (22)
    ) u_rgb (
        .active  (in_frame_d2),
        .test_en (btnR_out),
        .neg_en  (sw[1]),
        .bw_en   (sw[2]),
        .din     (rd_data),
        .r       (vga_r),
        .g       (vga_g),
        .b       (vga_b)
    );

    // Hien thi trang thai len LED
    assign led[0] = cfg_done;   // I2C config done
    assign led[1] = sw[1];      // Negative enabled
    assign led[2] = sw[2];      // B&W enabled
    assign led[3] = sw[3];      // Mirror enabled

endmodule