`timescale 1ns/1ps
// =============================================================================
// frame_buffer.sv  -  Dual-port Block RAM (Frame Buffer)
// =============================================================================
// Day la module xu ly Clock Domain Crossing (CDC) chinh cua du an:
//
//   Port A (WRITE) : chay tren PCLK  (~25 MHz, tu camera)
//   Port B (READ)  : chay tren clk_25 (~25 MHz, tu VGA controller)
//
// Hai clock co tan so gan bang nhau nhung KHAC NGUON => van la 2 clock domain.
// Dual-port BRAM trong Artix-7 ho tro true dual-clock, Vivado tu them
// synchronizer noi bo => an toan cho CDC nay (khong can async FIFO rieng).
//
// --- Kich thuoc BRAM ---
//   WIDTH = 12 bit  (RGB444: R[3:0] G[3:0] B[3:0])
//   DEPTH = 2^17 = 131072 entries
//   Tong: 131072 x 12 = 1,572,864 bit ~ 1.5 Mb
//   Artix-7 35T co 1,800 Kb BRAM => vua du (con du cho logic khac).
//
// --- Chieu do phan giai ---
//   Camera ghi o 640x480 (pix_cnt 19-bit), top-level dung addr[18:2]
//   => BRAM address = pix_cnt / 4 => luu 1/4 pixel theo chieu ngang
//   => Hieu qua: 160 x 480 pixels trong BRAM (17-bit address)
//   Khi doc: VGA cung dung [18:2] cua raw_addr => moi pixel hien thi
//   duoc lap lai 4 lan ngang => anh day man hinh nhung do phan giai thap hon.
//
// --- Synthesis note ---
//   Thuoc tinh (* ram_style = "block" *) ep Vivado dung BRAM thay vi LUT-RAM.
//   Neu bo thuoc tinh nay, Vivado co the chon distributed RAM (khong du lon).
//
// --- Latency ---
//   Port B (doc): 1 chu ky clk_25 (registered output).
//   => addr_generator phai cap dia chi SOM 1 chu ky truoc khi can data.
//      top.sv xu ly bang cach dung pixel_x/y truoc do 1 clock (xem top.sv).
// =============================================================================
module frame_buffer #(
    parameter int WIDTH  = 12,          // RGB444
    parameter int ADDR_W = 17,          // 2^17 = 131072 entries
    parameter int DEPTH  = 2**ADDR_W
) (
    // ---- Port A: WRITE (PCLK domain - camera) -------------------------------
    input  logic              clka,
    input  logic              wea,
    input  logic [ADDR_W-1:0] addra,
    input  logic [WIDTH-1:0]  dina,

    // ---- Port B: READ (clk_25 domain - VGA) ---------------------------------
    input  logic              clkb,
    input  logic [ADDR_W-1:0] addrb,
    output logic [WIDTH-1:0]  doutb
);

    // =========================================================================
    // Khai bao BRAM
    // =========================================================================
    // Thuoc tinh ram_style = "block" BAT BUOC phai co.
    // Neu dung distributed RAM: khong du (chi co ~400 Kb tren 35T).
    (* ram_style = "block" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // =========================================================================
    // Port A: ghi dong bo theo PCLK
    // =========================================================================
    always_ff @(posedge clka) begin
        if (wea)
            mem[addra] <= dina;
    end

    // =========================================================================
    // Port B: doc dong bo theo clk_25, co 1 chu ky latency
    // =========================================================================
    always_ff @(posedge clkb) begin
        doutb <= mem[addrb];
    end

    // =========================================================================
    // Luu y quan trong cho simulation:
    // =========================================================================
    // Trong Vivado sim: dual-clock BRAM co the hien thi 'X' o port B neu
    // port A vua ghi xong cung dia chi ma chua du setup time.
    // Day la hanh vi binh thuong cua true-dual-port BRAM -- khong phai bug.
    // Tren phan cung that, Vivado them sync logic noi bo de tranh xung dot.

endmodule