`timescale 1ns/1ps
// =============================================================================
// tb_addr_generator.sv - Testbench tu kiem chung cho module addr_generator
// =============================================================================
// Muc tieu kiem tra:
//   1. Che do zoom_en=0, mirror_en=0: rd_addr = (pixel_y/2)*160 + (pixel_x/2)
//      chi trong vung 320x240, ngoai vung -> in_frame=0, rd_addr=0
//   2. Che do zoom_en=1, mirror_en=0: rd_addr = pixel_y*160 + (pixel_x/4)
//      tren toan bo vung active 640x480
//   3. Che do mirror_en=1 o ca 2 zoom: toa do X bi dao nguoc truoc khi tinh addr
//   4. rd_addr duoc chot dung 1 chu ky clk_25 sau khi in_frame/pixel hop le
// =============================================================================
module tb_addr_generator;

    logic        clk_25, rst_n;
    logic        active;
    logic [9:0]  pixel_x, pixel_y;
    logic        zoom_en, mirror_en;
    logic [16:0] rd_addr;
    logic        in_frame;

    int errors = 0;
    int checks = 0;

    addr_generator dut (
        .clk_25   (clk_25),
        .rst_n    (rst_n),
        .active   (active),
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y),
        .zoom_en  (zoom_en),
        .mirror_en(mirror_en),
        .rd_addr  (rd_addr),
        .in_frame (in_frame)
    );

    initial clk_25 = 0;
    always #20 clk_25 = ~clk_25;

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %s", msg);
        end
    endtask

    // Ham tinh gia tri ky vong (mo hinh tham chieu song song voi RTL)
    function automatic logic [16:0] expected_addr(
        input logic [9:0] px, input logic [9:0] py,
        input logic zoom, input logic mirror
    );
        logic [9:0] eff_x;
        logic [8:0] eff_y;
        logic [7:0] col_idx;
        logic [8:0] row_idx;
        begin
            if (zoom) begin
                eff_x = mirror ? (10'd639 - px) : px;
                eff_y = py[8:0];
                col_idx = eff_x[9:2];
                row_idx = eff_y;
            end else begin
                eff_x = mirror ? (10'd319 - px) : px;
                eff_y = py[8:0];
                col_idx = eff_x[9:1];
                row_idx = {eff_y[7:0], 1'b0};
            end
            expected_addr = (17'(row_idx) * 17'd160) + 17'(col_idx);
        end
    endfunction

    function automatic bit expected_in_frame(
        input logic [9:0] px, input logic [9:0] py, input logic zoom
    );
        if (zoom) expected_in_frame = 1'b1; // toan bo active
        else      expected_in_frame = (px < 320) && (py < 240);
    endfunction

    // Task lai 1 diem pixel qua DUT va so sanh voi mo hinh tham chieu
    // (co bu 1 chu ky vi rd_addr duoc dang ky - registered)
    task automatic apply_and_check(
        input logic [9:0] px, input logic [9:0] py,
        input logic zoom, input logic mirror, input string tag
    );
        logic [16:0] exp_addr;
        logic        exp_inframe;
        begin
            zoom_en   = zoom;
            mirror_en = mirror;
            active    = 1'b1;
            pixel_x   = px;
            pixel_y   = py;
            exp_inframe = expected_in_frame(px, py, zoom);
            exp_addr    = expected_addr(px, py, zoom, mirror);

            @(posedge clk_25); // dua gia tri vao comb logic
            @(posedge clk_25); // cho 1 chu ky de rd_addr (registered) cap nhat

            check(in_frame == exp_inframe,
                  $sformatf("[%s] px=%0d py=%0d: in_frame=%0b, ky vong %0b",
                            tag, px, py, in_frame, exp_inframe));

            if (exp_inframe) begin
                check(rd_addr == exp_addr,
                      $sformatf("[%s] px=%0d py=%0d: rd_addr=%0d, ky vong %0d",
                                tag, px, py, rd_addr, exp_addr));
            end else begin
                check(rd_addr == 17'd0,
                      $sformatf("[%s] px=%0d py=%0d (ngoai khung): rd_addr=%0d, ky vong 0",
                                tag, px, py, rd_addr));
            end
        end
    endtask

    initial begin
        $dumpfile("tb_addr_generator.vcd");
        $dumpvars(0, tb_addr_generator);

        rst_n = 0; zoom_en = 0; mirror_en = 0; active = 0;
        pixel_x = 0; pixel_y = 0;
        repeat (4) @(posedge clk_25);
        rst_n = 1;
        @(posedge clk_25);

        // ---------------- Che do 1:1 (zoom_en=0), khong mirror -------------
        apply_and_check(10'd0,   10'd0,   1'b0, 1'b0, "1:1 goc trai-tren");
        apply_and_check(10'd318, 10'd238, 1'b0, 1'b0, "1:1 gan goc phai-duoi trong khung");
        apply_and_check(10'd160, 10'd120, 1'b0, 1'b0, "1:1 giua khung");
        apply_and_check(10'd320, 10'd100, 1'b0, 1'b0, "1:1 ngoai khung (px=320)");
        apply_and_check(10'd100, 10'd240, 1'b0, 1'b0, "1:1 ngoai khung (py=240)");
        apply_and_check(10'd500, 10'd400, 1'b0, 1'b0, "1:1 xa ngoai khung (nen den)");

        // ---------------- Che do Zoom fullscreen (zoom_en=1) ----------------
        apply_and_check(10'd0,   10'd0,   1'b1, 1'b0, "Zoom goc trai-tren");
        apply_and_check(10'd639, 10'd479, 1'b1, 1'b0, "Zoom goc phai-duoi");
        apply_and_check(10'd320, 10'd240, 1'b1, 1'b0, "Zoom giua man hinh");

        // ---------------- Che do Mirror (lat guong truc X) ------------------
        apply_and_check(10'd0,   10'd0,   1'b0, 1'b1, "1:1 + Mirror goc trai");
        apply_and_check(10'd319, 10'd0,   1'b0, 1'b1, "1:1 + Mirror goc phai (=goc trai khong mirror)");
        apply_and_check(10'd0,   10'd0,   1'b1, 1'b1, "Zoom + Mirror goc trai");
        apply_and_check(10'd639, 10'd0,   1'b1, 1'b1, "Zoom + Mirror goc phai");

        // ---------------- Truong hop active = 0 (vung blanking) ------------
        active = 1'b0; pixel_x = 10'd100; pixel_y = 10'd100; zoom_en = 1'b1; mirror_en = 1'b0;
        @(posedge clk_25);
        @(posedge clk_25);
        check(in_frame == 1'b0, "active=0: in_frame phai = 0 bat ke zoom_en");
        check(rd_addr == 17'd0, "active=0: rd_addr phai = 0 (blanking)");

        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module addr_generator", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module addr_generator", errors, checks);
        $display("==============================================================");
        $finish;
    end

endmodule
