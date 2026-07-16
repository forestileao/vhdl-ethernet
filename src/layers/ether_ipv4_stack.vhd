-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity ipv4_stack is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        tx_hdr_valid         : in  std_logic;
        tx_hdr_ready         : out std_logic;
        tx_payload_length    : in  word16_t;
        tx_identification    : in  word16_t;
        tx_flags_fragment    : in  word16_t;
        tx_ttl               : in  byte_t;
        tx_protocol          : in  byte_t;
        tx_source_ip         : in  ipv4_addr_t;
        tx_target_ip         : in  ipv4_addr_t;
        tx_payload_tdata     : in  byte_t;
        tx_payload_tvalid    : in  std_logic;
        tx_payload_tready    : out std_logic;
        tx_payload_tlast     : in  std_logic;
        tx_payload_tuser     : in  std_logic;
        tx_axis_tdata        : out byte_t;
        tx_axis_tvalid       : out std_logic;
        tx_axis_tready       : in  std_logic;
        tx_axis_tlast        : out std_logic;
        tx_axis_tuser        : out std_logic;
        rx_axis_tdata        : in  byte_t;
        rx_axis_tvalid       : in  std_logic;
        rx_axis_tready       : out std_logic;
        rx_axis_tlast        : in  std_logic;
        rx_axis_tuser        : in  std_logic;
        rx_hdr_valid         : out std_logic;
        rx_hdr_ready         : in  std_logic;
        rx_payload_length    : out word16_t;
        rx_identification    : out word16_t;
        rx_flags_fragment    : out word16_t;
        rx_ttl               : out byte_t;
        rx_protocol          : out byte_t;
        rx_source_ip         : out ipv4_addr_t;
        rx_target_ip         : out ipv4_addr_t;
        rx_payload_tdata     : out byte_t;
        rx_payload_tvalid    : out std_logic;
        rx_payload_tready    : in  std_logic;
        rx_payload_tlast     : out std_logic;
        rx_payload_tuser     : out std_logic;
        rx_error_bad_header  : out std_logic
    );
end entity;

architecture rtl of ipv4_stack is
begin
    tx: entity work.ipv4_tx
        port map (
            clk => clk,
            rst => rst,
            s_hdr_valid => tx_hdr_valid,
            s_hdr_ready => tx_hdr_ready,
            s_payload_length => tx_payload_length,
            s_identification => tx_identification,
            s_flags_fragment => tx_flags_fragment,
            s_ttl => tx_ttl,
            s_protocol => tx_protocol,
            s_source_ip => tx_source_ip,
            s_target_ip => tx_target_ip,
            s_axis_payload_tdata => tx_payload_tdata,
            s_axis_payload_tvalid => tx_payload_tvalid,
            s_axis_payload_tready => tx_payload_tready,
            s_axis_payload_tlast => tx_payload_tlast,
            s_axis_payload_tuser => tx_payload_tuser,
            m_axis_tdata => tx_axis_tdata,
            m_axis_tvalid => tx_axis_tvalid,
            m_axis_tready => tx_axis_tready,
            m_axis_tlast => tx_axis_tlast,
            m_axis_tuser => tx_axis_tuser
        );

    rx: entity work.ipv4_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => rx_axis_tdata,
            s_axis_tvalid => rx_axis_tvalid,
            s_axis_tready => rx_axis_tready,
            s_axis_tlast => rx_axis_tlast,
            s_axis_tuser => rx_axis_tuser,
            m_hdr_valid => rx_hdr_valid,
            m_hdr_ready => rx_hdr_ready,
            m_payload_length => rx_payload_length,
            m_identification => rx_identification,
            m_flags_fragment => rx_flags_fragment,
            m_ttl => rx_ttl,
            m_protocol => rx_protocol,
            m_source_ip => rx_source_ip,
            m_target_ip => rx_target_ip,
            m_axis_payload_tdata => rx_payload_tdata,
            m_axis_payload_tvalid => rx_payload_tvalid,
            m_axis_payload_tready => rx_payload_tready,
            m_axis_payload_tlast => rx_payload_tlast,
            m_axis_payload_tuser => rx_payload_tuser,
            error_bad_header => rx_error_bad_header
        );
end architecture;
