`timescale 1ns / 1ps

module togawa_pipeline (
    input  logic        clk_i,
    input  logic        rst_ni,

    // IF: cache valid/data describe the current word-indexed PC.
    output logic        icache_req_val_o,
    output logic [15:0] pc_o,
    input  logic        icache_req_rdy_i,

    input  logic        icache_val_i,
    input  logic [15:0] icache_inst_i,
    output logic        icache_rdy_o,

    spi_ram_if.if_src   spi_o,

    output logic        halt
);

    logic [63:0] reg_d, reg_q;
    logic reg_load;
    logic [15:0] reg_addr_q;
    logic [15:0] load_addr;
    logic reg_dirty_d, reg_dirty_q;

    // Instruction decode crosses the existing IFID -> EXMEM boundary.
    typedef enum logic [1:0] {
        OP_HALT        = 2'b00,
        OP_TOGA        = 2'b01,
        OP_WA_DIRECT   = 2'b10,
        OP_WA_INDIRECT = 2'b11
    } opcode_t;
    opcode_t opcode_d, opcode_q;
    logic inst_valid_d, inst_valid_q;
    logic [63:0] mask_d, mask_q;
    logic [15:0] branch_offset_d, branch_offset_q;
    logic [15:0] direct_addr_d, direct_addr_q;

    logic [15:0] pc_d, pc_q;
    logic halt_d, halt_q;
    logic stall, flush;

    typedef enum logic { IDLE, WAIT } spi_state_t;
    spi_state_t spi_state_d, spi_state_q;

    // WA operands index eight-byte words; addresses wrap in the 64 KiB SPI space.
    assign load_addr = opcode_q == OP_WA_INDIRECT ? {reg_q[12:0], 3'b000}
                                                : direct_addr_q;
    assign pc_o = pc_q;
    assign halt = halt_q;
    assign spi_o.req_is_inst = 1'b0;
    wire _unused_ok = &{1'b0, icache_req_rdy_i};

    always_comb begin : ifid_stage
        pc_d = pc_q;
        if (icache_inst_i == 16'h0)
            opcode_d = OP_HALT;
        else if (!icache_inst_i[15])
            opcode_d = OP_TOGA;
        else
            opcode_d = icache_inst_i[14] ? OP_WA_INDIRECT : OP_WA_DIRECT;
        mask_d = 64'h1 << icache_inst_i[14:9];
        branch_offset_d = { {7{icache_inst_i[8]}}, icache_inst_i[8:0] };
        direct_addr_d = {icache_inst_i[12:0], 3'b000};
        inst_valid_d = inst_valid_q && stall;

        // icache_req_val_o = !stall && !flush && !halt_d;
        // icache_rdy_o = icache_req_val_o;
        icache_req_val_o = !inst_valid_q && !halt_q;
  icache_rdy_o     = icache_req_val_o;

        if (flush) begin
            // IFID already advanced PC past the executing instruction.
            pc_d = pc_q + branch_offset_q;
            inst_valid_d = 1'b0;
        end else if (icache_val_i && icache_rdy_o) begin
            pc_d = pc_q + 16'd1;
            inst_valid_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin : ifid_exmem_rf
        if (!rst_ni) begin
            pc_q <= 16'd0;
            opcode_q <= OP_HALT;
            mask_q <= 64'd0;
            branch_offset_q <= 16'd0;
            direct_addr_q <= 16'd0;
            inst_valid_q <= 1'b0;
        end else begin
            pc_q <= pc_d;
            if (icache_val_i && icache_rdy_o) begin
                opcode_q <= opcode_d;
                mask_q <= mask_d;
                branch_offset_q <= branch_offset_d;
                direct_addr_q <= direct_addr_d;
            end
            inst_valid_q <= inst_valid_d;
        end
    end

    always_comb begin : exmem_stage
        reg_d = reg_q;
        reg_load = 1'b0;
        reg_dirty_d = reg_dirty_q;
        spi_state_d = spi_state_q;
        halt_d = halt_q;

        spi_o.req_val = 1'b0;
        spi_o.req_we = reg_dirty_q;
        spi_o.req_addr = reg_dirty_q ? reg_addr_q : load_addr;
        spi_o.req_wdata = reg_q;
        spi_o.rsp_rdy = 1'b0;
        stall = 1'b0;
        flush = 1'b0;

        if (inst_valid_q) begin
            case (opcode_q)
                OP_HALT: begin
                    stall = reg_dirty_q;
                    if (!reg_dirty_q)
                        halt_d = 1'b1;
                end
                OP_WA_DIRECT, OP_WA_INDIRECT: stall = 1'b1;
                OP_TOGA: begin
                    reg_d = reg_q ^ mask_q;
                    reg_dirty_d = 1'b1;
                    // The old bit being one means the toggled bit is zero.
                    // TimingFix01: This is correct but not efficient
                    // flush = reg_q[inst_q[14:9]] && inst_q[8:0] != 9'd0;
                    // The fix is we move whole mask calc to previous stage
                    flush = |(reg_q & mask_q);
                end
            endcase

            if (stall) begin
                case (spi_state_q)
                    IDLE: begin
                        spi_o.req_val = 1'b1;
                        if (spi_o.req_rdy)
                            spi_state_d = WAIT;
                    end
                    WAIT: begin
                        spi_o.rsp_rdy = 1'b1;
                        if (spi_o.rsp_val) begin
                            spi_state_d = IDLE;
                            if (reg_dirty_q) begin
                                reg_dirty_d = 1'b0;
                            end else begin
                                reg_load = 1'b1;
                                stall = 1'b0;
                            end
                        end
                    end
                endcase
            end
        end
    end

    always_ff @(posedge clk_i) begin : exmem_rf
        if (!rst_ni) begin
            reg_q <= 64'd0;
            reg_addr_q <= 16'd0;
            reg_dirty_q <= 1'b0;
            spi_state_q <= IDLE;
            halt_q <= 1'b0;
        end else begin
            if (reg_load) begin
                reg_q <= spi_o.rsp_rdata;
                reg_addr_q <= spi_o.req_addr;
            end else
                reg_q <= reg_d;
            reg_dirty_q <= reg_dirty_d;
            spi_state_q <= spi_state_d;
            halt_q <= halt_d;
        end
    end

endmodule

module reset_sync (
    input  logic clk_i,
    input  logic rst_ni,
    output logic rst_sync_ni
);

    logic [1:0] sync_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            sync_q <= 2'b00;
        else
            sync_q <= {sync_q[0], 1'b1};
    end

    assign rst_sync_ni = sync_q[1];

endmodule
