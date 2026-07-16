-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity eth_mac_phy_10g is
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
        tx_block_header    : out std_logic_vector(1 downto 0);
        tx_block_data      : out word64_t;
        tx_block_valid     : out std_logic;
        rx_block_header    : in  std_logic_vector(1 downto 0);
        rx_block_data      : in  word64_t;
        rx_block_valid     : in  std_logic;
        tx_busy            : out std_logic;
        tx_encode_error    : out std_logic;
        rx_block_error     : out std_logic;
        rx_error_bad_frame : out std_logic;
        rx_error_bad_fcs   : out std_logic
    );
end entity;

architecture rtl of eth_mac_phy_10g is
    signal txd : word64_t;
    signal txc : keep8_t;
    signal rxd : word64_t;
    signal rxc : keep8_t;
begin
    mac: entity work.eth_mac_10g
        generic map (
            MAX_FRAME_BYTES => MAX_FRAME_BYTES
        )
        port map (
            clk => clk,
            rst => rst,
            tx_axis_tdata => tx_axis_tdata,
            tx_axis_tkeep => tx_axis_tkeep,
            tx_axis_tvalid => tx_axis_tvalid,
            tx_axis_tready => tx_axis_tready,
            tx_axis_tlast => tx_axis_tlast,
            tx_axis_tuser => tx_axis_tuser,
            rx_axis_tdata => rx_axis_tdata,
            rx_axis_tkeep => rx_axis_tkeep,
            rx_axis_tvalid => rx_axis_tvalid,
            rx_axis_tready => rx_axis_tready,
            rx_axis_tlast => rx_axis_tlast,
            rx_axis_tuser => rx_axis_tuser,
            xgmii_txd => txd,
            xgmii_txc => txc,
            xgmii_rxd => rxd,
            xgmii_rxc => rxc,
            tx_busy => tx_busy,
            rx_error_bad_frame => rx_error_bad_frame,
            rx_error_bad_fcs => rx_error_bad_fcs
        );

    phy: entity work.eth_phy_10g
        port map (
            clk => clk,
            rst => rst,
            tx_xgmii_txd => txd,
            tx_xgmii_txc => txc,
            tx_block_header => tx_block_header,
            tx_block_data => tx_block_data,
            tx_block_valid => tx_block_valid,
            rx_block_header => rx_block_header,
            rx_block_data => rx_block_data,
            rx_block_valid => rx_block_valid,
            rx_xgmii_rxd => rxd,
            rx_xgmii_rxc => rxc,
            tx_encode_error => tx_encode_error,
            rx_block_error => rx_block_error
        );
end architecture;
