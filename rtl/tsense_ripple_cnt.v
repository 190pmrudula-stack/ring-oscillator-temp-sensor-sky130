// Ripple counter: bit0 toggles on clk when en=1, bit i toggles on the
// falling edge of bit i-1. Each flop only sees its own toggle rate, so it
// works at ring-oscillator frequencies without clock-tree constraints.
module tsense_ripple_cnt #(
    parameter W = 14
) (
    input  wire         clk,
    input  wire         clr,   // async clear, active high
    input  wire         en,
    output wire [W-1:0] q
);
    reg [W-1:0] r;

    always @(posedge clk or posedge clr) begin
        if (clr)     r[0] <= 1'b0;
        else if (en) r[0] <= ~r[0];
    end

    genvar i;
    generate
        for (i = 1; i < W; i = i + 1) begin : g_bit
            always @(negedge r[i-1] or posedge clr) begin
                if (clr) r[i] <= 1'b0;
                else     r[i] <= ~r[i];
            end
        end
    endgenerate

    assign q = r;
endmodule
