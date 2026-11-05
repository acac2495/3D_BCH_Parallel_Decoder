`include "../2d_bch_datapath/ccp/ccp_top.v"
`include "../2d_bch_datapath/DFFFT/dffft_top.v"

module top_3d #(parameter N = 15, M = 4, T = 2, MAX_ITER = 100) (clk, rst, start_3d, cube_in, done_3d, fail_3d, iters, cube_out);
    input clk, rst, start_3d;
    input [N*N*N-1:0] cube_in;

    output reg [7:0] iters;
    output reg done_3d, fail_3d;
    output [N*N*N-1:0] cube_out;

    reg [N*N-1:0] r_in_2d [0:N-1];  //Input 2d slices
    reg [N*N-1:0] err_2d [0:N-1];   //Ouptput 2d errors from 2d instances
    reg [N*N*N-1:0] cube;           //internally reconstructed cube
    reg [N*N-1:0] corr_2d [0:N-1];  //corrected 2d slices
    reg start_2d;                   //common start signal for 2d decoders

    integer i, r, c;

    assign cube_out = cube;

    //fsm states
    localparam IDLE = 0;
    localparam LOAD = 1;
    localparam START = 2;
    localparam WAIT = 3;
    localparam VERIFY = 4;
    localparam APPLY = 5;
    localparam NEXT = 6;

    //control registers
    reg [2:0] state;
    reg [1:0] pass_idx;
    reg sweep_dirty;

    wire [N*N-1:0] c_out_2d [0:N-1];    //2d decoder outputs
    wire [N-1:0] done_2d_v;             //2d decoder done signals

    reg [N-1:0] check;                  //check signals

    //2d decoders
    genvar p;
    generate
        for(p = 0; p < N; p = p + 1) begin 
            ccp_top #(.N(N), .M(M), .T(T)) DEC_2D_INST (
                .clk(clk),
                .rst(rst),
                .start(start_2d),
                .r_in(r_in_2d[p]),
                .c_out(c_out_2d[p]),
                .done(done_2d_v[p])
            );
        end
    endgenerate

    wire [(2*T)*(2*T)*M-1:0] synd [0:N-1];  //syndrome outputs

    //Syndrome checks
    genvar q;
    generate
        for(q = 0; q < N; q = q + 1) begin 
            dffft_top #(.M(M), .T(T), .N(N)) SYNDROME_CHECK_INST(
                .c_in(r_in_2d[q] ^ err_2d[q]),
                .C_out(synd[q])
            );
        end
    endgenerate

    always @(*) begin
        for(i = 0; i < N; i = i + 1) begin
            check[i] = (synd[i] == 0) && (err_2d[i] != 0);
        end
    end

    //helper functions
    function [2*8-1:0] pr_or;
        input [1:0] pass_idx;
        begin
            case(pass_idx)
                2'b00 : pr_or = "xy";
                2'b01 : pr_or = "xz";
                2'b10 : pr_or = "yz";
                default : pr_or = "xy";
            endcase
        end
    endfunction

    task print_status;
        input [1:0] pass_idx;
        input [7:0] iters;
        begin
            $display("Done with %s pass, iter : %d", pr_or(pass_idx), iters);
        end
    endtask

    always @(posedge clk) begin
        if(rst) begin       //setting all registers to 0
            cube <= 0;
            state <= IDLE;
            pass_idx <= 0;
            sweep_dirty <= 0;
            iters <= 0;
            done_3d <= 0;
            fail_3d <= 0;
            start_2d <= 0;

            for(i = 0; i < N; i = i + 1) begin
                r_in_2d[i] <= 0;
                err_2d[i] <= 0;
                corr_2d[i] <= 0;
            end
        end
        else begin
            case(state)
                IDLE : begin
                    pass_idx <= 0;
                    sweep_dirty <= 0;

                    iters <= 0;
                    done_3d <= 0;
                    fail_3d <= 0;

                    if(start_3d) begin      //loading in the input cube (will operate on this register now)
                        cube <= cube_in;
                        state <= LOAD;
                    end
                end

                LOAD : begin
                    for(i = 0; i < N; i = i + 1) begin      //breaking the cube into the slices
                        for(r = 0; r < N; r = r + 1) begin
                            for(c = 0; c < N; c = c + 1) begin
                                r_in_2d[i][r*N + c] <= (pass_idx == 0) ? cube[(r*N + c)*N + i]: 
                                                       (pass_idx == 1) ? cube[(r*N + i)*N + c]: 
                                                                         cube[(i*N + r)*N + c]; 
                            end
                        end
                    end
                    start_2d <= 1;
                    state <= WAIT;
                end

                /*START : begin      
                    start_2d <= 1;
                    state <= WAIT;
                end*/

                WAIT : begin        //waiting till done, then registering the 2d errors
                    start_2d <= 0;
                    if(&done_2d_v) begin
                        for(i = 0; i < N; i = i + 1) begin
                            err_2d[i] <= c_out_2d[i];
                        end
                        state <= VERIFY;
                    end
                end

                VERIFY : begin         //applying the checks, and zeroing wherever necessary (will replace with syndrome calc blocks)
                    for(i = 0; i < N; i = i + 1) begin
                        if(~check[i]) begin
                            corr_2d[i] <= r_in_2d[i];
                        end
                        else begin
                            corr_2d[i] <= r_in_2d[i] ^ err_2d[i];
                        end
                    end
                    state <= APPLY;
                    if(|check) begin    //sticky check for whether any correction was done in any pass of an iteration
                        sweep_dirty <= 1'b1;
                    end
                end

                APPLY : begin       //reconstructing the cube from the slice corrections
                    for(r = 0; r < N; r = r + 1) begin
                        for(c = 0; c < N; c = c + 1) begin
                            case(pass_idx)
                                2'd0 : begin
                                    for(i = 0; i < N; i = i + 1) begin
                                        cube[(r*N + c)*N + i] <= corr_2d[i][r*N + c];
                                    end
                                end
                                2'd1 : begin
                                    for(i = 0; i < N; i = i + 1) begin
                                        cube[(r*N + i)*N + c] <= corr_2d[i][r*N + c];
                                    end
                                end
                                default : begin
                                    for(i = 0; i < N; i = i + 1) begin
                                        cube[(i*N + r)*N + c] <= corr_2d[i][r*N + c];
                                    end
                                end
                            endcase
                        end
                    end
                    state <= NEXT; 
                end

                NEXT : begin    
                    print_status(pass_idx, iters);    
                    if(pass_idx != 2'd2) begin
                        pass_idx <= pass_idx + 1;
                        state <= LOAD;
                    end
                    else if(sweep_dirty == 0) begin
                        done_3d <= 1;
                        state <= IDLE;
                    end
                    else if(iters == MAX_ITER - 1) begin
                        fail_3d <= 1;
                        done_3d <= 1;
                        state <= IDLE;
                    end
                    else begin
                        iters <= iters + 1;
                        pass_idx <= 0;
                        sweep_dirty <= 0;
                        state <= LOAD;
                    end
                end
            endcase
        end 
    end
endmodule