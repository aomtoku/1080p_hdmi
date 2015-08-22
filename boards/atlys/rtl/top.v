module top (
	input  wire                        SYS_CLK,
	input  wire                        RSTBTN_,
	output wire                  [3:0] TMDS,
	output wire                  [3:0] TMDSB
);


wire clk100;
IBUFG sysclk_buf (.I(SYS_CLK), .O(clk100));

reg clk_buf;
assign clk50m = clk_buf;
always @(posedge clk100) clk_buf <= ~clk_buf;

BUFG clk50m_bufgbufg (.I(clk50m), .O(clk50m_bufg));
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

/*
 *  PLL 148.5MHz Generation
 *  Multiply = 199
 *  Divide   = 67
 */
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
BUFG pclkx2bufg (.I(pllclk2), .O(pclkx2));

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


wire hdmi_hsync_int, hdmi_vsync_int;
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
    .hsync(hdmi_hsync_int), //output
    .hblnk(bgnd_hblnk), //output
    .tc_vsblnk(tc_vsblnk), //input
    .tc_vssync(tc_vssync), //input
    .tc_vesync(tc_vesync), //input
    .tc_veblnk(tc_veblnk), //input
    .vcount(bgnd_vcount), //output
    .vsync(hdmi_vsync_int), //output
    .vblnk(bgnd_vblnk), //output
    .restart(reset),
    .clk(pclk)
);

/* ------ V/H SYNC and DE generator ------ */
assign active = !bgnd_hblnk && !bgnd_vblnk;

reg active_q;
reg vsync, hsync;
reg hdmi_hsync, hdmi_vsync;
reg vde;
wire [7:0] red_data, green_data, blue_data;

always @ (posedge pclk) begin
	hsync <= hdmi_hsync_int ^ hvsync_polarity ;
	vsync <= hdmi_vsync_int ^ hvsync_polarity ;
	hdmi_hsync <= hsync;
	hdmi_vsync <= vsync;
	
	active_q <= active;
	vde <= active_q;
end

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
	.hsync           (hdmi_hsync),
	.vsync           (hdmi_vsync),
	.vde             (vde),
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
	.o_r       (red_data),
	.o_g       (green_data),
	.o_b       (blue_data)
);

endmodule

