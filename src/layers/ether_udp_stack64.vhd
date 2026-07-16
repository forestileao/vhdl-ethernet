-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity udp_stack64 is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        tx_hdr_valid         : in  std_logic;
        tx_hdr_ready         : out std_logic;
        tx_source_port       : in  word16_t;
        tx_target_port       : in  word16_t;
        tx_payload_length    : in  word16_t;
        tx_payload_tdata     : in  word64_t;
        tx_payload_tkeep     : in  keep8_t;
        tx_payload_tvalid    : in  std_logic;
        tx_payload_tready    : out std_logic;
        tx_payload_tlast     : in  std_logic;
        tx_payload_tuser     : in  std_logic;
        tx_axis_tdata        : out word64_t;
        tx_axis_tkeep        : out keep8_t;
        tx_axis_tvalid       : out std_logic;
        tx_axis_tready       : in  std_logic;
        tx_axis_tlast        : out std_logic;
        tx_axis_tuser        : out std_logic;
        rx_axis_tdata        : in  word64_t;
        rx_axis_tkeep        : in  keep8_t;
        rx_axis_tvalid       : in  std_logic;
        rx_axis_tready       : out std_logic;
        rx_axis_tlast        : in  std_logic;
        rx_axis_tuser        : in  std_logic;
        rx_hdr_valid         : out std_logic;
        rx_hdr_ready         : in  std_logic;
        rx_source_port       : out word16_t;
        rx_target_port       : out word16_t;
        rx_payload_length    : out word16_t;
        rx_payload_tdata     : out word64_t;
        rx_payload_tkeep     : out keep8_t;
        rx_payload_tvalid    : out std_logic;
        rx_payload_tready    : in  std_logic;
        rx_payload_tlast     : out std_logic;
        rx_payload_tuser     : out std_logic;
        rx_error_bad_header  : out std_logic
    );
end entity;

architecture rtl of udp_stack64 is
begin
    tx: entity work.udp_tx64
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => tx_hdr_valid,
            s_hdr_ready => tx_hdr_ready,
            s_source_port => tx_source_port,
            s_target_port => tx_target_port,
            s_payload_length => tx_payload_length,
            s_axis_payload_tdata => tx_payload_tdata,
            s_axis_payload_tkeep => tx_payload_tkeep,
            s_axis_payload_tvalid => tx_payload_tvalid,
            s_axis_payload_tready => tx_payload_tready,
            s_axis_payload_tlast => tx_payload_tlast,
            s_axis_payload_tuser => tx_payload_tuser,
            m_axis_tdata => tx_axis_tdata,
            m_axis_tkeep => tx_axis_tkeep,
            m_axis_tvalid => tx_axis_tvalid,
            m_axis_tready => tx_axis_tready,
            m_axis_tlast => tx_axis_tlast,
            m_axis_tuser => tx_axis_tuser
        );

    rx: entity work.udp_rx64
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => rx_axis_tdata,
            s_axis_tkeep => rx_axis_tkeep,
            s_axis_tvalid => rx_axis_tvalid,
            s_axis_tready => rx_axis_tready,
            s_axis_tlast => rx_axis_tlast,
            s_axis_tuser => rx_axis_tuser,
            m_hdr_valid => rx_hdr_valid,
            m_hdr_ready => rx_hdr_ready,
            m_source_port => rx_source_port,
            m_target_port => rx_target_port,
            m_payload_length => rx_payload_length,
            m_axis_payload_tdata => rx_payload_tdata,
            m_axis_payload_tkeep => rx_payload_tkeep,
            m_axis_payload_tvalid => rx_payload_tvalid,
            m_axis_payload_tready => rx_payload_tready,
            m_axis_payload_tlast => rx_payload_tlast,
            m_axis_payload_tuser => rx_payload_tuser,
            error_bad_header => rx_error_bad_header
        );
end architecture;
