`timescale 1ns/1ps
// =============================================================================
// tb_rgb_decode.sv - Testbench tu kiem chung cho module rgb_decode
// =============================================================================
// Muc tieu kiem tra (mach thuan to hop - khong co clock):
//   1. Blanking: active=0 -> luon ra mau den (0,0,0) bat ke cac tin hieu khac
//   2. Test pattern: active=1, test_en=1 -> luon ra mau do 12'hF00
//   3. Anh thuong: active=1, test_en=0, neg_en=0, bw_en=0 -> xuat dung RGB444 goc
//   4. B&W: brightness > THRESHOLD(22) -> trang (FFF), nguoc lai -> den (000)
//   5. Negative: dao bit tat ca kenh mau cua ket qua sau lop B&W
//   6. Ket hop B&W + Negative dong thoi (lop noi tiep)
//   7. Do uu tien MUX: test_en luon thang the bat ke bw_en/neg_en
// =============================================================================
module tb_rgb_decode;

    logic        active, test_en, neg_en, bw_en;
    logic [11:0] din;
    logic [3:0]  r, g, b;

    int errors = 0;
    int checks = 0;

    rgb_decode #(.THRESHOLD(22)) dut (
        .active (active),
        .test_en(test_en),
        .neg_en (neg_en),
        .bw_en  (bw_en),
        .din    (din),
        .r      (r),
        .g      (g),
        .b      (b)
    );

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %s", msg);
        end
    endtask

    // Mo hinh tham chieu song song (mo phong dung 3 lop loc cua RTL)
    task automatic apply_and_check(
        input logic [3:0] rc, input logic [3:0] gc, input logic [3:0] bc,
        input logic act, input logic ten, input logic nen, input logic bwen,
        input string tag
    );
        logic [5:0] brightness;
        logic       is_white;
        logic [3:0] r1, g1, b1, r2, g2, b2;
        logic [3:0] exp_r, exp_g, exp_b;
        begin
            din     = {rc, gc, bc};
            active  = act;
            test_en = ten;
            neg_en  = nen;
            bw_en   = bwen;
            #5; // cho comb logic on dinh

            brightness = rc + gc + bc;
            is_white   = (brightness > 22);
            {r1,g1,b1} = bwen ? (is_white ? 12'hFFF : 12'h000) : {rc,gc,bc};
            {r2,g2,b2} = nen  ? {~r1,~g1,~b1} : {r1,g1,b1};

            if (!act)      {exp_r,exp_g,exp_b} = 12'h000;
            else if (ten)  {exp_r,exp_g,exp_b} = 12'hF00;
            else           {exp_r,exp_g,exp_b} = {r2,g2,b2};

            check({r,g,b} == {exp_r,exp_g,exp_b},
                  $sformatf("[%s] din=%03h act=%0b ten=%0b nen=%0b bwen=%0b => rgb=%01h%01h%01h, ky vong %01h%01h%01h",
                            tag, din, act, ten, nen, bwen, r, g, b, exp_r, exp_g, exp_b));
        end
    endtask

    initial begin
        $dumpfile("tb_rgb_decode.vcd");
        $dumpvars(0, tb_rgb_decode);

        // ---- 1. Blanking: active=0 luon ra den, bat ke cac tin hieu khac ----
        apply_and_check(4'hF, 4'h0, 4'h0, 1'b0, 1'b0, 1'b0, 1'b0, "Blanking co ban");
        apply_and_check(4'hF, 4'hF, 4'hF, 1'b0, 1'b1, 1'b1, 1'b1, "Blanking du test/neg/bw=1");

        // ---- 2. Test pattern uu tien cao nhat khi active=1 ----
        apply_and_check(4'h3, 4'h3, 4'h3, 1'b1, 1'b1, 1'b0, 1'b0, "Test pattern co ban");
        apply_and_check(4'hF, 4'hF, 4'hF, 1'b1, 1'b1, 1'b1, 1'b1, "Test pattern du bw+neg=1 van uu tien do");

        // ---- 3. Anh thuong (pass-through), khong loc gi ----
        apply_and_check(4'hA, 4'h5, 4'h2, 1'b1, 1'b0, 1'b0, 1'b0, "Pass-through mau tuy y");
        apply_and_check(4'h0, 4'h0, 4'h0, 1'b1, 1'b0, 1'b0, 1'b0, "Pass-through mau den");
        apply_and_check(4'hF, 4'hF, 4'hF, 1'b1, 1'b0, 1'b0, 1'b0, "Pass-through mau trang");

        // ---- 4. B&W Threshold: brightness so voi 22 ----
        // brightness = 4+4+4=12 <=22 -> den
        apply_and_check(4'h4, 4'h4, 4'h4, 1'b1, 1'b0, 1'b0, 1'b1, "B&W: brightness=12 (<=22) -> den");
        // brightness = 8+8+8=24 > 22 -> trang
        apply_and_check(4'h8, 4'h8, 4'h8, 1'b1, 1'b0, 1'b0, 1'b1, "B&W: brightness=24 (>22) -> trang");
        // brightness dung nguong bien: 7+7+8=22 (khong > 22) -> den
        apply_and_check(4'h7, 4'h7, 4'h8, 1'b1, 1'b0, 1'b0, 1'b1, "B&W: brightness=22 (bien duoi) -> den");
        // brightness = 7+8+8=23 (>22) -> trang
        apply_and_check(4'h7, 4'h8, 4'h8, 1'b1, 1'b0, 1'b0, 1'b1, "B&W: brightness=23 (bien tren) -> trang");

        // ---- 5. Negative don thuan (khong bw) ----
        apply_and_check(4'h0, 4'hF, 4'h3, 1'b1, 1'b0, 1'b1, 1'b0, "Negative: dao bit tung kenh");
        apply_and_check(4'hF, 4'h0, 4'hF, 1'b1, 1'b0, 1'b1, 1'b0, "Negative: dao bit truong hop khac");

        // ---- 6. Ket hop B&W roi Negative (thu tu lop noi tiep) ----
        // brightness=8+8+8=24>22 -> trang (FFF) -> negative -> den (000)
        apply_and_check(4'h8, 4'h8, 4'h8, 1'b1, 1'b0, 1'b1, 1'b1, "B&W(trang)+Negative => den");
        // brightness=4+4+4=12<=22 -> den (000) -> negative -> trang (FFF)
        apply_and_check(4'h4, 4'h4, 4'h4, 1'b1, 1'b0, 1'b1, 1'b1, "B&W(den)+Negative => trang");

        // ---- 7. Quet ngau nhien mot vai to hop de tang do bao phu ----
        begin
            logic [3:0] rc, gc, bc;
            logic act, ten, nen, bwen;
            for (int i = 0; i < 12; i++) begin
                rc = $urandom_range(0,15);
                gc = $urandom_range(0,15);
                bc = $urandom_range(0,15);
                act = $urandom_range(0,1);
                ten = $urandom_range(0,1);
                nen = $urandom_range(0,1);
                bwen = $urandom_range(0,1);
                apply_and_check(rc, gc, bc, act, ten, nen, bwen,
                                 $sformatf("Random#%0d", i));
            end
        end

        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module rgb_decode", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module rgb_decode", errors, checks);
        $display("==============================================================");
        $finish;
    end

endmodule
