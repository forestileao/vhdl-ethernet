-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_phy_interfaces is
end entity;

architecture sim of tb_phy_interfaces is
    signal clk : std_logic := '0';
    signal clk90 : std_logic := '0';
    signal rx_clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal gmii_mac_rxd : byte_t;
    signal gmii_mac_dv : std_logic;
    signal gmii_mac_er : std_logic;
    signal gmii_phy_txd : byte_t;
    signal gmii_phy_tx_en : std_logic;
    signal gmii_phy_tx_er : std_logic;

    signal mii_mac_rxd : std_logic_vector(3 downto 0);
    signal mii_mac_dv : std_logic;
    signal mii_mac_er : std_logic;
    signal mii_phy_txd : std_logic_vector(3 downto 0);
    signal mii_phy_tx_en : std_logic;
    signal mii_phy_tx_er : std_logic;

    signal rgmii_mac_rxd : byte_t;
    signal rgmii_mac_dv : std_logic;
    signal rgmii_mac_er : std_logic;
    signal rgmii_txd : std_logic_vector(3 downto 0);
    signal rgmii_tx_ctl : std_logic;
    signal rgmii_rx_d : std_logic_vector(3 downto 0) := (others => '0');
    signal rgmii_rx_ctl : std_logic := '0';
    signal rgmii_tx_en_clk : std_logic;
begin
    clk <= not clk after 5 ns;
    clk90 <= transport clk after 2 ns;
    rx_clk <= not rx_clk after 5 ns;

    gmii_if: entity work.gmii_phy_if
        port map (
            clk => clk,
            rst => rst,
            mac_gmii_rx_clk => open,
            mac_gmii_rx_rst => open,
            mac_gmii_rxd => gmii_mac_rxd,
            mac_gmii_rx_dv => gmii_mac_dv,
            mac_gmii_rx_er => gmii_mac_er,
            mac_gmii_tx_clk => open,
            mac_gmii_tx_rst => open,
            mac_gmii_txd => x"A5",
            mac_gmii_tx_en => '1',
            mac_gmii_tx_er => '0',
            phy_gmii_rx_clk => rx_clk,
            phy_gmii_rxd => x"5A",
            phy_gmii_rx_dv => '1',
            phy_gmii_rx_er => '0',
            phy_mii_tx_clk => rx_clk,
            phy_gmii_tx_clk => open,
            phy_gmii_txd => gmii_phy_txd,
            phy_gmii_tx_en => gmii_phy_tx_en,
            phy_gmii_tx_er => gmii_phy_tx_er,
            mii_select => '0'
        );

    mii_if: entity work.mii_phy_if
        port map (
            rst => rst,
            mac_mii_rx_clk => open,
            mac_mii_rx_rst => open,
            mac_mii_rxd => mii_mac_rxd,
            mac_mii_rx_dv => mii_mac_dv,
            mac_mii_rx_er => mii_mac_er,
            mac_mii_tx_clk => open,
            mac_mii_tx_rst => open,
            mac_mii_txd => "1010",
            mac_mii_tx_en => '1',
            mac_mii_tx_er => '0',
            phy_mii_rx_clk => rx_clk,
            phy_mii_rxd => "0101",
            phy_mii_rx_dv => '1',
            phy_mii_rx_er => '0',
            phy_mii_tx_clk => clk,
            phy_mii_txd => mii_phy_txd,
            phy_mii_tx_en => mii_phy_tx_en,
            phy_mii_tx_er => mii_phy_tx_er
        );

    rgmii_if: entity work.rgmii_phy_if
        port map (
            clk => clk,
            clk90 => clk90,
            rst => rst,
            mac_gmii_rx_clk => open,
            mac_gmii_rx_rst => open,
            mac_gmii_rxd => rgmii_mac_rxd,
            mac_gmii_rx_dv => rgmii_mac_dv,
            mac_gmii_rx_er => rgmii_mac_er,
            mac_gmii_tx_clk => open,
            mac_gmii_tx_rst => open,
            mac_gmii_tx_clk_en => rgmii_tx_en_clk,
            mac_gmii_txd => x"3C",
            mac_gmii_tx_en => '1',
            mac_gmii_tx_er => '1',
            phy_rgmii_rx_clk => rx_clk,
            phy_rgmii_rxd => rgmii_rx_d,
            phy_rgmii_rx_ctl => rgmii_rx_ctl,
            phy_rgmii_tx_clk => open,
            phy_rgmii_txd => rgmii_txd,
            phy_rgmii_tx_ctl => rgmii_tx_ctl,
            speed => "10"
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';

        assert gmii_mac_rxd = x"5A" report "GMII RX path mismatch" severity failure;
        assert gmii_mac_dv = '1' and gmii_mac_er = '0' report "GMII RX control mismatch" severity failure;
        assert gmii_phy_txd = x"A5" report "GMII TX path mismatch" severity failure;
        assert gmii_phy_tx_en = '1' and gmii_phy_tx_er = '0' report "GMII TX control mismatch" severity failure;

        assert mii_mac_rxd = "0101" report "MII RX path mismatch" severity failure;
        assert mii_mac_dv = '1' and mii_mac_er = '0' report "MII RX control mismatch" severity failure;
        assert mii_phy_txd = "1010" report "MII TX path mismatch" severity failure;
        assert mii_phy_tx_en = '1' and mii_phy_tx_er = '0' report "MII TX control mismatch" severity failure;

        wait until falling_edge(rx_clk);
        rgmii_rx_d <= x"4";
        rgmii_rx_ctl <= '1';
        wait until rising_edge(rx_clk);
        wait for 1 ns;
        rgmii_rx_d <= x"D";
        rgmii_rx_ctl <= '0';
        wait until falling_edge(rx_clk);
        wait for 1 ns;
        assert rgmii_mac_rxd = x"D4" report "RGMII DDR RX data mismatch" severity failure;
        assert rgmii_mac_dv = '1' and rgmii_mac_er = '1' report "RGMII DDR RX control mismatch" severity failure;

        wait until clk = '1';
        wait for 1 ns;
        assert rgmii_txd = x"C" report "RGMII TX rising nibble mismatch" severity failure;
        assert rgmii_tx_ctl = '1' report "RGMII TX rising control mismatch" severity failure;
        wait until clk = '0';
        wait for 1 ns;
        assert rgmii_txd = x"3" report "RGMII TX falling nibble mismatch" severity failure;
        assert rgmii_tx_ctl = '0' report "RGMII TX falling control mismatch" severity failure;
        assert rgmii_tx_en_clk = '1' report "RGMII 1G clock enable mismatch" severity failure;

        report "simulation finished" severity note;
        finish;
    end process;
end architecture;
