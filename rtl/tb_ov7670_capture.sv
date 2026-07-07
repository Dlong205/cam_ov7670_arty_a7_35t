`timescale 1ns/1ps

module tb_ov7670_capture;

    logic        pclk;
    logic        rst_n;
    logic        vsync;
    logic        href;
    logic [7:0]  d;
    logic [18:0] wr_addr;
    logic [11:0] wr_data;
    logic        wr_en;

    ov7670_capture u_dut (
        .pclk    (pclk),
        .rst_n   (rst_n),
        .vsync   (vsync),
        .href    (href),
        .d       (d),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .wr_en   (wr_en)
    );

    // Clock generation: 25 MHz PCLK = 40ns period
    initial pclk = 0;
    always #20 pclk = ~pclk;

    // Test pattern: simulate OV7670 output for 640x480 frame
    // OV7670 outputs YUV422: 2 bytes per pixel (Y0, U, Y1, V)
    // We'll simulate a simple color bar pattern
    
    logic [7:0] pixel_data [0:1279]; // 640 pixels * 2 bytes = 1280 bytes per line
    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic [10:0] line_cnt;
    
    initial begin
        // Generate color bar pattern for 640 pixels (each pixel = 2 bytes in YUV422)
        // 8 color bars of 80 pixels each
        for (int i = 0; i < 640; i++) begin
            logic [2:0] bar = i / 80;
            logic [7:0] y, u, v;
            case (bar)
                3'd0: {y,u,v} = {8'hEB, 8'h10, 8'h80}; // White
                3'd1: {y,u,v} = {8'hD2, 8'h91, 8'h11}; // Yellow
                3'd2: {y,u,v} = {8'h9E, 8'h24, 8'hF0}; // Cyan
                3'd3: {y,u,v} = {8'h85, 8'hA5, 8'h81}; // Green
                3'd4: {y,u,v} = {8'h7A, 8'h5A, 8'h7E}; // Magenta
                3'd5: {y,u,v} = {8'h61, 0xDC, 0x0F};   // Red
                3'd6: {y,u,v} = {0x2D, 0x6F, 0xF0};    // Blue
                3'd7: {y,u,v} = {0x14, 0xF0, 0x7F};    // Black
            endcase
            pixel_data[i*2]   = y;  // Y0
            pixel_data[i*2+1] = (i[0] == 1'b0) ? u : v; // U/V alternating
        end
    end

    // Simulate camera timing
    initial begin
        rst_n = 0;
        vsync = 0;
        href  = 0;
        d     = 8'h00;
        pixel_x = 0;
        pixel_y = 0;
        line_cnt = 0;
        
        repeat(5) @(negedge pclk);
        rst_n = 1;
        repeat(2) @(negedge pclk);
        
        // Simulate VSYNC pulse (active high during blanking)
        vsync = 1;
        repeat(3) @(negedge pclk); // V sync pulse
        vsync = 0;
        repeat(33) @(negedge pclk); // V back porch
        
        for (int y = 0; y < 480; y++) begin
            pixel_y = y;
            // H front porch
            href = 0;
            repeat(16) @(negedge pclk);
            
            // H sync pulse
            href = 0;
            repeat(96) @(negedge pclk);
            
            // H back porch
            href = 0;
            repeat(48) @(negedge pclk);
            
            // Active video: 640 pixels = 1280 bytes (YUV422)
            href = 1;
            pixel_x = 0;
            for (int x = 0; x < 1280; x++) begin
                d = pixel_data[x];
                @(negedge pclk);
                pixel_x = x / 2;
            end
            
            // H front porch after line
            href = 0;
            repeat(16) @(negedge pclk);
        end
        
        // V front porch
        vsync = 0;
        href = 0;
        repeat(10) @(negedge pclk);
        
        // V sync pulse for next frame
        vsync = 1;
        repeat(2) @(negedge pclk);
        vsync = 0;
        
        repeat(100) @(negedge pclk);
        $finish;
    end

    // Monitor write transactions
    logic [18:0] last_wr_addr;
    logic [11:0] last_wr_data;
    int pixel_count;
    
    always_ff @(negedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 0;
            last_wr_addr <= 0;
            last_wr_data <= 0;
        end else if (wr_en) begin
            pixel_count <= pixel_count + 1;
            last_wr_addr <= wr_addr;
            last_wr_data <= wr_data;
            $display("WR[%0d] addr=%0d data=%h (R=%h G=%h B=%h)", 
                     pixel_count, wr_addr, wr_data, wr_data[11:8], wr_data[7:4], wr_data[3:0]);
        end
    end

    // Check expected pixel count: 640*480/4 = 76800 pixels (due to 1/4 subsampling)
    initial begin
        wait(rst_n);
        wait(pixel_count >= 76800);
        $display("SUCCESS: Captured %0d pixels (expected 76800 for 160x480 subsampled)", pixel_count);
        repeat(100) @(negedge pclk);
        $finish;
    end

    initial begin
        $dumpfile("tb_ov7670_capture.vcd");
        $dumpvars(0, tb_ov7670_capture);
    end

endmodule