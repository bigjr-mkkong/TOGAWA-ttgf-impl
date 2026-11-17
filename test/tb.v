`default_nettype none
`timescale 1ns / 1ps

module tb ();
  reg clk_i;
  reg rst_ni;
  wire [7:0] ui_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  wire spi_cs_n = uo_out[0];
  wire spi_sclk = uo_out[1];
  wire spi_mosi = uo_out[2];
  wire halt_o = uo_out[3];
  wire spi_miso;
`ifdef GL_TEST
  supply1 VPWR;
  supply0 VGND;
`endif

  assign ui_in = {7'b0, spi_miso};

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
  end

  tt_um_bigjr_mkkong user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in(ui_in),
      .uo_out(uo_out),
      .uio_in(8'b0),
      .uio_out(uio_out),
      .uio_oe(uio_oe),
      .ena(1'b1),
      .clk(clk_i),
      .rst_n(rst_ni)
  );

  spi_ram_model ram (
      .cs_n(spi_cs_n),
      .sclk(spi_sclk),
      .mosi(spi_mosi),
      .miso(spi_miso)
  );
endmodule
