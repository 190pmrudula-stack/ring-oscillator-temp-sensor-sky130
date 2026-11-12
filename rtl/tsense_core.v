// Ratio-metric measurement + control FSM + two-point linear calibration.
//
//  - The CTAT oscillator (ro_n_clk) defines the window: 2^M of its cycles.
//  - The PTAT oscillator (ro_p_clk) is counted during that window.
//  - raw = 2^M * f_ptat / f_ctat   (ratio -> process/supply partly cancel)
//  - Piecewise-linear calibration with two segments (3-point calibration):
//      seg A (raw <  CB): temp = TA + ((raw - CA) * KA) >>> 12
//      seg B (raw >= CB): temp = TB + ((raw - CB) * KB) >>> 12
//    temp in 1/16 degC, K in Q0.16 degC/code.  Set CB = 16'hFFFF for a
//    plain 2-point (single-segment) calibration.
module tsense_core #(
    parameter M  = 12,          // window = 2^M CTAT cycles
    parameter CW = 14           // PTAT counter width
) (
    input  wire               clk,        // reference/control clock
    input  wire               rst_n,
    input  wire               start,      // one-shot conversion request
    input  wire               cont,       // continuous conversions
    input  wire        [15:0] cal_ca,     // raw count at TA
    input  wire        [15:0] cal_ka,     // slope seg A, Q0.16 degC/code
    input  wire signed [15:0] cal_ta,     // TA in 1/16 degC
    input  wire        [15:0] cal_cb,     // raw count at TB (segment break)
    input  wire        [15:0] cal_kb,     // slope seg B, Q0.16 degC/code
    input  wire signed [15:0] cal_tb,     // TB in 1/16 degC
    output reg                ro_en,      // enables both oscillators
    input  wire               ro_n_clk,   // CTAT oscillator
    input  wire               ro_p_clk,   // PTAT oscillator
    output reg  signed [15:0] temp_x16,   // temperature, 1/16 degC
    output reg       [CW-1:0] raw,        // raw PTAT count (for calibration)
    output reg                valid,      // 1-cycle pulse when result ready
    output wire               busy,
    output reg                err         // timeout (oscillator dead)
);
    localparam S_IDLE = 3'd0, S_EN = 3'd1, S_RUN = 3'd2,
               S_SETTLE = 3'd3, S_CAP = 3'd4, S_CALC = 3'd5;

    wire rst = ~rst_n;
    reg  [2:0]  state;
    reg  [15:0] timer;
    reg         clr;      // clears the oscillator-domain logic
    reg         run;      // request window (ref domain)

    wire clr_ro = rst | clr;

    // ---------------- CTAT (window) domain ----------------
    wire         run_n, done_n;
    wire [M:0]   cnt_n;
    reg          win;

    tsense_sync2 u_s_run (.clk(ro_n_clk), .rst(clr_ro), .d(run), .q(run_n));
    tsense_ripple_cnt #(.W(M+1)) u_cnt_n (
        .clk(ro_n_clk), .clr(clr_ro), .en(win), .q(cnt_n));
    tsense_sync2 u_s_done (.clk(ro_n_clk), .rst(clr_ro), .d(cnt_n[M]), .q(done_n));

    always @(posedge ro_n_clk or posedge clr_ro) begin
        if (clr_ro) win <= 1'b0;
        else        win <= run_n & ~done_n;
    end

    // ---------------- PTAT (counted) domain ----------------
    wire          win_p;
    wire [CW-1:0] cnt_p;

    tsense_sync2 u_s_win (.clk(ro_p_clk), .rst(clr_ro), .d(win), .q(win_p));
    tsense_ripple_cnt #(.W(CW)) u_cnt_p (
        .clk(ro_p_clk), .clr(clr_ro), .en(win_p), .q(cnt_p));

    // ---------------- reference domain ----------------
    wire done_ref;
    tsense_sync2 u_s_dref (.clk(clk), .rst(rst), .d(done_n), .q(done_ref));

    // calibration arithmetic (one shared multiplier)
    wire               seg_b = ({2'b00, raw} >= cal_cb);
    wire        [15:0] c_sel = seg_b ? cal_cb : cal_ca;
    wire        [15:0] k_sel = seg_b ? cal_kb : cal_ka;
    wire signed [15:0] t_sel = seg_b ? cal_tb : cal_ta;
    wire signed [16:0] diff = $signed({3'b000, raw}) - $signed({1'b0, c_sel});
    wire signed [33:0] prod = diff * $signed({1'b0, k_sel});
    wire signed [21:0] tcal = t_sel + (prod >>> 12);
    wire signed [15:0] tsat = (tcal >  22'sd32767) ? 16'sh7FFF :
                              (tcal < -22'sd32768) ? 16'sh8000 : tcal[15:0];

    assign busy = (state != S_IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE; timer <= 16'd0; clr <= 1'b1; run <= 1'b0;
            ro_en <= 1'b0; temp_x16 <= 16'sd0; raw <= {CW{1'b0}};
            valid <= 1'b0; err <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
            S_IDLE: begin
                clr <= 1'b1; run <= 1'b0; ro_en <= 1'b0; timer <= 16'd0;
                if (start | cont) begin err <= 1'b0; state <= S_EN; end
            end
            S_EN: begin                    // start oscillators, let them settle
                clr <= 1'b0; ro_en <= 1'b1; timer <= timer + 16'd1;
                if (timer == 16'd7) begin timer <= 16'd0; run <= 1'b1; state <= S_RUN; end
            end
            S_RUN: begin                   // wait for 2^M CTAT cycles
                timer <= timer + 16'd1;
                if (done_ref) begin
                    run <= 1'b0; timer <= 16'd0; state <= S_SETTLE;
                end else if (timer == 16'hFFFF) begin
                    err <= 1'b1; state <= S_IDLE;
                end
            end
            S_SETTLE: begin                // let PTAT window close & ripple settle
                timer <= timer + 16'd1;
                if (timer == 16'd3) state <= S_CAP;
            end
            S_CAP: begin
                raw <= cnt_p; ro_en <= 1'b0; state <= S_CALC;
            end
            S_CALC: begin
                temp_x16 <= tsat; valid <= 1'b1; state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
