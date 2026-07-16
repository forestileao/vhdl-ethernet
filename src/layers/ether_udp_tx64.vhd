-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity udp_tx64 is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_source_port        : in  word16_t;
        s_target_port        : in  word16_t;
        s_payload_length     : in  word16_t;
        s_axis_payload_tdata : in  word64_t;
        s_axis_payload_tkeep : in  keep8_t;
        s_axis_payload_tvalid: in  std_logic;
        s_axis_payload_tready: out std_logic;
        s_axis_payload_tlast : in  std_logic;
        s_axis_payload_tuser : in  std_logic;
        m_axis_tdata         : out word64_t;
        m_axis_tkeep         : out keep8_t;
        m_axis_tvalid        : out std_logic;
        m_axis_tready        : in  std_logic;
        m_axis_tlast         : out std_logic;
        m_axis_tuser         : out std_logic
    );
end entity;

architecture rtl of udp_tx64 is
    signal p_data : byte_t;
    signal p_valid : std_logic;
    signal p_ready : std_logic;
    signal p_last : std_logic;
    signal p_user : std_logic;
    signal udp_data : byte_t;
    signal udp_valid : std_logic;
    signal udp_ready : std_logic;
    signal udp_last : std_logic;
    signal udp_user : std_logic;
begin
    unpack_payload: entity work.axis64_to_byte_stream
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => s_axis_payload_tdata,
            s_axis_tkeep => s_axis_payload_tkeep,
            s_axis_tvalid => s_axis_payload_tvalid,
            s_axis_tready => s_axis_payload_tready,
            s_axis_tlast => s_axis_payload_tlast,
            s_axis_tuser => s_axis_payload_tuser,
            m_axis_tdata => p_data,
            m_axis_tvalid => p_valid,
            m_axis_tready => p_ready,
            m_axis_tlast => p_last,
            m_axis_tuser => p_user
        );

    tx: entity work.udp_tx
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => s_hdr_valid,
            s_hdr_ready => s_hdr_ready,
            s_source_port => s_source_port,
            s_target_port => s_target_port,
            s_payload_length => s_payload_length,
            s_axis_payload_tdata => p_data,
            s_axis_payload_tvalid => p_valid,
            s_axis_payload_tready => p_ready,
            s_axis_payload_tlast => p_last,
            s_axis_payload_tuser => p_user,
            m_axis_tdata => udp_data,
            m_axis_tvalid => udp_valid,
            m_axis_tready => udp_ready,
            m_axis_tlast => udp_last,
            m_axis_tuser => udp_user
        );

    pack_output: entity work.byte_stream_to_axis64
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => udp_data,
            s_axis_tvalid => udp_valid,
            s_axis_tready => udp_ready,
            s_axis_tlast => udp_last,
            s_axis_tuser => udp_user,
            m_axis_tdata => m_axis_tdata,
            m_axis_tkeep => m_axis_tkeep,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
            m_axis_tuser => m_axis_tuser
        );
end architecture;
