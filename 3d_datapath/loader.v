`include "top_3d.v"

module loader #(parameter N = 15, M = 4, T = 2) (clk, rst, start_master, leds, done_master);
    input clk, rst, start_master;
    output [7:0] leds;
    output reg done_master;

    localparam NUM_VECTORS = 5;
    localparam MAX_ITER = 5;

    (* rom_style = "block" *) reg [N*N*N-1:0] cube_in_mem [0:NUM_VECTORS-1];
    reg [N*N*N-1:0] cube_in;
    reg [3:0] vector_idx;

    initial begin
        $readmemh("cube_in_vectors.hex", cube_in_mem);
    end

    localparam TOP_IDLE = 0;
    localparam TOP_START = 1;
    localparam TOP_WAIT = 2;
    localparam TOP_DONE = 3;

    reg [1:0] top_state;
    wire [7:0] iters;

    reg start_3d;
    wire done_3d, fail_3d;
    wire [N*N*N-1:0] cube_out;

    reg [3:0] pass_cnt;
    reg any_fail; 

    top_3d #(.N(N), .M(M), .T(T), .MAX_ITER(MAX_ITER)) TOP_3D_INST (
        .clk(clk),
        .rst(rst),
        .start_3d(start_3d),
        .cube_in(cube_in),
        .done_3d(done_3d),
        .fail_3d(fail_3d),
        .iters(iters),
        .cube_out(cube_out)
    );

    always @(posedge clk) begin
        if(rst) begin
            top_state <= TOP_IDLE;
            pass_cnt <= 4'b0;
            vector_idx <= 0;
            start_3d <= 0;
            done_master <= 0;
        end
        else begin
            case(top_state)
                TOP_IDLE : begin
                    if(start_master) begin
                        top_state <= TOP_START;
                    end
                    start_3d <= 0;
                end
                TOP_START : begin
                    cube_in <= cube_in_mem[vector_idx];
                    start_3d <= 1;
                    top_state <= TOP_WAIT;
                end
                TOP_WAIT : begin
                    start_3d <= 0;
                    if(done_3d) begin
                        if(~fail_3d && (cube_out == 0)) begin
                            pass_cnt <= pass_cnt + 1;
                        end
                        else begin
                            any_fail <= 1;  
                        end
                        vector_idx <= vector_idx + 1;
                        if(vector_idx == NUM_VECTORS-1) begin
                            top_state <= TOP_DONE;
                            done_master <= 1;
                        end
                        else begin
                            top_state <= TOP_START;
                        end
                    end
                end
                TOP_DONE : begin
                    done_master <= 1;
                end
            endcase
        end
    end

    assign leds = {any_fail, 2'b00, done_master, pass_cnt};
endmodule