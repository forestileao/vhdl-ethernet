-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity rgmii_phy_if is
    port (
        clk                : in  std_logic;
        clk90              : in  std_logic;
        rst                : in  std_logic;
        mac_gmii_rx_clk    : out std_logic;
        mac_gmii_rx_rst    : out std_logic;
        mac_gmii_rxd       : out byte_t;
        mac_gmii_rx_dv     : out std_logic;
        mac_gmii_rx_er     : out std_logic;
        mac_gmii_tx_clk    : out std_logic;
        mac_gmii_tx_rst    : out std_logic;
        mac_gmii_tx_clk_en : out std_logic;
        mac_gmii_txd       : in  byte_t;
        mac_gmii_tx_en     : in  std_logic;
        mac_gmii_tx_er     : in  std_logic;
        phy_rgmii_rx_clk   : in  std_logic;
        phy_rgmii_rxd      : in  std_logic_vector(3 downto 0);
        phy_rgmii_rx_ctl   : in  std_logic;
        phy_rgmii_tx_clk   : out std_logic;
        phy_rgmii_txd      : out std_logic_vector(3 downto 0);
        phy_rgmii_tx_ctl   : out std_logic;
        speed              : in  std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of rgmii_phy_if is
    signal rx_rise : std_logic_vector(3 downto 0);
    signal rx_fall : std_logic_vector(3 downto 0);
    signal rx_ctl_rise : std_logic;
    signal rx_ctl_fall : std_logic;
    signal tx_clk_en_reg : std_logic := '1';
    signal div_count : natural range 0 to 49 := 0;
begin
    mac_gmii_rx_clk <= phy_rgmii_rx_clk;
    mac_gmii_tx_clk <= clk;
    mac_gmii_tx_clk_en <= tx_clk_en_reg;
    phy_rgmii_tx_clk <= clk90;

    mac_gmii_rxd <= rx_fall & rx_rise;
    mac_gmii_rx_dv <= rx_ctl_rise;
    mac_gmii_rx_er <= rx_ctl_rise xor rx_ctl_fall;

    rx_bits: for i in 0 to 3 generate
        rx_ddr: entity work.io_ddr_in
            port map (
                clk => phy_rgmii_rx_clk,
                d => phy_rgmii_rxd(i),
                q_rise => rx_rise(i),
                q_fall => rx_fall(i)
            );
    end generate;

    rx_ctl_ddr: entity work.io_ddr_in
        port map (
            clk => phy_rgmii_rx_clk,
            d => phy_rgmii_rx_ctl,
            q_rise => rx_ctl_rise,
            q_fall => rx_ctl_fall
        );

    tx_bits: for i in 0 to 3 generate
        tx_ddr: entity work.io_ddr_out
            port map (
                clk => clk,
                d_rise => mac_gmii_txd(i),
                d_fall => mac_gmii_txd(i + 4),
                q => phy_rgmii_txd(i)
            );
    end generate;

    tx_ctl_ddr: entity work.io_ddr_out
        port map (
            clk => clk,
            d_rise => mac_gmii_tx_en,
            d_fall => mac_gmii_tx_en xor mac_gmii_tx_er,
            q => phy_rgmii_tx_ctl
        );

    tx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => clk,
            arst => rst,
            sync_rst => mac_gmii_tx_rst
        );

    rx_rst_sync: entity work.sync_reset_pipe
        port map (
            clk => phy_rgmii_rx_clk,
            arst => rst,
            sync_rst => mac_gmii_rx_rst
        );

    process (clk)
        variable terminal : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                div_count <= 0;
                tx_clk_en_reg <= '1';
            else
                if speed = "00" then
                    terminal := 49;
                elsif speed = "01" then
                    terminal := 4;
                else
                    terminal := 0;
                end if;

                if div_count >= terminal then
                    div_count <= 0;
                    tx_clk_en_reg <= '1';
                else
                    div_count <= div_count + 1;
                    tx_clk_en_reg <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
