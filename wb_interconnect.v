module wb_interconnect(
    input  [31:0] m_adr_i,
    input  [31:0] m_dat_i,
    output reg [31:0] m_dat_o,
    input         m_we_i,
    input  [3:0]  m_sel_i,
    input         m_cyc_i,
    input         m_stb_i,
    output reg    m_ack_o,

    output [31:0] s0_adr_o,
    output [31:0] s0_dat_o,
    input  [31:0] s0_dat_i,
    output        s0_we_o,
    output [3:0]  s0_sel_o,
    output        s0_cyc_o,
    output        s0_stb_o,
    input         s0_ack_i,

    output [31:0] s1_adr_o,
    output [31:0] s1_dat_o,
    input  [31:0] s1_dat_i,
    output        s1_we_o,
    output [3:0]  s1_sel_o,
    output        s1_cyc_o,
    output        s1_stb_o,
    input         s1_ack_i,

    output [31:0] s2_adr_o,
    output [31:0] s2_dat_o,
    input  [31:0] s2_dat_i,
    output        s2_we_o,
    output [3:0]  s2_sel_o,
    output        s2_cyc_o,
    output        s2_stb_o,
    input         s2_ack_i
);

    wire access = m_cyc_i & m_stb_i;

    wire sel_s0 = access && (m_adr_i[31:12] == 20'h00000);
    wire sel_s1 = access && (m_adr_i[31:12] == 20'h00001);
    wire sel_s2 = access && (m_adr_i[31:12] == 20'h00002);

    assign s0_adr_o = m_adr_i;
    assign s1_adr_o = m_adr_i;
    assign s2_adr_o = m_adr_i;

    assign s0_dat_o = m_dat_i;
    assign s1_dat_o = m_dat_i;
    assign s2_dat_o = m_dat_i;

    assign s0_we_o  = m_we_i;
    assign s1_we_o  = m_we_i;
    assign s2_we_o  = m_we_i;

    assign s0_sel_o = m_sel_i;
    assign s1_sel_o = m_sel_i;
    assign s2_sel_o = m_sel_i;

    assign s0_cyc_o = sel_s0;
    assign s1_cyc_o = sel_s1;
    assign s2_cyc_o = sel_s2;

    assign s0_stb_o = sel_s0;
    assign s1_stb_o = sel_s1;
    assign s2_stb_o = sel_s2;

    always @(*) begin
        m_dat_o = 32'b0;
        m_ack_o = 1'b0;

        if (sel_s0) begin
            m_dat_o = s0_dat_i;
            m_ack_o = s0_ack_i;
        end
        else if (sel_s1) begin
            m_dat_o = s1_dat_i;
            m_ack_o = s1_ack_i;
        end
        else if (sel_s2) begin
            m_dat_o = s2_dat_i;
            m_ack_o = s2_ack_i;
        end
        else if (access) begin
            m_dat_o = 32'h0000_0000;
            m_ack_o = 1'b1;
        end
    end

endmodule
