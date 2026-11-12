// Top level: dual ring-oscillator temperature sensor with digital readout.
// Config registers (write cfg_data to cfg_addr with cfg_we on rising clk):
//   0 : CA   raw count at calibration temperature TA
//   1 : KA   slope of segment A, Q0.16 degC per code
//   2 : TA   calibration temperature A, signed, 1/16 degC
//   3 : CB   raw count at TB (start of segment B); 16'hFFFF = 2-point mode
//   4 : KB   slope of segment B, Q0.16 degC per code
//   5 : TB   calibration temperature B, signed, 1/16 degC
//   6 : bit0 = continuous-conversion mode
module tsense_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        cfg_we,
    input  wire [2:0]  cfg_addr,
    input  wire [15:0] cfg_data,
    output wire [15:0] temp_x16,   // signed, 1/16 degC
    output wire [13:0] raw,        // raw ratio count
    output wire        valid,
    output wire        busy,
    output wire        err
);
    // Reset defaults = typical-corner (tt) calibration from simulation
    localparam [15:0] DEF_CA = 16'd1622;   // C(-40 C)
    localparam [15:0] DEF_KA = 16'd13833;  // (40-(-40))/(2001-1622) in Q0.16
    localparam [15:0] DEF_TA = 16'hFD80;  // -40 C x16
    localparam [15:0] DEF_CB = 16'd2001;   // C(40 C)
    localparam [15:0] DEF_KB = 16'd16336;  // (125-40)/(2342-2001) in Q0.16
    localparam [15:0] DEF_TB = 16'd640;    // 40 C x16

    reg [15:0] ca_r, ka_r, ta_r, cb_r, kb_r, tb_r;
    reg        cont_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ca_r <= DEF_CA; ka_r <= DEF_KA; ta_r <= DEF_TA;
            cb_r <= DEF_CB; kb_r <= DEF_KB; tb_r <= DEF_TB; cont_r <= 1'b0;
        end else if (cfg_we) begin
            case (cfg_addr)
                3'd0: ca_r   <= cfg_data;
                3'd1: ka_r   <= cfg_data;
                3'd2: ta_r   <= cfg_data;
                3'd3: cb_r   <= cfg_data;
                3'd4: kb_r   <= cfg_data;
                3'd5: tb_r   <= cfg_data;
                3'd6: cont_r <= cfg_data[0];
                default: ;
            endcase
        end
    end

    wire ro_en, ro_n_clk, ro_p_clk;

    tsense_ro_ctat u_ro_n (.en(ro_en), .clk_out(ro_n_clk));
    tsense_ro_ptat u_ro_p (.en(ro_en), .clk_out(ro_p_clk));

    tsense_core #(.M(12), .CW(14)) u_core (
        .clk(clk), .rst_n(rst_n), .start(start), .cont(cont_r),
        .cal_ca(ca_r), .cal_ka(ka_r), .cal_ta(ta_r),
        .cal_cb(cb_r), .cal_kb(kb_r), .cal_tb(tb_r),
        .ro_en(ro_en), .ro_n_clk(ro_n_clk), .ro_p_clk(ro_p_clk),
        .temp_x16(temp_x16), .raw(raw), .valid(valid), .busy(busy), .err(err));
endmodule
