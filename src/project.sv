/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

module tt_um_bigjr_mkkong (
    input  logic [7:0] ui_in,    // Dedicated inputs
    output logic [7:0] uo_out,   // Dedicated outputs
    input  logic [7:0] uio_in,   // IOs: Input path
    output logic [7:0] uio_out,  // IOs: Output path
    output logic [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  logic       ena,      // always 1 when the design is powered, so you can ignore it
    input  logic       clk,      // clock
    input  logic       rst_n     // reset_n - low to reset
);

    logic spi_cs_no;
    logic spi_sclk_o;
    logic spi_mosi_o;
    logic halt_o;

    // Dedicated outputs
    assign uo_out[0] = spi_cs_no;
    assign uo_out[1] = spi_sclk_o;
    assign uo_out[2] = spi_mosi_o;
    assign uo_out[3] = halt_o;
    assign uo_out[7:4] = 4'b0000;

    // No bidirectional pins needed
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Unused signals
    wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

    // Existing TOGAWA CPU
    top_module top_module_inst (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .spi_cs_no   (spi_cs_no),
        .spi_sclk_o  (spi_sclk_o),
        .spi_mosi_o  (spi_mosi_o),
        .spi_miso_i  (ui_in[0]),
        .halt_o      (halt_o)
    );


endmodule
