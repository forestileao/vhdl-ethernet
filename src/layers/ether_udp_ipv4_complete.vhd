-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity udp_ipv4_complete is
    port (
        clk                    : in  std_logic;
        rst                    : in  std_logic;
        tx_hdr_valid           : in  std_logic;
        tx_hdr_ready           : out std_logic;
        tx_source_ip           : in  ipv4_addr_t;
        tx_target_ip           : in  ipv4_addr_t;
        tx_identification      : in  word16_t;
        tx_source_port         : in  word16_t;
        tx_target_port         : in  word16_t;
        tx_payload_length      : in  word16_t;
        tx_payload_tdata       : in  byte_t;
        tx_payload_tvalid      : in  std_logic;
        tx_payload_tready      : out std_logic;
        tx_payload_tlast       : in  std_logic;
        tx_payload_tuser       : in  std_logic;
        tx_ip_tdata            : out byte_t;
        tx_ip_tvalid           : out std_logic;
        tx_ip_tready           : in  std_logic;
        tx_ip_tlast            : out std_logic;
        tx_ip_tuser            : out std_logic;
        rx_ip_tdata            : in  byte_t;
        rx_ip_tvalid           : in  std_logic;
        rx_ip_tready           : out std_logic;
        rx_ip_tlast            : in  std_logic;
        rx_ip_tuser            : in  std_logic;
        rx_hdr_valid           : out std_logic;
        rx_hdr_ready           : in  std_logic;
        rx_source_ip           : out ipv4_addr_t;
        rx_target_ip           : out ipv4_addr_t;
        rx_source_port         : out word16_t;
        rx_target_port         : out word16_t;
        rx_payload_length      : out word16_t;
        rx_payload_tdata       : out byte_t;
        rx_payload_tvalid      : out std_logic;
        rx_payload_tready      : in  std_logic;
        rx_payload_tlast       : out std_logic;
        rx_payload_tuser       : out std_logic;
        rx_error_bad_ip_header : out std_logic;
        rx_error_bad_udp_header: out std_logic
    );
end entity;

architecture rtl of udp_ipv4_complete is
    signal udp_data : byte_t;
    signal udp_valid : std_logic;
    signal udp_ready : std_logic;
    signal udp_last : std_logic;
    signal udp_user : std_logic;

    signal ip_payload_data : byte_t;
    signal ip_payload_valid : std_logic;
    signal ip_payload_ready : std_logic;
    signal ip_payload_last : std_logic;
    signal ip_payload_user : std_logic;
    signal ip_hdr_valid : std_logic;
    signal ip_payload_length : word16_t;
    signal ip_identification : word16_t;
    signal ip_flags_fragment : word16_t;
    signal ip_ttl : byte_t;
    signal ip_protocol : byte_t;
    signal ip_source : ipv4_addr_t;
    signal ip_target : ipv4_addr_t;
    signal udp_tx_hdr_ready : std_logic;
    signal ip_tx_hdr_ready : std_logic;
begin
    tx_hdr_ready <= udp_tx_hdr_ready and ip_tx_hdr_ready;

    udp_encoder: entity work.udp_tx
        port map (
            clk => clk,
            rst => rst,
            s_hdr_valid => tx_hdr_valid,
            s_hdr_ready => udp_tx_hdr_ready,
            s_source_port => tx_source_port,
            s_target_port => tx_target_port,
            s_payload_length => tx_payload_length,
            s_axis_payload_tdata => tx_payload_tdata,
            s_axis_payload_tvalid => tx_payload_tvalid,
            s_axis_payload_tready => tx_payload_tready,
            s_axis_payload_tlast => tx_payload_tlast,
            s_axis_payload_tuser => tx_payload_tuser,
            m_axis_tdata => udp_data,
            m_axis_tvalid => udp_valid,
            m_axis_tready => udp_ready,
            m_axis_tlast => udp_last,
            m_axis_tuser => udp_user
        );

    ip_encoder: entity work.ipv4_tx
        port map (
            clk => clk,
            rst => rst,
            s_hdr_valid => tx_hdr_valid,
            s_hdr_ready => ip_tx_hdr_ready,
            s_payload_length => std_logic_vector(unsigned(tx_payload_length) + 8),
            s_identification => tx_identification,
            s_flags_fragment => x"4000",
            s_ttl => x"40",
            s_protocol => x"11",
            s_source_ip => tx_source_ip,
            s_target_ip => tx_target_ip,
            s_axis_payload_tdata => udp_data,
            s_axis_payload_tvalid => udp_valid,
            s_axis_payload_tready => udp_ready,
            s_axis_payload_tlast => udp_last,
            s_axis_payload_tuser => udp_user,
            m_axis_tdata => tx_ip_tdata,
            m_axis_tvalid => tx_ip_tvalid,
            m_axis_tready => tx_ip_tready,
            m_axis_tlast => tx_ip_tlast,
            m_axis_tuser => tx_ip_tuser
        );

    ip_decoder: entity work.ipv4_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => rx_ip_tdata,
            s_axis_tvalid => rx_ip_tvalid,
            s_axis_tready => rx_ip_tready,
            s_axis_tlast => rx_ip_tlast,
            s_axis_tuser => rx_ip_tuser,
            m_hdr_valid => ip_hdr_valid,
            m_hdr_ready => rx_hdr_ready,
            m_payload_length => ip_payload_length,
            m_identification => ip_identification,
            m_flags_fragment => ip_flags_fragment,
            m_ttl => ip_ttl,
            m_protocol => ip_protocol,
            m_source_ip => ip_source,
            m_target_ip => ip_target,
            m_axis_payload_tdata => ip_payload_data,
            m_axis_payload_tvalid => ip_payload_valid,
            m_axis_payload_tready => ip_payload_ready,
            m_axis_payload_tlast => ip_payload_last,
            m_axis_payload_tuser => ip_payload_user,
            error_bad_header => rx_error_bad_ip_header
        );

    udp_decoder: entity work.udp_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => ip_payload_data,
            s_axis_tvalid => ip_payload_valid,
            s_axis_tready => ip_payload_ready,
            s_axis_tlast => ip_payload_last,
            s_axis_tuser => ip_payload_user,
            m_hdr_valid => rx_hdr_valid,
            m_hdr_ready => rx_hdr_ready,
            m_source_port => rx_source_port,
            m_target_port => rx_target_port,
            m_payload_length => rx_payload_length,
            m_axis_payload_tdata => rx_payload_tdata,
            m_axis_payload_tvalid => rx_payload_tvalid,
            m_axis_payload_tready => rx_payload_tready,
            m_axis_payload_tlast => rx_payload_tlast,
            m_axis_payload_tuser => rx_payload_tuser,
            error_bad_header => rx_error_bad_udp_header
        );

    rx_source_ip <= ip_source;
    rx_target_ip <= ip_target;
end architecture;
