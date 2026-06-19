module tope(
    input clk,
    input reset,
    output [3:0] led
);

    // Hardware-safe reset:
    // - reset input is active-high.
    // - startup_reset keeps the CPU in reset for a short time after configuration.
    // - cpu_reset is used everywhere, not only declared and ignored.
    reg [15:0] reset_counter = 16'd0;
    wire startup_reset;
    wire cpu_reset;

    always @(posedge clk) begin
        if (reset)
            reset_counter <= 16'd0;
        else if (reset_counter != 16'hFFFF)
            reset_counter <= reset_counter + 16'd1;
    end

    assign startup_reset = (reset_counter != 16'hFFFF);
    assign cpu_reset = reset | startup_reset;
    // =========================================================
    // CPU FSM States
    // =========================================================

    localparam S_FETCH = 2'b00;
    localparam S_WAIT_INSTR = 2'b01;
    localparam S_EXECUTE = 2'b10;
    localparam S_WAIT_DATA = 2'b11;

    reg [1:0] state;

    // =========================================================
    // Program Counter and Instruction Register
    // =========================================================

    reg [31:0] pc;
    reg [31:0] instruction;

    wire [31:0] pc_plus4;
    assign pc_plus4 = pc + 32'd4;

    // =========================================================
    // Instruction Fields
    // =========================================================

    wire [6:0] opcode;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // =========================================================
    // Control Unit Signals
    // =========================================================

    wire branch;
    wire mem_read;
    wire mem_to_reg;
    wire [1:0] alu_op;
    wire mem_write;
    wire alu_src;
    wire reg_write_ctrl;
    wire jump;

    control_unit CU(
        .instruction(opcode),
        .Branch(branch),
        .MemRead(mem_read),
        .MemtoReg(mem_to_reg),
        .AluOp(alu_op),
        .MemWrite(mem_write),
        .ALUSrc(alu_src),
        .RegWrite(reg_write_ctrl),
        .Jump(jump)
    );

    // =========================================================
    // Immediate Generator
    // =========================================================

    wire [31:0] imm_ext;

    ImmGen IMM(
        .Opcode(opcode),
        .instruction(instruction),
        .ImmExt(imm_ext)
    );

    // =========================================================
    // Register File
    // =========================================================

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] write_data_reg;
    wire cpu_reg_write;

    Reg_File RF(
        .clk(clk),
        .reset(cpu_reset),
        .Regwrite(cpu_reg_write),
        .Rs1(rs1),
        .Rs2(rs2),
        .Rd(rd),
        .Write_data(write_data_reg),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // =========================================================
    // ALU Control
    // =========================================================

    wire [3:0] alu_ctrl;

    ALU_Control ALU_CTRL(
        .funct7(funct7),
        .funct3(funct3),
        .ALUOp(alu_op),
        .ALU_Ctrl(alu_ctrl)
    );

    // =========================================================
    // ALU
    // =========================================================

    wire [31:0] alu_in2;
    wire [31:0] alu_result;
    wire zero;

    assign alu_in2 = alu_src ? imm_ext : read_data2;

    ALU ALU_INST(
        .in1(read_data1),
        .in2(alu_in2),
        .alu_op(alu_ctrl),
        .alu_result(alu_result),
        .zero(zero)
    );

    // =========================================================
    // Branch and Jump Logic
    // =========================================================

    wire is_jalr;
    wire is_lui;
    wire is_auipc;

    wire [31:0] branch_target;
    wire [31:0] jalr_target;
    wire [31:0] auipc_result;
    wire [31:0] next_pc;

    assign is_jalr  = (opcode == 7'b1100111);
    assign is_lui   = (opcode == 7'b0110111);
    assign is_auipc = (opcode == 7'b0010111);

    assign branch_target = pc + imm_ext;
    assign jalr_target   = (read_data1 + imm_ext) & 32'hFFFF_FFFE;
    assign auipc_result  = pc + imm_ext;

    assign next_pc =
        is_jalr ? jalr_target :
        ((jump || (branch && zero)) ? branch_target : pc_plus4);

    // =========================================================
    // Wishbone Master Signals from CPU
    // =========================================================

    wire [31:0] wb_m_adr;
    wire [31:0] wb_m_dat_w;
    wire [31:0] wb_m_dat_r;
    wire        wb_m_we;
    wire [3:0]  wb_m_sel;
    wire        wb_m_cyc;
    wire        wb_m_stb;
    wire        wb_m_ack;

    // =========================================================
    // Store Byte Enable and Store Data Alignment
    // =========================================================

    reg [3:0] store_sel;
    reg [31:0] store_data;

    always @(*) begin
        store_sel  = 4'b1111;
        store_data = read_data2;

        case (funct3)

            // SB
            3'b000: begin
                case (alu_result[1:0])
                    2'b00: begin
                        store_sel  = 4'b0001;
                        store_data = {24'b0, read_data2[7:0]};
                    end

                    2'b01: begin
                        store_sel  = 4'b0010;
                        store_data = {16'b0, read_data2[7:0], 8'b0};
                    end

                    2'b10: begin
                        store_sel  = 4'b0100;
                        store_data = {8'b0, read_data2[7:0], 16'b0};
                    end

                    2'b11: begin
                        store_sel  = 4'b1000;
                        store_data = {read_data2[7:0], 24'b0};
                    end
                endcase
            end

            // SH
            3'b001: begin
                if (alu_result[1] == 1'b0) begin
                    store_sel  = 4'b0011;
                    store_data = {16'b0, read_data2[15:0]};
                end
                else begin
                    store_sel  = 4'b1100;
                    store_data = {read_data2[15:0], 16'b0};
                end
            end

            // SW
            3'b010: begin
                store_sel  = 4'b1111;
                store_data = read_data2;
            end

            default: begin
                store_sel  = 4'b1111;
                store_data = read_data2;
            end
        endcase
    end

    // =========================================================
    // Load Data Extension
    // =========================================================

    reg [31:0] load_data_extended;

    always @(*) begin
        case (funct3)

            // LB
            3'b000: begin
                case (alu_result[1:0])
                    2'b00: load_data_extended = {{24{wb_m_dat_r[7]}},  wb_m_dat_r[7:0]};
                    2'b01: load_data_extended = {{24{wb_m_dat_r[15]}}, wb_m_dat_r[15:8]};
                    2'b10: load_data_extended = {{24{wb_m_dat_r[23]}}, wb_m_dat_r[23:16]};
                    2'b11: load_data_extended = {{24{wb_m_dat_r[31]}}, wb_m_dat_r[31:24]};
                endcase
            end

            // LH
            3'b001: begin
                if (alu_result[1] == 1'b0)
                    load_data_extended = {{16{wb_m_dat_r[15]}}, wb_m_dat_r[15:0]};
                else
                    load_data_extended = {{16{wb_m_dat_r[31]}}, wb_m_dat_r[31:16]};
            end

            // LW
            3'b010: begin
                load_data_extended = wb_m_dat_r;
            end

            // LBU
            3'b100: begin
                case (alu_result[1:0])
                    2'b00: load_data_extended = {24'b0, wb_m_dat_r[7:0]};
                    2'b01: load_data_extended = {24'b0, wb_m_dat_r[15:8]};
                    2'b10: load_data_extended = {24'b0, wb_m_dat_r[23:16]};
                    2'b11: load_data_extended = {24'b0, wb_m_dat_r[31:24]};
                endcase
            end

            // LHU
            3'b101: begin
                if (alu_result[1] == 1'b0)
                    load_data_extended = {16'b0, wb_m_dat_r[15:0]};
                else
                    load_data_extended = {16'b0, wb_m_dat_r[31:16]};
            end

            default: begin
                load_data_extended = wb_m_dat_r;
            end
        endcase
    end

    // =========================================================
    // Wishbone Bus Control
    // =========================================================

    assign wb_m_adr =
        (state == S_WAIT_INSTR) ? pc : alu_result;

    assign wb_m_dat_w = store_data;

    assign wb_m_we =
        (state == S_WAIT_DATA) && mem_write;

    assign wb_m_sel =
        (state == S_WAIT_DATA) ? store_sel : 4'b1111;

    assign wb_m_cyc =
        (state == S_WAIT_INSTR) ||
        (state == S_WAIT_DATA);

    assign wb_m_stb = wb_m_cyc;

    // =========================================================
    // Register Writeback
    // =========================================================

    assign cpu_reg_write =
        ((state == S_EXECUTE) && reg_write_ctrl && !mem_read && !mem_write) ||
        ((state == S_WAIT_DATA) && mem_read && wb_m_ack);

    assign write_data_reg =
        ((state == S_WAIT_DATA) && mem_read) ? load_data_extended :
        is_lui   ? imm_ext :
        is_auipc ? auipc_result :
        jump     ? pc_plus4 :
        alu_result;

    // =========================================================
    // CPU FSM
    // =========================================================

    always @(posedge clk) begin
        if (cpu_reset) begin
            pc <= 32'h0000_0000;
            instruction <= 32'h0000_0013;
            state <= S_FETCH;
        end
        else begin
            case (state)

                S_FETCH: begin
                    state <= S_WAIT_INSTR;
                end

                S_WAIT_INSTR: begin
                    if (wb_m_ack) begin
                        instruction <= wb_m_dat_r;
                        state <= S_EXECUTE;
                    end
                end

                S_EXECUTE: begin
                    if (mem_read || mem_write) begin
                        state <= S_WAIT_DATA;
                    end
                    else begin
                        pc <= next_pc;
                        state <= S_FETCH;
                    end
                end

                S_WAIT_DATA: begin
                    if (wb_m_ack) begin
                        pc <= next_pc;
                        state <= S_FETCH;
                    end
                end

                default: begin
                    state <= S_FETCH;
                end

            endcase
        end
    end

    // =========================================================
    // Wishbone Slave Wires
    // =========================================================

    wire [31:0] s0_adr;
    wire [31:0] s0_dat_w;
    wire [31:0] s0_dat_r;
    wire        s0_we;
    wire [3:0]  s0_sel;
    wire        s0_cyc;
    wire        s0_stb;
    wire        s0_ack;

    wire [31:0] s1_adr;
    wire [31:0] s1_dat_w;
    wire [31:0] s1_dat_r;
    wire        s1_we;
    wire [3:0]  s1_sel;
    wire        s1_cyc;
    wire        s1_stb;
    wire        s1_ack;

    wire [31:0] s2_adr;
    wire [31:0] s2_dat_w;
    wire [31:0] s2_dat_r;
    wire        s2_we;
    wire [3:0]  s2_sel;
    wire        s2_cyc;
    wire        s2_stb;
    wire        s2_ack;

    // =========================================================
    // Wishbone Interconnect
    // =========================================================

    wb_interconnect BUS(
        .m_adr_i(wb_m_adr),
        .m_dat_i(wb_m_dat_w),
        .m_dat_o(wb_m_dat_r),
        .m_we_i(wb_m_we),
        .m_sel_i(wb_m_sel),
        .m_cyc_i(wb_m_cyc),
        .m_stb_i(wb_m_stb),
        .m_ack_o(wb_m_ack),

        .s0_adr_o(s0_adr),
        .s0_dat_o(s0_dat_w),
        .s0_dat_i(s0_dat_r),
        .s0_we_o(s0_we),
        .s0_sel_o(s0_sel),
        .s0_cyc_o(s0_cyc),
        .s0_stb_o(s0_stb),
        .s0_ack_i(s0_ack),

        .s1_adr_o(s1_adr),
        .s1_dat_o(s1_dat_w),
        .s1_dat_i(s1_dat_r),
        .s1_we_o(s1_we),
        .s1_sel_o(s1_sel),
        .s1_cyc_o(s1_cyc),
        .s1_stb_o(s1_stb),
        .s1_ack_i(s1_ack),

        .s2_adr_o(s2_adr),
        .s2_dat_o(s2_dat_w),
        .s2_dat_i(s2_dat_r),
        .s2_we_o(s2_we),
        .s2_sel_o(s2_sel),
        .s2_cyc_o(s2_cyc),
        .s2_stb_o(s2_stb),
        .s2_ack_i(s2_ack)
    );

    // =========================================================
    // Slave S0: Program Memory
    // =========================================================

    wb_rom ROM(
        .clk(clk),
        .reset(cpu_reset),
        .adr_i(s0_adr),
        .dat_i(s0_dat_w),
        .dat_o(s0_dat_r),
        .we_i(s0_we),
        .sel_i(s0_sel),
        .cyc_i(s0_cyc),
        .stb_i(s0_stb),
        .ack_o(s0_ack)
    );

    // =========================================================
    // Slave S1: Data Memory
    // =========================================================

    wb_ram RAM(
        .clk(clk),
        .reset(cpu_reset),
        .adr_i(s1_adr),
        .dat_i(s1_dat_w),
        .dat_o(s1_dat_r),
        .we_i(s1_we),
        .sel_i(s1_sel),
        .cyc_i(s1_cyc),
        .stb_i(s1_stb),
        .ack_o(s1_ack)
    );

    // =========================================================
    // Slave S2: LED Controller
    // =========================================================
	wb_led LED(
    .clk(clk),
    .reset(cpu_reset),
    .adr_i(s2_adr),
    .dat_i(s2_dat_w),
    .dat_o(s2_dat_r),
    .we_i(s2_we),
    .sel_i(s2_sel),
    .cyc_i(s2_cyc),
    .stb_i(s2_stb),
    .ack_o(s2_ack),
    .led(led)
);


endmodule
