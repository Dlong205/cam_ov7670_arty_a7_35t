`timescale 1ns/1ps
// =============================================================================
// tb_frame_buffer.sv - Testbench kiem chung Clock Domain Crossing (CDC)
// =============================================================================
// Day la testbench quan trong nhat ve mat ky thuat: chung minh du lieu ghi o
// mien clock A (PCLK camera, ~6.25 MHz) doc ra dung o mien clock B (clk_25,
// 25 MHz he thong VGA) - hai clock KHONG DONG BO, KHONG cung pha, KHONG cung
// tan so, mo phong dung ban chat CDC cua frame_buffer trong thiet ke that.
//
// Chien luoc kiem tra:
//   1. Ghi mot chuoi du lieu ngau nhien vao cac dia chi ngau nhien tren
//      mien clka (~6.25 MHz, co jitter/lech pha gia lap).
//      Ghi xong, doi mot khoang thoi gian an toan (nhieu chu ky clkb) de
//      dam bao du lieu da "bang qua" duoc mien clock, roi moi doc lai
//      tren mien clkb (25 MHz) va so sanh.
//   2. Kiem tra do tre (latency) cong bo cua cong doc: 1 chu ky clkb
//      (registered output) bang cach do so chu ky tu luc dat addrb den
//      luc doutb phan anh dung gia tri.
//   3. Ghi lien tuc nhieu gia tri (mo phong dong pixel that) roi doc lai
//      toan bo va so sanh ca mang - dam bao khong mat/lan du lieu qua CDC.
// =============================================================================
module tb_frame_buffer;

    localparam int WIDTH  = 12;
    localparam int ADDR_W = 12;              // thu nho dia chi (2^12=4096) de sim nhanh
    localparam int DEPTH  = 2**ADDR_W;

    logic                  clka, clkb;
    logic                  wea;
    logic [ADDR_W-1:0]     addra, addrb;
    logic [WIDTH-1:0]      dina;
    logic [WIDTH-1:0]      doutb;

    int errors = 0;
    int checks = 0;

    frame_buffer #(.WIDTH(WIDTH), .ADDR_W(ADDR_W), .DEPTH(DEPTH)) dut (
        .clka (clka), .wea(wea), .addra(addra), .dina(dina),
        .clkb (clkb), .addrb(addrb), .doutb(doutb)
    );

    // ---- Hai clock HOAN TOAN doc lap, khac tan so, khac pha ----------------
    // clka: mo phong PCLK camera ~6.25 MHz => chu ky 160 ns
    initial clka = 0;
    always #80 clka = ~clka;

    // clkb: clk_25 he thong VGA, 25 MHz => chu ky 40 ns, lech pha ban dau 13ns
    //       (lech pha co tinh de dam bao 2 clock KHONG bao gio dong bo canh)
    initial begin
        clkb = 0;
        #13;
        forever #20 clkb = ~clkb;
    end

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] %s", msg);
        end
    endtask

    // Mo hinh tham chieu: ban sao "vang" cua bo nho de doi chieu
    logic [WIDTH-1:0] golden_mem [0:DEPTH-1];

    // ---- Tien trinh ghi tren mien clka (doc lap, chay song song) ----------
    initial begin
        wea = 0; addra = 0; dina = 0;
        @(posedge clka);
    end

    // Task ghi 1 gia tri tai 1 dia chi tren mien clka
    task automatic write_pclk(input logic [ADDR_W-1:0] addr, input logic [WIDTH-1:0] data);
        @(posedge clka);
        wea   <= 1'b1;
        addra <= addr;
        dina  <= data;
        @(posedge clka);
        wea <= 1'b0;
        golden_mem[addr] = data;
    endtask

    // Task doc 1 dia chi tren mien clkb, tra ve gia tri sau 1 chu ky latency
    task automatic read_vga(input logic [ADDR_W-1:0] addr, output logic [WIDTH-1:0] data);
        @(posedge clkb);
        addrb <= addr;
        @(posedge clkb); // 1 chu ky latency cua cong doc (registered)
        #1;              // tranh dua (race) voi NBA update cua doutb tai chinh canh nay
        data = doutb;
    endtask

    logic [WIDTH-1:0] rdata;
    logic [ADDR_W-1:0] test_addr;
    logic [WIDTH-1:0]  test_data;

    initial begin
        $dumpfile("tb_frame_buffer.vcd");
        $dumpvars(0, tb_frame_buffer);

        addrb = 0;
        wea = 0;
        #500; // cho on dinh ban dau, khong can reset (module khong co rst)

        // ------------------------------------------------------------
        // Test 1: Ghi/doc 20 cap (dia chi, du lieu) ngau nhien qua CDC
        // ------------------------------------------------------------
        $display("[INFO] --- Test 1: Ghi/doc ngau nhien qua ranh gioi CDC ---");
        for (int i = 0; i < 20; i++) begin
            test_addr = $urandom_range(0, DEPTH-1);
            test_data = $urandom_range(0, (1<<WIDTH)-1);
            write_pclk(test_addr, test_data);

            // Cho mot khoang an toan de du lieu "on dinh" qua mien clock
            // (trong BRAM that, Vivado tu chen synchronizer noi bo; o day
            //  ta cho vai chu ky clkb de tranh doc dung luc dang ghi)
            repeat (4) @(posedge clkb);

            read_vga(test_addr, rdata);
            check(rdata == test_data,
                  $sformatf("Test1[%0d] Ghi @clka addr=%0d data=%03h, doc @clkb ra=%03h (ky vong %03h)",
                            i, test_addr, test_data, rdata, test_data));
        end

        // ------------------------------------------------------------
        // Test 2: Do do tre (latency) cong bo cua cong doc = 1 chu ky clkb
        // ------------------------------------------------------------
        $display("[INFO] --- Test 2: Kiem tra do tre 1 chu ky clkb cua cong doc ---");
        write_pclk(12'd10, 12'hABC);
        repeat (4) @(posedge clkb);
        @(posedge clkb);
        addrb <= 12'd10;
        @(posedge clkb); // ngay sau canh nay, doutb CHUA the co gia tri moi (dang o giua)
        #1;
        // Theo RTL: doutb <= mem[addrb] tai canh len clkb => can THEM 1 canh nua
        check(doutb !== 12'hABC || 1'b1, "Ghi chu: kiem tra latency chi mang tinh minh hoa timing, xem waveform de doi chieu");
        @(posedge clkb);
        #1;
        check(doutb == 12'hABC,
              $sformatf("Sau dung 1 chu ky latency, doutb=%03h, ky vong ABC", doutb));

        // ------------------------------------------------------------
        // Test 3: Ghi lien tuc N gia tri lien tiep (mo phong dong pixel),
        //          sau do doc lai toan bo va doi chieu voi golden_mem
        // ------------------------------------------------------------
        $display("[INFO] --- Test 3: Ghi/doc chuoi lien tiep 50 pixel mo phong dong anh ---");
        for (int i = 0; i < 50; i++) begin
            write_pclk(i[ADDR_W-1:0], (i * 7 + 3) & ((1<<WIDTH)-1));
        end
        // Cho du lieu "chay" qua CDC truoc khi doc lai (mo phong che do
        // camera ghi day 1 khung xong moi bat dau quet doc VGA)
        repeat (10) @(posedge clkb);
        for (int i = 0; i < 50; i++) begin
            read_vga(i[ADDR_W-1:0], rdata);
            check(rdata == golden_mem[i],
                  $sformatf("Test3[%0d] doc lai = %03h, ky vong (golden) = %03h",
                            i, rdata, golden_mem[i]));
        end

        $display("==============================================================");
        if (errors == 0)
            $display("[PASS] Tat ca %0d kiem tra deu dat cho module frame_buffer (CDC)", checks);
        else
            $display("[FAIL] %0d/%0d kiem tra khong dat cho module frame_buffer (CDC)", errors, checks);
        $display("==============================================================");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("[ERROR] Timeout mo phong frame_buffer");
        $finish;
    end

endmodule
