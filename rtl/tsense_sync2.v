// 2-flop synchronizer with async active-high reset
module tsense_sync2 (
    input  wire clk,
    input  wire rst,
    input  wire d,
    output wire q
);
    reg s1, s2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin s1 <= 1'b0; s2 <= 1'b0; end
        else     begin s1 <= d;    s2 <= s1;   end
    end
    assign q = s2;
endmodule
