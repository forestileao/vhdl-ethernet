-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity eth_phy_10g is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        tx_xgmii_txd    : in  word64_t;
        tx_xgmii_txc    : in  keep8_t;
        tx_block_header : out std_logic_vector(1 downto 0);
        tx_block_data   : out word64_t;
        tx_block_valid  : out std_logic;
        rx_block_header : in  std_logic_vector(1 downto 0);
        rx_block_data   : in  word64_t;
        rx_block_valid  : in  std_logic;
        rx_xgmii_rxd    : out word64_t;
        rx_xgmii_rxc    : out keep8_t;
        tx_encode_error : out std_logic;
        rx_block_error  : out std_logic
    );
end entity;

architecture rtl of eth_phy_10g is
begin
    tx_encode: entity work.baser_encode64
        port map (
            clk => clk,
            rst => rst,
            xgmii_txd => tx_xgmii_txd,
            xgmii_txc => tx_xgmii_txc,
            block_header => tx_block_header,
            block_data => tx_block_data,
            block_valid => tx_block_valid,
            encode_error => tx_encode_error
        );

    rx_decode: entity work.baser_decode64
        port map (
            clk => clk,
            rst => rst,
            block_header => rx_block_header,
            block_data => rx_block_data,
            block_valid => rx_block_valid,
            xgmii_rxd => rx_xgmii_rxd,
            xgmii_rxc => rx_xgmii_rxc,
            block_error => rx_block_error
        );
end architecture;
