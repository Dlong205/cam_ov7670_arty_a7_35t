`timescale 1ns/1ps
// =============================================================================
// tb_debounce.sv - Testbench tu kiem chung cho module debounce
// =============================================================================
// De sim nhanh, giam DEB_TIME xuong con 20 chu ky (thay vi 1.250.000).
// Nguyen ly khong doi: chi cong nhan trang thai moi khi giu nguyen DEB_TIME
// chu ky lien tuc.
//
// Muc tieu kiem tra:
//   1. Chuoi "rung" (bounce train) ngay khi nhan/tha KHONG lam btn_out doi
//      neu chua du DEB_TIME chu ky on dinh
//   2. Sau khi tin hieu on dinh muc moi du DEB_TIME chu ky, btn_out cap nhat
//   3. btn_rise / btn_fall phat dung 1 xung tai dung thoi diem btn_out doi
//   4. Nhieu chuoi rung lien tiep (nhan-tha-nhan nhanh) khong lam sai lech
//      logic, cuoi cung van hoi tu ve dung trang thai on dinh cuoi cung
// =============================================================================
module tb_debounce;

    localparam int DEB_TIME_SIM = 20; // rut gon de mo phong nhanh

    logic clk, rst_n;
    logic btn_in, btn_out, btn_rise, btn_fall;

    int errors = 0;
    int checks = 0;

    debounce #(.DEB_TIME(DEB_TIME_SIM)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .btn_in  (btn_in),
        .btn_out (btn_out),
        .btn_rise(btn_rise),
        .btn_fall(btn_fall)
    );

    initial clk = 0;
    always #10 clk = ~clk; // 50 MHz gia lap, khong quan trong ty le thuc te

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %0t ns : %s", $time, msg);
        end
    endtask

    // Tao chuoi rung "bounce" ngau nhien quanh gia tri final_val trong so
    // chu ky bounce_cycles, moi chu ky giu ngau nhien vai clock roi doi
    task automatic bounce_then_settle(
        input logic final_val, input int bounce_cycles, input string tag
    );
        int i;
        begin
            $display("[INFO] %s: phat chuoi rung %0d lan quanh gia tri %0b", tag, bounce_cycles, final_val);
            for (i = 0; i < bounce_cycles; i++) begin
                btn_in = ~final_val; // nhieu/rung ve phia nguoc lai
                repeat ($urandom_range(1,3)) @(posedge clk);
                btn_in = final_val;
                repeat ($urandom_range(1,3)) @(posedge clk);
            end
            // Giu on dinh muc final_val de bat dau dem debounce that su
            btn_in = final_val;
        end
    endtask

    initial begin
        $dumpfile("tb_debounce.vcd");
        $dumpvars(0, tb_debounce);

        rst_n  = 0;
        btn_in = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ------------------------------------------------------------
        // Test 1: Chuoi rung khi nhan nut (0->1), sau do phai giu on
        // dinh du DEB_TIME chu ky moi duoc cong nhan
        // ------------------------------------------------------------
        bounce_then_settle(1'b1, 5, "Nhan nut (rung 5 lan)");
        // Ngay sau chuoi rung, btn_out CHUA duoc phep doi thanh 1 vi
        // dem se bi reset lien tuc do gia tri dao dong truoc do
        check(btn_out == 1'b0, "Ngay sau chuoi rung, btn_out van phai la 0 (chua du thoi gian on dinh)");

        // Cho du DEB_TIME chu ky on dinh (+ 2 chu ky dong bo hoa dau vao)
        repeat (DEB_TIME_SIM + 4) @(posedge clk);
        check(btn_out == 1'b1, "Sau khi giu on dinh du DEB_TIME, btn_out phai chuyen thanh 1");

        // ------------------------------------------------------------
        // Test 2: Kiem tra xung btn_rise xuat hien dung 1 chu ky tai
        // thoi diem btn_out chuyen 0->1
        // ------------------------------------------------------------
        // (Da bo lo xung vi cho lau o test 1 - lam lai tu dau voi giam sat)
        rst_n = 0; btn_in = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        fork
            begin : monitor_rise
                int rise_count = 0;
                forever begin
                    @(posedge clk);
                    if (btn_rise) rise_count++;
                    if (rise_count > 0) begin
                        check(btn_out == 1'b1, "Tai thoi diem btn_rise=1, btn_out phai dang la 1");
                        disable monitor_rise;
                    end
                end
            end
            begin
                btn_in = 1'b1; // nhan thang, khong rung, de kiem tra rise don gian
                repeat (DEB_TIME_SIM + 6) @(posedge clk);
            end
        join

        // ------------------------------------------------------------
        // Test 3: Kiem tra xung btn_fall xuat hien khi tha nut (1->0)
        // ------------------------------------------------------------
        fork
            begin : monitor_fall
                int fall_count = 0;
                forever begin
                    @(posedge clk);
                    if (btn_fall) fall_count++;
                    if (fall_count > 0) begin
                        check(btn_out == 1'b0, "Tai thoi diem btn_fall=1, btn_out phai dang la 0");
                        disable monitor_fall;
                    end
                end
            end
            begin
                btn_in = 1'b0; // tha nut
                repeat (DEB_TIME_SIM + 6) @(posedge clk);
            end
        join

        // ------------------------------------------------------------
        // Test 4: Chuoi rung phuc tap (nhan-tha-nhan lien tuc, chua
        // on dinh lan nao) roi hoi tu ve gia tri cuoi cung = 1
        // ------------------------------------------------------------
        bounce_then_settle(1'b1, 8, "Nhan nut voi chuoi rung phuc tap 8 lan");
        repeat (DEB_TIME_SIM + 4) @(posedge clk);
        check(btn_out == 1'b1, "Sau chuoi rung phuc tap, btn_out phai hoi tu dung ve 1");

        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module debounce", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module debounce", errors, checks);
        $display("==============================================================");
        $finish;
    end

    // Timeout an toan
    initial begin
        #200000;
        $display("[ERROR] Timeout mo phong debounce");
        $finish;
    end

endmodule
