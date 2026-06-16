`timescale 1ns/1ps
// =============================================================================
// addr_generator.sv  -  Tao dia chi doc BRAM tu toa do VGA
// =============================================================================
// BRAM luu anh 160x480 (camera 640x480 -> ghi 1/4 pixel ngang):
//   Stride VAT LY LUON LA 160 cot
//
// Chuc nang:
//   SW0 (zoom_en)  = 0: Che do 1:1 (320x240 o goc trai, padding den)
//   SW0 (zoom_en)  = 1: Che do Zoom 2x fullscreen (640x480)
//   SW3 (mirror_en) = 1: Lat nguoc truc X (Mirror)
//
// in_frame = 1 khi toa do nam trong vung anh hop le (dung de gate mau o rgb_decode)
// =============================================================================
module addr_generator (
    input  logic        clk_25,
    input  logic        rst_n,
    input  logic        active,      // VGA active region (640x480)
    input  logic [9:0]  pixel_x,     // 0-639
    input  logic [9:0]  pixel_y,     // 0-479
    input  logic        zoom_en,     // SW[0]: 0=1:1 mode, 1=Zoom 2x fullscreen
    input  logic        mirror_en,   // SW[3]: 1=Mirror X
    output logic [16:0] rd_addr,     // Dia chi doc BRAM (17-bit)
    output logic        in_frame     // 1 = dang nam trong khung anh
);

    logic [9:0] eff_x;
    logic [8:0] eff_y;
    logic [7:0] col_idx;
    logic [8:0] row_idx;
    logic [16:0] addr_next;

    always_comb begin
        if (zoom_en) begin
            // ----------------------------------------------------
            // CHẾ ĐỘ 1: Phóng to Fullscreen 640x480
            // ----------------------------------------------------
            in_frame = active; // Toàn bộ màn hình đều có ảnh
            
            // Xử lý Lật gương toàn màn hình
            eff_x = mirror_en ? (10'd639 - pixel_x) : pixel_x;
            eff_y = pixel_y[8:0];
            
            // Map BRAM 160x480 ra 640x480 (Cột giãn 4, Hàng giữ nguyên)
            col_idx = eff_x[9:2]; 
            row_idx = eff_y;      
        end else begin
            // ----------------------------------------------------
            // CHẾ ĐỘ 0: Khung hình nguyên bản 320x240 ở góc trái
            // ----------------------------------------------------
            in_frame = active && (pixel_x < 10'd320) && (pixel_y < 10'd240);
            
            // Xử lý Lật gương trong vùng 320x240
            eff_x = mirror_en ? (10'd319 - pixel_x) : pixel_x;
            eff_y = pixel_y[8:0];
            
            // Map BRAM 160x480 ra 320x240 (Cột giãn 2, Hàng nén 2)
            col_idx = eff_x[9:1];             
            row_idx = {eff_y[7:0], 1'b0};     
        end

        // Chốt địa chỉ đọc (Ép kiểu 17-bit chống tràn)
        addr_next = (17'(row_idx) * 17'd160) + 17'(col_idx);
    end

    // Ghi địa chỉ vào Flip-Flop (Delay 1 clock cho BRAM)
    always_ff @(posedge clk_25 or negedge rst_n) begin
        if (!rst_n) rd_addr <= 17'd0;
        else        rd_addr <= in_frame ? addr_next : 17'd0;
    end

endmodule