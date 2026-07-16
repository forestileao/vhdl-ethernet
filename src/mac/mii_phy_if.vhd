-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity mii_phy_if is
    port (
        rst            : in  std_logic;
        mac_mii_rx_clk : out std_logic;
        mac_mii_rx_rst : out std_logic;
        mac_mii_rxd    : out std_logic_vector(3 downto 0);
        mac_mii_rx_dv  : out std_logic;
        mac_mii_rx_er  : out std_logic;
        mac_mii_tx_clk : out std_logic;
        mac_mii_tx_rst : out std_logic;
        mac_mii_txd    : in  std_logic_vector(3 downto 0);
        mac_mii_tx_en  : in  std_logic;
        mac_mii_tx_er  : in  std_logic;
        phy_mii_rx_clk : in  std_logic;
        phy_mii_rxd    : in  std_logic_vector(3 downto 0);
        phy_mii_rx_dv  : in  std_logic;
        phy_mii_rx_er  : in  std_logic;
        phy_mii_tx_clk : in  std_logic;
        phy_mii_txd    : out std_logic_vector(3 downto 0);
        phy_mii_tx_en  : out std_logic;
        phy_mii_tx_er  : out std_logic
    );
end entity;

architecture rtl of mii_phy_if is
begin
    mac_mii_rx_clk <= phy_mii_rx_clk;
    mac_mii_tx_clk <= phy_mii_tx_clk;

    mac_mii_rxd <= phy_mii_rxd;
    mac_mii_rx_dv <= phy_mii_rx_dv;
    mac_mii_rx_er <= phy_mii_rx_er;

    phy_mii_txd <= mac_mii_txd;
    phy_mii_tx_en <= mac_mii_tx_en;
    phy_mii_tx_er <= mac_mii_tx_er;

    tx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => phy_mii_tx_clk,
            arst => rst,
            sync_rst => mac_mii_tx_rst
        );

    rx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => phy_mii_rx_clk,
            arst => rst,
            sync_rst => mac_mii_rx_rst
        );
end architecture;
