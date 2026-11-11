module debouncer #(parameter STABLE_CYCLES = 1_600_000) (clk, rst, in_sig, out_sig, rise);

    input clk, rst, in_sig;
    output reg out_sig;
    output rise;

    localparam CNT_WIDTH = $clog2(STABLE_CYCLES);
    reg [CNT_WIDTH-1:0] stable_cnt;
    reg prev;

    always @(posedge clk) begin
        if(rst) begin
            stable_cnt <= 0;
            prev <= 0;
            out_sig <= 0;
        end
        else begin
            prev <= out_sig;
            if(out_sig == in_sig) begin
                stable_cnt <= 0;
            end
            else begin
                if(stable_cnt == (STABLE_CYCLES - 1)) begin
                    out_sig <= in_sig;
                    stable_cnt <= 0;
                end
                else begin
                    stable_cnt <= stable_cnt + 1;
                end
            end
        end
    end

    assign rise = (out_sig && ~prev);

endmodule