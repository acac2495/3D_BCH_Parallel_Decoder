`include "top_3d.v"
`include "synchronizer.v"
`include "debouncer.v"

module top_interface(clk, rst, start_master, done_master, leds);
    input clk, rst, start_master;
    output reg done_master;
    output reg [7:0] leds;

    localparam N = 15;
    localparam M = 4;
    localparam T = 2;
    localparam MAX_ITER = 5;
    localparam NUM_VECTORS = 5;

    (* rom_style = "block" *) reg [N*N*N-1:0] cube_in_mem [0:NUM_VECTORS-1];
    reg [N*N*N-1:0] cube_in;
    reg [3:0] vector_idx;

    reg start_3d;
    wire done_3d, fail_3d;
    wire [7:0] iters;
    wire [N*N*N-1:0] cube_out;

    wire start_master_sync;
    wire start_master_btn;
    wire start_master_pulse;

    wire rst_sync;

    synchronizer SYNC_RST (
        .clk(clk),
        .rst(rst),
        .in_sig(rst),
        .out_sig(rst_sync)
    );

    synchronizer SYNC_START_MASTER (
        .clk(clk),
        .rst(rst),
        .in_sig(start_master),
        .out_sig(start_master_sync)
    );

    debouncer #(.STABLE_CYCLES(1_600_000)) DEBOUNCE_START_MASTER (
        .clk(clk),
        .rst(rst),
        .in_sig(start_master_sync),
        .out_sig(start_master_btn),
        .rise(start_master_pulse)
    );

    top_3d #(.N(N), .M(M), .T(T), .MAX_ITER(MAX_ITER)) TOP_3D_INST (
        .clk(clk),
        .rst(rst_sync),
        .start_3d(start_3d),
        .cube_in(cube_in),
        .done_3d(done_3d),
        .fail_3d(fail_3d),
        .iters(iters),
        .cube_out(cube_out)
    );

    initial begin
        $readmemh("cube_in_vectors.hex", cube_in_mem);
    end

    localparam TOP_IDLE = 0;
    localparam TOP_START = 1;
    localparam TOP_WAIT = 2;
    localparam TOP_BUFFER = 3;
    reg [2:0] top_state;

    always @(posedge clk) begin
        if(rst_sync) begin
            top_state <= TOP_IDLE;
            vector_idx <= 0;
            start_3d <= 0;
            leds <= 0;
            done_master <= 0;
        end
        else begin
            case(top_state)
                TOP_IDLE : begin
                    if(start_master_pulse) begin
                        top_state <= TOP_START;
                        start_3d <= 0;
                        leds <= 0;
                        vector_idx <= 0;
                        done_master <= 0;
                    end
                end
                TOP_START : begin
                    cube_in <= cube_in_mem[vector_idx];
                    start_3d <= 1;
                    top_state <= TOP_WAIT;
                    vector_idx <= vector_idx + 1;
                end
                TOP_WAIT : begin
                    start_3d <= 0;
                    if(done_3d) begin
                        if(~fail_3d && cube_out == 0) begin
                            leds <= leds + 1;
                        end
                        top_state <= TOP_BUFFER;
                    end
                end
                TOP_BUFFER : begin
                    if (vector_idx == NUM_VECTORS) begin
                        done_master <= 1;               
                        top_state <= TOP_IDLE;
                    end
                    else begin
                        if(start_master_pulse) begin
                            top_state <= TOP_START;
                        end
                    end
                end
            endcase
        end
    end
    
endmodule