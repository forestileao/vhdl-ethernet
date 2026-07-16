-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity udp_checksum_gen64 is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_source_ip          : in  ipv4_addr_t;
        s_target_ip          : in  ipv4_addr_t;
        s_source_port        : in  word16_t;
        s_target_port        : in  word16_t;
        s_payload_length     : in  word16_t;
        s_axis_payload_tdata : in  word64_t;
        s_axis_payload_tkeep : in  keep8_t;
        s_axis_payload_tvalid: in  std_logic;
        s_axis_payload_tready: out std_logic;
        s_axis_payload_tlast : in  std_logic;
        s_axis_payload_tuser : in  std_logic;
        m_axis_payload_tdata : out word64_t;
        m_axis_payload_tkeep : out keep8_t;
        m_axis_payload_tvalid: out std_logic;
        m_axis_payload_tready: in  std_logic;
        m_axis_payload_tlast : out std_logic;
        m_axis_payload_tuser : out std_logic;
        m_checksum           : out word16_t;
        m_checksum_valid     : out std_logic;
        m_checksum_ready     : in  std_logic
    );
end entity;

architecture rtl of udp_checksum_gen64 is
    signal in_data : byte_t;
    signal in_valid : std_logic;
    signal in_ready : std_logic;
    signal in_last : std_logic;
    signal in_user : std_logic;
    signal out_data : byte_t;
    signal out_valid : std_logic;
    signal out_ready : std_logic;
    signal out_last : std_logic;
    signal out_user : std_logic;
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
            m_axis_tdata => in_data,
            m_axis_tvalid => in_valid,
            m_axis_tready => in_ready,
            m_axis_tlast => in_last,
            m_axis_tuser => in_user
        );

    checksum: entity work.udp_checksum_gen
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => s_hdr_valid,
            s_hdr_ready => s_hdr_ready,
            s_source_ip => s_source_ip,
            s_target_ip => s_target_ip,
            s_source_port => s_source_port,
            s_target_port => s_target_port,
            s_payload_length => s_payload_length,
            s_axis_payload_tdata => in_data,
            s_axis_payload_tvalid => in_valid,
            s_axis_payload_tready => in_ready,
            s_axis_payload_tlast => in_last,
            s_axis_payload_tuser => in_user,
            m_axis_payload_tdata => out_data,
            m_axis_payload_tvalid => out_valid,
            m_axis_payload_tready => out_ready,
            m_axis_payload_tlast => out_last,
            m_axis_payload_tuser => out_user,
            m_checksum => m_checksum,
            m_checksum_valid => m_checksum_valid,
            m_checksum_ready => m_checksum_ready
        );

    pack_payload: entity work.byte_stream_to_axis64
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => out_data,
            s_axis_tvalid => out_valid,
            s_axis_tready => out_ready,
            s_axis_tlast => out_last,
            s_axis_tuser => out_user,
            m_axis_tdata => m_axis_payload_tdata,
            m_axis_tkeep => m_axis_payload_tkeep,
            m_axis_tvalid => m_axis_payload_tvalid,
            m_axis_tready => m_axis_payload_tready,
            m_axis_tlast => m_axis_payload_tlast,
            m_axis_tuser => m_axis_payload_tuser
        );
end architecture;
