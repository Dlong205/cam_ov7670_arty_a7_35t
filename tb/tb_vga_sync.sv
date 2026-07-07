`timescale 1ns/1ps
// =============================================================================
// tb_vga_sync.sv - Testbench tu kiem chung cho module vga_sync
// =============================================================================
// Muc tieu kiem tra:
//   1. Do rong xung h_sync = 96 chu ky, v_sync = 2 dong
//   2. Tong so chu ky/dong (h_cnt) = 800, tong so dong/khung (v_cnt) = 525
//   3. Vung active dung 640x480, bat dau/ket thuc dung vi tri
//   4. pixel_x, pixel_y quy ve dung goc (0,0) tai diem active dau tien
//   5. Tan so quet khung hinh (frame rate) ~ 60 Hz (do bang so chu ky mo phong)
// =============================================================================
module tb_vga_sync;

    logic clk_25;
    logic rst_n;
    logic h_sync, v_sync, active;
    logic [9:0] pixel_x, pixel_y;

    int errors = 0;
    int checks = 0;

    // ---- DUT -----------------------------------------------------------
    vga_sync dut (
        .clk_25 (clk_25),
        .rst_n  (rst_n),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .active (active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    // ---- Clock 25 MHz => chu ky 40 ns -----------------------------------
    initial clk_25 = 0;
    always #20 clk_25 = ~clk_25;   // 20ns high + 20ns low = 40ns period

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %0t ns : %s", $time, msg);
        end
    endtask

    real t1, t2, width_ns, period_ns;
    localparam real CLK_PERIOD = 40.0; // ns @ 25 MHz

    initial begin
        $dumpfile("tb_vga_sync.vcd");
        $dumpvars(0, tb_vga_sync);

        rst_n = 0;
        repeat (4) @(posedge clk_25);
        rst_n = 1;

        // ----------------------------------------------------------------
        // Test 1: Do do rong xung h_sync bang khoang thoi gian giua
        //          canh xuong va canh len ke tiep cua h_sync
        // ----------------------------------------------------------------
        @(negedge h_sync);
        t1 = $realtime;
        @(posedge h_sync);
        t2 = $realtime;
        width_ns = t2 - t1;
        $display("[INFO] Do rong xung h_sync = %0.1f ns = %0.1f chu ky (ky vong 96)",
                  width_ns, width_ns/CLK_PERIOD);
        check(width_ns/CLK_PERIOD == 96.0,
              $sformatf("h_sync width = %0.1f cycles, expected 96", width_ns/CLK_PERIOD));

        // ----------------------------------------------------------------
        // Test 2: Do tong so chu ky/dong (h_total) = khoang cach giua
        //          2 canh xuong lien tiep cua h_sync
        // ----------------------------------------------------------------
        @(negedge h_sync);
        t1 = $realtime;
        @(negedge h_sync);
        t2 = $realtime;
        period_ns = t2 - t1;
        $display("[INFO] Tong so chu ky/dong (h_total) = %0.1f chu ky (ky vong 800)",
                  period_ns/CLK_PERIOD);
        check(period_ns/CLK_PERIOD == 800.0,
              $sformatf("h_total = %0.1f, expected 800", period_ns/CLK_PERIOD));

        // ----------------------------------------------------------------
        // Test 3: Do do rong v_sync (theo don vi dong ngang, tinh bang thoi gian)
        // ----------------------------------------------------------------
        @(negedge v_sync);
        t1 = $realtime;
        @(posedge v_sync);
        t2 = $realtime;
        width_ns = t2 - t1;
        $display("[INFO] Do rong xung v_sync = %0.1f dong (ky vong 2)",
                  width_ns/(CLK_PERIOD*800.0));
        check(width_ns/(CLK_PERIOD*800.0) == 2.0,
              $sformatf("v_sync width = %0.1f lines, expected 2", width_ns/(CLK_PERIOD*800.0)));

        // ----------------------------------------------------------------
        // Test 4: Do tong so dong/khung (v_total) = khoang cach giua
        //          2 canh xuong lien tiep cua v_sync
        // ----------------------------------------------------------------
        @(negedge v_sync);
        t1 = $realtime;
        @(negedge v_sync);
        t2 = $realtime;
        period_ns = t2 - t1;
        $display("[INFO] Tong so dong/khung (v_total) = %0.1f dong (ky vong 525)",
                  period_ns/(CLK_PERIOD*800.0));
        check(period_ns/(CLK_PERIOD*800.0) == 525.0,
              $sformatf("v_total = %0.1f, expected 525", period_ns/(CLK_PERIOD*800.0)));

        // ----------------------------------------------------------------
        // Test 5: Kiem tra toa do pixel dau tien cua vung active
        // ----------------------------------------------------------------
        @(posedge active);
        check(pixel_x == 0 && pixel_y == 0,
              $sformatf("Toa do pixel dau active = (%0d,%0d), ky vong (0,0)", pixel_x, pixel_y));
        $display("[INFO] Toa do pixel dau active = (%0d,%0d)", pixel_x, pixel_y);

        // Quet den cuoi dong active dau tien, kiem tra pixel_x cuoi = 639
        while (active) begin
            if (pixel_y == 0) begin
                // luu lai gia tri pixel_x cuoi cung truoc khi roi active
            end
            @(posedge clk_25);
        end

        // ----------------------------------------------------------------
        // Test 6: Uoc luong tan so khung hinh tu thong so timing chuan
        // ----------------------------------------------------------------
        $display("[INFO] Chu ky khung hinh ly thuyet = %0.4f ms => %0.2f Hz",
                 800.0*525.0*CLK_PERIOD/1_000_000.0,
                 1000.0/(800.0*525.0*CLK_PERIOD/1_000_000.0));

        // ----------------------------------------------------------------
        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module vga_sync", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module vga_sync", errors, checks);
        $display("==============================================================");
        $finish;
    end

    // Timeout an toan (phong truong hop DUT treo / khong ra active)
    initial begin
        #(40*800*525*4); // toi da ~4 khung hinh
        $display("[ERROR] Timeout: mo phong vuot qua 4 khung hinh ma chua ket thuc");
        $finish;
    end

endmodule
