`timescale 1ns/1ps

module sccb_master #(
    parameter int HALF_PERIOD = 1250
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,          
    input  logic [7:0]  reg_addr,
    input  logic [7:0]  reg_data,
    output logic        busy,           
    output logic        done,           
    output logic        sioc,           
    output logic        siod_out,       
    output logic        siod_oe         
);

    localparam [7:0] SLAVE_WR = 8'h42;

    typedef enum logic [3:0] {
        ST_IDLE, ST_START_HH, ST_START_HL, ST_START_LL,
        ST_DATA_LO, ST_DATA_HI, ST_STOP_LO, ST_STOP_RISE, ST_STOP_HH, ST_DONE
    } state_t;

    state_t state;

    localparam int HP_W = $clog2(HALF_PERIOD);
    logic [HP_W-1:0] half_cnt;
    logic            half_done;
    logic [3:0]      bit_idx;
    logic [1:0]      byte_idx;
    logic [7:0]      tx_bytes [2:0];
    logic            cur_bit;

    assign half_done = (half_cnt == HALF_PERIOD[HP_W-1:0] - 1);
    assign cur_bit = (bit_idx == 4'd8) ? 1'b1 : tx_bytes[byte_idx][7 - bit_idx[2:0]];
    assign busy = (state != ST_IDLE);
    assign done = (state == ST_DONE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            half_cnt <= '0;
        else if (state == ST_IDLE || state == ST_DONE)
            half_cnt <= '0;
        else
            half_cnt <= half_done ? '0 : half_cnt + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            bit_idx     <= 4'd0;
            byte_idx    <= 2'd0;
            tx_bytes[0] <= SLAVE_WR;
            tx_bytes[1] <= 8'd0;
            tx_bytes[2] <= 8'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        tx_bytes[0] <= SLAVE_WR;    
                        tx_bytes[1] <= reg_addr;
                        tx_bytes[2] <= reg_data;
                        bit_idx     <= 4'd0;
                        byte_idx    <= 2'd0;
                        state       <= ST_START_HH;
                    end
                end
                ST_START_HH: if (half_done) state <= ST_START_HL;
                ST_START_HL: if (half_done) state <= ST_START_LL;
                ST_START_LL: if (half_done) state <= ST_DATA_LO;
                ST_DATA_LO:  if (half_done) state <= ST_DATA_HI;
                ST_DATA_HI: begin
                    if (half_done) begin
                        if (bit_idx == 4'd8) begin
                            bit_idx <= 4'd0;
                            if (byte_idx == 2'd2) state <= ST_STOP_LO;
                            else begin byte_idx <= byte_idx + 2'd1; state <= ST_DATA_LO; end
                        end else begin
                            bit_idx <= bit_idx + 4'd1; state <= ST_DATA_LO;              
                        end
                    end
                end
                ST_STOP_LO:   if (half_done) state <= ST_STOP_RISE;
                ST_STOP_RISE: if (half_done) state <= ST_STOP_HH;
                ST_STOP_HH:   if (half_done) state <= ST_DONE;
                ST_DONE: state <= ST_IDLE;
                default: state <= ST_IDLE;
            endcase
        end
    end

    // FIX OPEN-DRAIN: Khong day 3.3V vao camera de tranh doan mach
    logic sda_val;
    always_comb begin
        sioc     = 1'b1;
        sda_val  = 1'b1; 
        unique case (state)
            ST_IDLE:      begin sioc = 1'b1; sda_val = 1'b1; end
            ST_START_HH:  begin sioc = 1'b1; sda_val = 1'b1; end
            ST_START_HL:  begin sioc = 1'b1; sda_val = 1'b0; end 
            ST_START_LL:  begin sioc = 1'b0; sda_val = 1'b0; end
            ST_DATA_LO:   begin sioc = 1'b0; sda_val = cur_bit; end
            ST_DATA_HI:   begin sioc = 1'b1; sda_val = cur_bit; end
            ST_STOP_LO:   begin sioc = 1'b0; sda_val = 1'b0; end
            ST_STOP_RISE: begin sioc = 1'b1; sda_val = 1'b0; end
            ST_STOP_HH:   begin sioc = 1'b1; sda_val = 1'b1; end 
            ST_DONE:      begin sioc = 1'b1; sda_val = 1'b1; end
            default:      begin sioc = 1'b1; sda_val = 1'b1; end
        endcase
    end

    assign siod_out = 1'b0;       
    assign siod_oe  = ~sda_val;   // Chi keo xuong GND khi can
endmodule