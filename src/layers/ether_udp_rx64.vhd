-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity udp_rx64 is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_axis_tdata         : in  word64_t;
        s_axis_tkeep         : in  keep8_t;
        s_axis_tvalid        : in  std_logic;
        s_axis_tready        : out std_logic;
        s_axis_tlast         : in  std_logic;
        s_axis_tuser         : in  std_logic;
        m_hdr_valid          : out std_logic;
        m_hdr_ready          : in  std_logic;
        m_source_port        : out word16_t;
        m_target_port        : out word16_t;
        m_payload_length     : out word16_t;
        m_axis_payload_tdata : out word64_t;
        m_axis_payload_tkeep : out keep8_t;
        m_axis_payload_tvalid: out std_logic;
        m_axis_payload_tready: in  std_logic;
        m_axis_payload_tlast : out std_logic;
        m_axis_payload_tuser : out std_logic;
        error_bad_header     : out std_logic
    );
end entity;

architecture rtl of udp_rx64 is
    signal in_data : byte_t;
    signal in_valid : std_logic;
    signal in_ready : std_logic;
    signal in_last : std_logic;
    signal in_user : std_logic;
    signal p_data : byte_t;
    signal p_valid : std_logic;
    signal p_ready : std_logic;
    signal p_last : std_logic;
    signal p_user : std_logic;
begin
    unpack_input: entity work.axis64_to_byte_stream
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => s_axis_tdata,
            s_axis_tkeep => s_axis_tkeep,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            s_axis_tuser => s_axis_tuser,
            m_axis_tdata => in_data,
            m_axis_tvalid => in_valid,
            m_axis_tready => in_ready,
            m_axis_tlast => in_last,
            m_axis_tuser => in_user
        );

    rx: entity work.udp_rx
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => in_data,
            s_axis_tvalid => in_valid,
            s_axis_tready => in_ready,
            s_axis_tlast => in_last,
            s_axis_tuser => in_user,
            m_hdr_valid => m_hdr_valid,
            m_hdr_ready => m_hdr_ready,
            m_source_port => m_source_port,
            m_target_port => m_target_port,
            m_payload_length => m_payload_length,
            m_axis_payload_tdata => p_data,
            m_axis_payload_tvalid => p_valid,
            m_axis_payload_tready => p_ready,
            m_axis_payload_tlast => p_last,
            m_axis_payload_tuser => p_user,
            error_bad_header => error_bad_header
        );

    pack_payload: entity work.byte_stream_to_axis64
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => p_data,
            s_axis_tvalid => p_valid,
            s_axis_tready => p_ready,
            s_axis_tlast => p_last,
            s_axis_tuser => p_user,
            m_axis_tdata => m_axis_payload_tdata,
            m_axis_tkeep => m_axis_payload_tkeep,
            m_axis_tvalid => m_axis_payload_tvalid,
            m_axis_tready => m_axis_payload_tready,
            m_axis_tlast => m_axis_payload_tlast,
            m_axis_tuser => m_axis_payload_tuser
        );
end architecture;
