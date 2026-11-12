// PTAT ring oscillator: NAND2 enable + 10 x NOR4 (inputs tied).
// Stacked PMOS pull-up -> frequency INCREASES with temperature.
// Hand-instantiated sky130 standard cells, kept through synthesis.
// Explicit instances (no buses) keep net names simple for layout tools.
// For RTL simulation, tb/ro_models.v replaces this file.
module tsense_ro_ptat (
    input  wire en,
    output wire clk_out
);
    wire n0, n1, n2, n3, n4, n5, n6, n7, n8, n9, n10;

    (* keep *) sky130_fd_sc_hd__nand2_1 u_en (.A(en), .B(n10), .Y(n0));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d0 (.A(n0), .B(n0), .C(n0), .D(n0), .Y(n1));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d1 (.A(n1), .B(n1), .C(n1), .D(n1), .Y(n2));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d2 (.A(n2), .B(n2), .C(n2), .D(n2), .Y(n3));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d3 (.A(n3), .B(n3), .C(n3), .D(n3), .Y(n4));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d4 (.A(n4), .B(n4), .C(n4), .D(n4), .Y(n5));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d5 (.A(n5), .B(n5), .C(n5), .D(n5), .Y(n6));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d6 (.A(n6), .B(n6), .C(n6), .D(n6), .Y(n7));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d7 (.A(n7), .B(n7), .C(n7), .D(n7), .Y(n8));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d8 (.A(n8), .B(n8), .C(n8), .D(n8), .Y(n9));
    (* keep *) sky130_fd_sc_hd__nor4_1 u_d9 (.A(n9), .B(n9), .C(n9), .D(n9), .Y(n10));

    (* keep *) sky130_fd_sc_hd__clkbuf_2 u_ob (.A(n0), .X(clk_out));
endmodule
