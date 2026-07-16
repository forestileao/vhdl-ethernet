-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity gmii_phy_if is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        mac_gmii_rx_clk : out std_logic;
        mac_gmii_rx_rst : out std_logic;
        mac_gmii_rxd    : out byte_t;
        mac_gmii_rx_dv  : out std_logic;
        mac_gmii_rx_er  : out std_logic;
        mac_gmii_tx_clk : out std_logic;
        mac_gmii_tx_rst : out std_logic;
        mac_gmii_txd    : in  byte_t;
        mac_gmii_tx_en  : in  std_logic;
        mac_gmii_tx_er  : in  std_logic;
        phy_gmii_rx_clk : in  std_logic;
        phy_gmii_rxd    : in  byte_t;
        phy_gmii_rx_dv  : in  std_logic;
        phy_gmii_rx_er  : in  std_logic;
        phy_mii_tx_clk  : in  std_logic;
        phy_gmii_tx_clk : out std_logic;
        phy_gmii_txd    : out byte_t;
        phy_gmii_tx_en  : out std_logic;
        phy_gmii_tx_er  : out std_logic;
        mii_select      : in  std_logic
    );
end entity;

architecture rtl of gmii_phy_if is
    signal tx_clk_sel : std_logic;
begin
    mac_gmii_rx_clk <= phy_gmii_rx_clk;
    tx_clk_sel <= phy_mii_tx_clk when mii_select = '1' else clk;
    mac_gmii_tx_clk <= tx_clk_sel;

    mac_gmii_rxd <= phy_gmii_rxd;
    mac_gmii_rx_dv <= phy_gmii_rx_dv;
    mac_gmii_rx_er <= phy_gmii_rx_er;

    phy_gmii_tx_clk <= tx_clk_sel;
    phy_gmii_txd <= mac_gmii_txd;
    phy_gmii_tx_en <= mac_gmii_tx_en;
    phy_gmii_tx_er <= mac_gmii_tx_er;

    tx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => tx_clk_sel,
            arst => rst,
            sync_rst => mac_gmii_tx_rst
        );

    rx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => phy_gmii_rx_clk,
            arst => rst,
            sync_rst => mac_gmii_rx_rst
        );
end architecture;
