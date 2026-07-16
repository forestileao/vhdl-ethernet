-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity eth_mac_10g is
    generic (
        MAX_FRAME_BYTES : positive := 2048
    );
    port (
        clk                : in  std_logic;
        rst                : in  std_logic;
        tx_axis_tdata      : in  word64_t;
        tx_axis_tkeep      : in  keep8_t;
        tx_axis_tvalid     : in  std_logic;
        tx_axis_tready     : out std_logic;
        tx_axis_tlast      : in  std_logic;
        tx_axis_tuser      : in  std_logic;
        rx_axis_tdata      : out word64_t;
        rx_axis_tkeep      : out keep8_t;
        rx_axis_tvalid     : out std_logic;
        rx_axis_tready     : in  std_logic;
        rx_axis_tlast      : out std_logic;
        rx_axis_tuser      : out std_logic;
        xgmii_txd          : out word64_t;
        xgmii_txc          : out keep8_t;
        xgmii_rxd          : in  word64_t;
        xgmii_rxc          : in  keep8_t;
        tx_busy            : out std_logic;
        rx_error_bad_frame : out std_logic;
        rx_error_bad_fcs   : out std_logic
    );
end entity;

architecture rtl of eth_mac_10g is
begin
    tx: entity work.axis_xgmii_tx64
        generic map (
            MAX_FRAME_BYTES => MAX_FRAME_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => tx_axis_tdata,
            s_axis_tkeep => tx_axis_tkeep,
            s_axis_tvalid => tx_axis_tvalid,
            s_axis_tready => tx_axis_tready,
            s_axis_tlast => tx_axis_tlast,
            s_axis_tuser => tx_axis_tuser,
            xgmii_txd => xgmii_txd,
            xgmii_txc => xgmii_txc,
            busy => tx_busy
        );

    rx: entity work.axis_xgmii_rx64
        generic map (
            MAX_FRAME_BYTES => MAX_FRAME_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            xgmii_rxd => xgmii_rxd,
            xgmii_rxc => xgmii_rxc,
            m_axis_tdata => rx_axis_tdata,
            m_axis_tkeep => rx_axis_tkeep,
            m_axis_tvalid => rx_axis_tvalid,
            m_axis_tready => rx_axis_tready,
            m_axis_tlast => rx_axis_tlast,
            m_axis_tuser => rx_axis_tuser,
            error_bad_frame => rx_error_bad_frame,
            error_bad_fcs => rx_error_bad_fcs
        );
end architecture;
