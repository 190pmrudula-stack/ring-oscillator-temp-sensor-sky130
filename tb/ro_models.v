// Behavioural ring-oscillator models for RTL simulation ONLY.
// Frequency follows tb_tsense.f_ctat_mhz / f_ptat_mhz, which the
// testbench computes from the Ngspice results for the chosen temperature.
// When disabled, output sits high (NAND2 enable output = 1), as in silicon.
`timescale 1ps/1fs
module tsense_ro_ctat (input wire en, output reg clk_out);
    initial clk_out = 1'b1;
    always begin
        wait (en === 1'b1);
        #(500000.0 / tb_tsense.f_ctat_mhz) clk_out = ~clk_out;  // half period, ps
        if (en !== 1'b1) clk_out = 1'b1;
    end
endmodule

module tsense_ro_ptat (input wire en, output reg clk_out);
    initial clk_out = 1'b1;
    always begin
        wait (en === 1'b1);
        #(500000.0 / tb_tsense.f_ptat_mhz) clk_out = ~clk_out;
        if (en !== 1'b1) clk_out = 1'b1;
    end
endmodule
