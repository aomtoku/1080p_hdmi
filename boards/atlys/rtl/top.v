module top (
	input  wire                        SYS_CLK,
	input  wire                        RSTBTN_,
//	input  wire                  [3:0] RX0_TMDS,
//	input  wire                  [3:0] RX0_TMDSB,
//	input  wire                        RX0_SCL,
//	inout  wire                        RX0_SDA,
	output wire                  [3:0] TMDS,
	output wire                  [3:0] TMDSB,
    input  wire                        SW,
	output wire                  [7:0] LED
);


wire clk100;
IBUFG sysclk_buf (.I(SYS_CLK), .O(clk100));

reg clk_buf;
assign clk50m = clk_buf;
always @(posedge clk100) clk_buf <= ~clk_buf;

BUFG clk50m_bufgbufg (.I(clk50m), .O(clk50m_bufg));
///* --------- Switching Logic -------------- */
//wire  sws_sync;
//synchro #(.INITIALIZE("LOGIC0"))
//synchro_sws_0 (.async(SW),.sync(sws_sync),.clk(clk50m_bufg));
//reg  sws_sync_q;
//always @ (posedge clk50m_bufg) sws_sync_q <= sws_sync;
//wire sw0_rdy;
//
// debnce debsw0 (
//    .sync(sws_sync_q),
//    .debnced(sw0_rdy),
//    .clk(clk50m_bufg)
// );
//
//wire pclk;
//wire sws_clk;
//synchro #(.INITIALIZE("LOGIC0"))
//clk_sws_0 (.async(SW),.sync(sws_clk),.clk(pclk));
//
//reg  [3:0] sws_clk_sync; //clk synchronous output
//always @(posedge pclk) begin
//    sws_clk_sync <= sws_clk;
//end


/* --------- Power UP logic -------------- */
wire pclk_lckd;
wire pwrup;
SRL16E #(.INIT(16'h1)) pwrup_0 (
	.Q(pwrup),
	.A0(1'b1),
	.A1(1'b1),
	.A2(1'b1),
	.A3(1'b1),
	.CE(pclk_lckd),
	.CLK(clk50m_bufg),
	.D(1'b0)
);

reg switch = 1'b0;
//always @ (posedge clk50m_bufg) switch <= pwrup | sw0_;
always @ (posedge clk50m_bufg) switch <= pwrup;

wire gopclk;
SRL16E SRL16E_0 (
  .Q(gopclk),
  .A0(1'b1),
  .A1(1'b1),
  .A2(1'b1),
  .A3(1'b1),
  .CE(1'b1),
  .CLK(clk50m_bufg),
  .D(switch)
);

//1920x1080@60Hz
parameter HPIXELS_HDTV1080P = 12'd1920;  //Horizontal Live Pixels
parameter VLINES_HDTV1080P  = 12'd1080;  //Vertical Live ines
parameter HFNPRCH_HDTV1080P = 12'd88;    //Horizontal Front Portch
parameter HSYNCPW_HDTV1080P = 12'd44;    //HSYNC Pulse Width
parameter HBKPRCH_HDTV1080P = 12'd148;   //Horizontal Back Portch
parameter VFNPRCH_HDTV1080P = 12'd4;     //Vertical Front Portch
parameter VSYNCPW_HDTV1080P = 12'd5;     //VSYNC Pulse Width
parameter VBKPRCH_HDTV1080P = 12'd36;    //Vertical Back Portch


wire [11:0] tc_hsblnk = HPIXELS_HDTV1080P - 12'd1;
wire [11:0] tc_hssync = HPIXELS_HDTV1080P - 12'd1 + HFNPRCH_HDTV1080P;
wire [11:0] tc_hesync = HPIXELS_HDTV1080P - 12'd1 + HFNPRCH_HDTV1080P + HSYNCPW_HDTV1080P;
wire [11:0] tc_heblnk = HPIXELS_HDTV1080P - 12'd1 + HFNPRCH_HDTV1080P + HSYNCPW_HDTV1080P + HBKPRCH_HDTV1080P;
wire [11:0] tc_vsblnk = VLINES_HDTV1080P  - 12'd1;
wire [11:0] tc_vssync = VLINES_HDTV1080P  - 12'd1 + VFNPRCH_HDTV1080P;
wire [11:0] tc_vesync = VLINES_HDTV1080P  - 12'd1 + VFNPRCH_HDTV1080P + VSYNCPW_HDTV1080P;
wire [11:0] tc_veblnk = VLINES_HDTV1080P  - 12'd1 + VFNPRCH_HDTV1080P + VSYNCPW_HDTV1080P + VBKPRCH_HDTV1080P;
wire hvsync_polarity  = 1'b0;

wire [7:0] pclk_M = 8'd199 - 8'd1;
wire [7:0] pclk_D = 8'd67 - 8'd1;

/* ------------- DCM_CLKGEN SPI controller --------------- */

wire progdone, progen, progdata;
dcmspi dcmspi_0 (
  .RST(switch),          //Synchronous Reset
  .PROGCLK(clk50m_bufg), //SPI clock
  .PROGDONE(progdone),   //DCM is ready to take next command
  .DFSLCKD(pclk_lckd),
  .M(pclk_M),            //DCM M value
  .D(pclk_D),            //DCM D value
  .GO(gopclk),           //Go programme the M and D value into DCM(1 cycle pulse)
  .BUSY(busy),
  .PROGEN(progen),       //SlaveSelect,
  .PROGDATA(progdata)    //CommandData
);

/* -------------- DCM_CLKGEN to generate a pixel clock with a variable frequency ------*/
wire          clkfx;
DCM_CLKGEN #(
  .CLKFX_DIVIDE (21),
  .CLKFX_MULTIPLY (31),
  .CLKIN_PERIOD(20.000)
)
PCLK_GEN_INST (
  .CLKFX(clkfx),
  .CLKFX180(),
  .CLKFXDV(),
  .LOCKED(pclk_lckd),
  .PROGDONE(progdone),
  .STATUS(),
  .CLKIN(clk50m),
  .FREEZEDCM(1'b0),
  .PROGCLK(clk50m_bufg),
  .PROGDATA(progdata),
  .PROGEN(progen),
  .RST(1'b0)
);


wire pllclk0, pllclk1, pllclk2;
wire pclkx2, pclkx10, pll_lckd;
wire clkfbout;

/* --------- Pixel Rate clock buffer ---------- */
BUFG pclkbufg (.I(pllclk1), .O(pclk));

//////////////////////////////////////////////////////////////////
// 2x pclk is going to be used to drive OSERDES2
// on the GCLK side
//////////////////////////////////////////////////////////////////
BUFG pclkx2bufg (.I(pllclk2), .O(pclkx2));

//////////////////////////////////////////////////////////////////
// 10x pclk is used to drive IOCLK network so a bit rate reference
// can be used by OSERDES2
//////////////////////////////////////////////////////////////////
PLL_BASE # (
	.CLKIN_PERIOD(13),
	.CLKFBOUT_MULT(10), //set VCO to 10x of CLKIN
	.CLKOUT0_DIVIDE(1),
	.CLKOUT1_DIVIDE(10),
	.CLKOUT2_DIVIDE(5),
	.COMPENSATION("INTERNAL")
) PLL_OSERDES (
	.CLKFBOUT(clkfbout),
	.CLKOUT0(pllclk0),
	.CLKOUT1(pllclk1),
	.CLKOUT2(pllclk2),
	.CLKOUT3(),
	.CLKOUT4(),
	.CLKOUT5(),
	.LOCKED(pll_lckd),
	.CLKFBIN(clkfbout),
	.CLKIN(clkfx),
	.RST(~pclk_lckd)
);

wire serdesstrobe;
wire bufpll_lock;
wire reset;
BUFPLL #(.DIVIDE(5)) ioclk_buf (.PLLIN(pllclk0), .GCLK(pclkx2), .LOCKED(pll_lckd),
         .IOCLK(pclkx10), .SERDESSTROBE(serdesstrobe), .LOCK(bufpll_lock));
synchro #(.INITIALIZE("LOGIC1"))
synchro_reset (.async(!pll_lckd),.sync(reset),.clk(pclk));


wire VGA_HSYNC_INT, VGA_VSYNC_INT;
wire   [11:0] bgnd_hcount;
wire          bgnd_hsync;
wire          bgnd_hblnk;
wire   [11:0] bgnd_vcount;
wire          bgnd_vsync;
wire          bgnd_vblnk;


timing timing_inst (
    .tc_hsblnk(tc_hsblnk), //input
    .tc_hssync(tc_hssync), //input
    .tc_hesync(tc_hesync), //input
    .tc_heblnk(tc_heblnk), //input
    .hcount(bgnd_hcount), //output
    .hsync(VGA_HSYNC_INT), //output
    .hblnk(bgnd_hblnk), //output
    .tc_vsblnk(tc_vsblnk), //input
    .tc_vssync(tc_vssync), //input
    .tc_vesync(tc_vesync), //input
    .tc_veblnk(tc_veblnk), //input
    .vcount(bgnd_vcount), //output
    .vsync(VGA_VSYNC_INT), //output
    .vblnk(bgnd_vblnk), //output
    .restart(reset),
    .clk(pclk)
);

/* ------ V/H SYNC and DE generator ------ */
assign active = !bgnd_hblnk && !bgnd_vblnk;

reg active_q;
reg vsync, hsync;
reg VGA_HSYNC, VGA_VSYNC;
reg de = 1'b0;

always @ (posedge pclk) begin
	hsync <= VGA_HSYNC_INT ^ hvsync_polarity ;
	vsync <= VGA_VSYNC_INT ^ hvsync_polarity ;
	VGA_HSYNC <= hsync;
	VGA_VSYNC <= vsync;
	
	active_q <= active;
	de <= active_q;
end

  ///////////////////////////////////
  // Video pattern generator:
  //   SMPTE HD Color Bar
  ///////////////////////////////////
wire [7:0] hdc_red, hdc_blue, hdc_green;
wire [7:0] red_data    = hdc_red  ;
wire [7:0] green_data  = hdc_green;
wire [7:0] blue_data   = hdc_blue ;

/* ------------- TMDS Encoder ---------------- */
hdmi_encoder_top enc0 (
	.pclk            (pclk),
	.pclkx2          (pclkx2),
	.pclkx10         (pclkx10),
	.serdesstrobe    (serdesstrobe),
	.rstin           (reset),
	.blue_din        (blue_data),
	.green_din       (green_data),
	.red_din         (red_data),
	.aux0_din        (4'd0),
	.aux1_din        (4'd0),
	.aux2_din        (4'd0),
	.hsync           (VGA_HSYNC),
	.vsync           (VGA_VSYNC),
	.vde             (de),
	.ade             (1'b0),
	.sdata_r         (), // 10bit Red Channel
	.sdata_g         (), // 10bit Green Channel
	.sdata_b         (), // 10bit Blue Channel
	.TMDS            (TMDS),
	.TMDSB           (TMDSB)
);

hdcolorbar clrbar(
	.i_clk_74M (pclk),
	.i_rst     (reset),
	.i_hcnt    (bgnd_hcount),
	.i_vcnt    (bgnd_vcount),
	.baronly   (1'b0),
	.i_format  (2'b00),
	.o_r       (hdc_red),
	.o_g       (hdc_green),
	.o_b       (hdc_blue)
);

/* --------------- EDID instance ---------------- */
`ifdef DECODE
i2c_edid edid0_inst (
   .clk(clk100),
   .rst(~RSTBTN_),
   .scl(RX0_SCL),
   .sda(RX0_SDA)
);

/* --------------- Decoder Port0 ---------------- */
wire        rx0_tmdsclk;
wire        rx0_pclkx10, rx0_pllclk0;
wire        rx0_plllckd;
wire        rx0_reset;
wire        rx0_serdesstrobe;

wire        rx0_psalgnerr;      // channel phase alignment error
wire [7:0]  rx0_red;      // pixel data out
wire [7:0]  rx0_green;    // pixel data out
wire [7:0]  rx0_blue;     // pixel data out
wire        rx0_de;
wire [29:0] rx0_sdata;
wire        rx0_blue_vld;
wire        rx0_green_vld;
wire        rx0_red_vld;
wire        rx0_blue_rdy;
wire        rx0_green_rdy;
wire        rx0_red_rdy;

hdmi_decoder hdmi_decode0 (
	.tmdsclk_p   (RX0_TMDS[3]) ,  // tmds clock
	.tmdsclk_n   (RX0_TMDSB[3]),  // tmds clock
	.blue_p      (RX0_TMDS[0]) ,  // Blue data in
	.green_p     (RX0_TMDS[1]) ,  // Green data in
	.red_p       (RX0_TMDS[2]) ,  // Red data in
	.blue_n      (RX0_TMDSB[0]),  // Blue data in
	.green_n     (RX0_TMDSB[1]),  // Green data in
	.red_n       (RX0_TMDSB[2]),  // Red data in
	.exrst       (~RSTBTN_)    ,  // external reset input, e.g. reset button
	
	.reset       (rx0_reset)       ,  // rx reset
	.pclk        (rx0_pclk)        ,  // regenerated pixel clock
	.pclkx2      (rx0_pclkx2)      ,  // double rate pixel clock
	.pclkx10     (rx0_pclkx10)     ,  // 10x pixel as IOCLK
	.pllclk0     (rx0_pllclk0)     ,  // send pllclk0 out so it can be fed into a different BUFPLL
	.pllclk1     (rx0_pllclk1)     ,  // PLL x1 output
	.pllclk2     (rx0_pllclk2)     ,  // PLL x2 output
                 
	.pll_lckd    (rx0_plllckd)     ,  // send pll_lckd out so it can be fed into a different BUFPLL
	.serdesstrobe(rx0_tmdsclk)     ,  // BUFPLL serdesstrobe output
	.tmdsclk     (rx0_serdesstrobe),  // TMDS cable clock
                 
	.hsync       (rx0_hsync)       , // hsync data
	.vsync       (rx0_vsync)       , // vsync data
	.ade         ()                , // data enable
	.vde         (rx0_de)          , // data enable

	.blue_vld    (rx0_blue_vld)    ,
	.green_vld   (rx0_green_vld)   ,
	.red_vld     (rx0_red_vld)     ,
	.blue_rdy    (rx0_blue_rdy)    ,
	.green_rdy   (rx0_green_rdy)   ,
	.red_rdy     (rx0_red_rdy)     ,
                                   
	.psalgnerr   (rx0_psalgnerr)   ,
	.debug       ()                ,
                       
	.sdout       (rx0_sdata)       ,
	.aux0        (),
	.aux1        (),
	.aux2        (),
	.red         (rx0_red)         ,      // pixel data out
	.green       (rx0_green)       ,    // pixel data out
	.blue        (rx0_blue)
); 
`endif
assign LED = {5'b11111,pclk_lckd, pll_lckd, de};

endmodule

