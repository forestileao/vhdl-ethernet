-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity arp_stack is
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        tx_hdr_valid        : in  std_logic;
        tx_hdr_ready        : out std_logic;
        tx_oper             : in  word16_t;
        tx_sender_mac       : in  mac_addr_t;
        tx_sender_ip        : in  ipv4_addr_t;
        tx_target_mac       : in  mac_addr_t;
        tx_target_ip        : in  ipv4_addr_t;
        tx_axis_tdata       : out byte_t;
        tx_axis_tvalid      : out std_logic;
        tx_axis_tready      : in  std_logic;
        tx_axis_tlast       : out std_logic;
        tx_axis_tuser       : out std_logic;
        rx_axis_tdata       : in  byte_t;
        rx_axis_tvalid      : in  std_logic;
        rx_axis_tready      : out std_logic;
        rx_axis_tlast       : in  std_logic;
        rx_axis_tuser       : in  std_logic;
        rx_hdr_valid        : out std_logic;
        rx_hdr_ready        : in  std_logic;
        rx_oper             : out word16_t;
        rx_sender_mac       : out mac_addr_t;
        rx_sender_ip        : out ipv4_addr_t;
        rx_target_mac       : out mac_addr_t;
        rx_target_ip        : out ipv4_addr_t;
        rx_error_bad_packet : out std_logic
    );
end entity;

architecture rtl of arp_stack is
begin
    tx: entity work.arp_eth_tx
        port map (
            clk => clk,
            rst => rst,
            s_request_valid => tx_hdr_valid,
            s_request_ready => tx_hdr_ready,
            s_oper => tx_oper,
            s_sender_mac => tx_sender_mac,
            s_sender_ip => tx_sender_ip,
            s_target_mac => tx_target_mac,
            s_target_ip => tx_target_ip,
            m_axis_tdata => tx_axis_tdata,
            m_axis_tvalid => tx_axis_tvalid,
            m_axis_tready => tx_axis_tready,
            m_axis_tlast => tx_axis_tlast,
            m_axis_tuser => tx_axis_tuser
        );

    rx: entity work.arp_eth_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => rx_axis_tdata,
            s_axis_tvalid => rx_axis_tvalid,
            s_axis_tready => rx_axis_tready,
            s_axis_tlast => rx_axis_tlast,
            s_axis_tuser => rx_axis_tuser,
            m_packet_valid => rx_hdr_valid,
            m_packet_ready => rx_hdr_ready,
            m_oper => rx_oper,
            m_sender_mac => rx_sender_mac,
            m_sender_ip => rx_sender_ip,
            m_target_mac => rx_target_mac,
            m_target_ip => rx_target_ip,
            error_bad_packet => rx_error_bad_packet
        );
end architecture;
