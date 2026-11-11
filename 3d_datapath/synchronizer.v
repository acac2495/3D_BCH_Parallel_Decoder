module synchronizer(clk, rst, in_sig, out_sig);

    input clk, rst, in_sig;
    (* ASYNC_REG = "TRUE" *) output reg out_sig;
    (* ASYNC_REG = "TRUE" *) reg sync_reg; 

    always @(posedge clk) begin
        if(rst) begin
            sync_reg <= 0;
            out_sig <= 0; 
        end
        else begin
            sync_reg <= in_sig;
            out_sig <= sync_reg;
        end
    end

endmodule