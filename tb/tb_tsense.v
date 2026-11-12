// Testbench: 2-point and 3-point calibration, each followed by a -40..125 degC sweep.
// Select process corner with -DCORNER_SS / _FF / _SF / _FS (default tt).
// Writes tb_results_<corner>.csv
`timescale 1ps/1fs
module tb_tsense;
    real temp_c, f_ctat_mhz, f_ptat_mhz;

`ifdef CORNER_SS
    `include "ro_table_ss.vh"
    localparam CNAME = "ss";
`elsif CORNER_FF
    `include "ro_table_ff.vh"
    localparam CNAME = "ff";
`elsif CORNER_SF
    `include "ro_table_sf.vh"
    localparam CNAME = "sf";
`elsif CORNER_FS
    `include "ro_table_fs.vh"
    localparam CNAME = "fs";
`else
    `include "ro_table_tt.vh"
    localparam CNAME = "tt";
`endif

    reg clk = 0, rst_n = 1, start = 0, cfg_we = 0;
    reg [2:0] cfg_addr = 0;
    reg [15:0] cfg_data = 0;
    wire signed [15:0] temp_x16;
    wire [13:0] raw;
    wire valid, busy, err;

    always #50000 clk = ~clk;          // 10 MHz reference clock

    tsense_top dut (.clk(clk), .rst_n(rst_n), .start(start), .cfg_we(cfg_we),
        .cfg_addr(cfg_addr), .cfg_data(cfg_data), .temp_x16(temp_x16),
        .raw(raw), .valid(valid), .busy(busy), .err(err));

    task set_temp(input real t);
        begin
            temp_c = t; f_ctat_mhz = f_ctat(t); f_ptat_mhz = f_ptat(t);
        end
    endtask

    task convert;
        begin
            @(negedge clk) start = 1; @(negedge clk) start = 0;
            @(posedge valid or posedge err);
            if (err) begin $display("ERROR: timeout"); $finish; end
            @(negedge clk);
        end
    endtask

    task wr(input [2:0] a, input [15:0] d);
        begin
            @(negedge clk) begin cfg_addr = a; cfg_data = d; cfg_we = 1; end
            @(negedge clk) cfg_we = 0;
        end
    endtask

    // slope in Q0.16 degC/code between two calibration points
    function integer kq16(input integer t0, input integer t1, input integer c0, input integer c1);
        kq16 = ((t1 - t0) * 65536 + (c1 - c0) / 2) / (c1 - c0);
    endfunction

    integer fd, c_a, c_b, c_c, t_a, t_b, t_c;
    real    emax2, emax3;

    // sweep -40..125 and return max |error|
    task sweep(input [8*8-1:0] mode, output real emax);
        real t, meas, e;
        begin
            emax = 0.0;
            for (t = -40.0; t <= 125.0; t = t + 5.0) begin
                set_temp(t); convert;
                meas = temp_x16 / 16.0; e = meas - t;
                if ((e < 0 ? -e : e) > emax) emax = (e < 0 ? -e : e);
                $display("[%s %0s] T=%7.2f C  raw=%5d  Tmeas=%8.3f C  err=%7.3f C",
                         CNAME, mode, t, raw, meas, e);
                $fdisplay(fd, "%s,%0s,%0.2f,%0.3f,%0.3f,%0d,%0.4f,%0.4f",
                          CNAME, mode, t, f_ctat_mhz, f_ptat_mhz, raw, meas, e);
            end
        end
    endtask

    initial begin
        $dumpfile({"tb_tsense_", CNAME, ".vcd"});
        $dumpvars(0, tb_tsense);
        set_temp(27.0);
        #1000   rst_n = 0;          // clean reset edge after time 0
        #200000 rst_n = 1;

        fd = $fopen({"tb_results_", CNAME, ".csv"}, "w");
        $fdisplay(fd, "corner,cal_mode,T_true_C,f_ctat_MHz,f_ptat_MHz,raw,T_meas_C,error_C");

        // measure the three calibration points (as in a temperature chamber)
        t_a = -40; t_b = 40; t_c = 125;
        set_temp(t_a); convert; c_a = raw;
        set_temp(t_b); convert; c_b = raw;
        set_temp(t_c); convert; c_c = raw;
        $display("[%s] calibration counts: C(%0d)=%0d  C(%0d)=%0d  C(%0d)=%0d",
                 CNAME, t_a, c_a, t_b, c_b, t_c, c_c);

        // ---- 2-point (single line from TA to TC) ----
        wr(3'd0, c_a[15:0]); wr(3'd1, kq16(t_a, t_c, c_a, c_c)); wr(3'd2, t_a * 16);
        wr(3'd3, 16'hFFFF);
        sweep("2pt", emax2);

        // ---- 3-point (two segments, break at TB) ----
        wr(3'd1, kq16(t_a, t_b, c_a, c_b));
        wr(3'd3, c_b[15:0]); wr(3'd4, kq16(t_b, t_c, c_b, c_c)); wr(3'd5, t_b * 16);
        sweep("3pt", emax3);

        $fclose(fd);
        $display("[%s] RESULT: max |error|  2-point = %0.3f C   3-point = %0.3f C",
                 CNAME, emax2, emax3);
        $finish;
    end
endmodule
