`timescale 1ns/1ps
// =============================================================================
// tb_ov7670_capture.sv - Testbench mo phong camera gia lap cho ov7670_capture
// =============================================================================
// Vi module bat du lieu tai CANH XUONG cua pclk, testbench dong vai tro
// "camera gia" se doi du lieu d[7:0] va href/vsync o CANH LEN cua pclk
// (giong cach camera thuc xuat du lieu) de dam bao du lieu on dinh dung
// luc DUT lay mau.
//
// Muc tieu kiem tra:
//   1. Ghep dung 2 byte RGB565 lien tiep thanh 1 tu RGB444 12-bit theo
//      dung cong thuc {byte0[7:4], byte0[2:0], byte1[7], byte1[4:1]}
//   2. wr_en chi bat dung 1 chu ky sau khi nhan du 2 byte (moi 2 xung href)
//   3. wr_addr tang dan tuan tu 0,1,2,... theo tung pixel ghi ra
//   4. vsync tich cuc lam pix_cnt/wr_addr reset ve 0 cho khung hinh moi
//   5. Khi href = 0 (giua cac dong), khong co wr_en nao duoc phat sinh
// =============================================================================
module tb_ov7670_capture;

    logic       pclk, rst_n;
    logic       vsync, href;
    logic [7:0] d;
    logic [18:0] wr_addr;
    logic [11:0] wr_data;
    logic        wr_en;

    int errors = 0;
    int checks = 0;

    ov7670_capture dut (
        .pclk   (pclk),
        .rst_n  (rst_n),
        .vsync  (vsync),
        .href   (href),
        .d      (d),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en  (wr_en)
    );

    // PCLK camera gia lap ~6.25 MHz => chu ky 160 ns
    initial pclk = 0;
    always #80 pclk = ~pclk;

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %0t ns : %s", $time, msg);
        end
    endtask

    // Ham tinh RGB444 ky vong tu 2 byte RGB565 (dung cong thuc trong RTL)
    function automatic logic [11:0] expected_rgb444(input logic [7:0] b0, input logic [7:0] b1);
        expected_rgb444 = { b0[7:4], b0[2:0], b1[7], b1[4:1] };
    endfunction

    // Task "camera gia" xuat 1 pixel (2 byte) qua href, dong bo tai CANH LEN pclk
    // (DUT bat mau tai canh xuong => du lieu se on dinh dung luc DUT doc)
    int wr_en_count = 0;
    logic [11:0] last_wr_data;
    logic [18:0] last_wr_addr;

    // Giam sat wr_en/wr_data/wr_addr moi khi co xung, ghi lai lich su de doi chieu
    logic [11:0] captured_data_q[$];
    logic [18:0] captured_addr_q[$];

    // QUAN TRONG: DUT dung always_ff @(negedge pclk) voi phep gan non-blocking.
    // Neu monitor cung kich hoat dung tai negedge pclk, no co the doc gia tri
    // CU (truoc khi NBA cap nhat) do hai always block cung mot su kien khong
    // dam bao thu tu thuc thi (kinh dien "race condition" trong mo phong).
    // => Them tre #1 sau canh xuong de dam bao NBA cua DUT da hoan tat.
    always @(negedge pclk) begin
        #1;
        if (wr_en) begin
            captured_data_q.push_back(wr_data);
            captured_addr_q.push_back(wr_addr);
        end
    end

    // "Camera gia" xuat 1 pixel (2 byte) dong bo tai CANH LEN pclk.
    // QUAN TRONG: href phai duoc bat CUNG LUC voi byte dau tien (cung 1 posedge),
    // neu bat href SOM HON 1 nhip so voi d, canh xuong ngay sau do se lay mau
    // nham d cu (chua kip cap nhat) => lam lech pha toan bo chuoi byte con lai.
    task automatic start_line(input logic [7:0] first_byte);
        @(posedge pclk);
        href = 1'b1;
        d    = first_byte;
    endtask

    task automatic next_byte(input logic [7:0] byte_val);
        @(posedge pclk);
        d = byte_val;
    endtask

    task automatic end_line();
        @(posedge pclk); // cho canh xuong cuoi cung kip lay mau byte cuoi
        href = 1'b0;
    endtask

    task automatic send_vsync_pulse();
        @(posedge pclk);
        vsync = 1'b1;
        @(posedge pclk);
        vsync = 1'b0;
    endtask

    initial begin
        $dumpfile("tb_ov7670_capture.vcd");
        $dumpvars(0, tb_ov7670_capture);

        rst_n = 0; vsync = 0; href = 0; d = 0;
        repeat (4) @(posedge pclk);
        rst_n = 1;
        repeat (2) @(posedge pclk);

        // ------------------------------------------------------------
        // Khoi dau khung hinh: xung vsync de dam bao pix_cnt = 0
        // ------------------------------------------------------------
        send_vsync_pulse();

        // ------------------------------------------------------------
        // Test 1+3: Gui 6 pixel lien tiep (12 byte) trong 1 dong href,
        //           kiem tra ghep byte dung va wr_addr tang tuan tu
        // ------------------------------------------------------------
        captured_data_q.delete();
        captured_addr_q.delete();

        start_line(8'hF3); next_byte(8'h5A); next_byte(8'h12); next_byte(8'hC7);
        next_byte(8'h00); next_byte(8'hFF); next_byte(8'hFF); next_byte(8'h00);
        next_byte(8'hAB); next_byte(8'h34); next_byte(8'h55); next_byte(8'hAA);
        end_line(); // 6 pixel = 12 byte

        check(captured_data_q.size() == 6,
              $sformatf("So pixel ghi duoc trong 1 dong = %0d, ky vong 6", captured_data_q.size()));

        check(captured_data_q[0] == expected_rgb444(8'hF3, 8'h5A),
              $sformatf("Pixel0: wr_data=%03h, ky vong %03h", captured_data_q[0], expected_rgb444(8'hF3,8'h5A)));
        check(captured_data_q[1] == expected_rgb444(8'h12, 8'hC7),
              $sformatf("Pixel1: wr_data=%03h, ky vong %03h", captured_data_q[1], expected_rgb444(8'h12,8'hC7)));
        check(captured_data_q[2] == expected_rgb444(8'h00, 8'hFF),
              $sformatf("Pixel2: wr_data=%03h, ky vong %03h", captured_data_q[2], expected_rgb444(8'h00,8'hFF)));
        check(captured_data_q[3] == expected_rgb444(8'hFF, 8'h00),
              $sformatf("Pixel3: wr_data=%03h, ky vong %03h", captured_data_q[3], expected_rgb444(8'hFF,8'h00)));
        check(captured_data_q[4] == expected_rgb444(8'hAB, 8'h34),
              $sformatf("Pixel4: wr_data=%03h, ky vong %03h", captured_data_q[4], expected_rgb444(8'hAB,8'h34)));
        check(captured_data_q[5] == expected_rgb444(8'h55, 8'hAA),
              $sformatf("Pixel5: wr_data=%03h, ky vong %03h", captured_data_q[5], expected_rgb444(8'h55,8'hAA)));

        // wr_addr phai tang tuan tu 0,1,2,3,4,5
        for (int i = 0; i < 6; i++) begin
            check(captured_addr_q[i] == i,
                  $sformatf("wr_addr pixel %0d = %0d, ky vong %0d", i, captured_addr_q[i], i));
        end

        // ------------------------------------------------------------
        // Test 2: Trong khoang href=0 (giua cac dong), khong co wr_en nao
        // ------------------------------------------------------------
        captured_data_q.delete();
        repeat (10) @(posedge pclk); // href dang = 0 ngay sau send_line() ket thuc
        check(captured_data_q.size() == 0,
              $sformatf("Khi href=0, so wr_en phat sinh = %0d, ky vong 0", captured_data_q.size()));

        // ------------------------------------------------------------
        // Test 4: vsync reset wr_addr/pix_cnt ve 0 cho khung hinh moi
        // ------------------------------------------------------------
        // Gui them 1 dong nua (3 pixel) de wr_addr tiep tuc tang len 6,7,8
        captured_data_q.delete();
        captured_addr_q.delete();
        start_line(8'h11); next_byte(8'h22); next_byte(8'h33);
        next_byte(8'h44); next_byte(8'h55); next_byte(8'h66);
        end_line(); // 3 pixel = 6 byte
        check(captured_addr_q[0] == 6 && captured_addr_q[1] == 7 && captured_addr_q[2] == 8,
              $sformatf("wr_addr truoc vsync moi = %0d,%0d,%0d, ky vong 6,7,8",
                        captured_addr_q[0], captured_addr_q[1], captured_addr_q[2]));

        // Bay gio phat xung vsync cho khung hinh moi
        send_vsync_pulse();
        captured_data_q.delete();
        captured_addr_q.delete();
        start_line(8'hDE); next_byte(8'hAD); end_line(); // 1 pixel
        check(captured_addr_q[0] == 0,
              $sformatf("Sau vsync, wr_addr pixel dau tien = %0d, ky vong 0 (da reset)", captured_addr_q[0]));

        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module ov7670_capture", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module ov7670_capture", errors, checks);
        $display("==============================================================");
        $finish;
    end

    initial begin
        #500000;
        $display("[ERROR] Timeout mo phong ov7670_capture");
        $finish;
    end

endmodule
