-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity eth_mac_1g_gmii_fifo is
    generic (
        MIN_FRAME_LENGTH : positive := 64;
        IFG_LENGTH       : positive := 12;
        TX_FIFO_DEPTH    : positive := 32;
        RX_FIFO_DEPTH    : positive := 32
    );
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        tx_axis_tdata       : in  byte_t;
        tx_axis_tvalid      : in  std_logic;
        tx_axis_tready      : out std_logic;
        tx_axis_tlast       : in  std_logic;
        tx_axis_tuser       : in  std_logic;
        rx_axis_tdata       : out byte_t;
        rx_axis_tvalid      : out std_logic;
        rx_axis_tready      : in  std_logic;
        rx_axis_tlast       : out std_logic;
        rx_axis_tuser       : out std_logic;
        gmii_txd            : out byte_t;
        gmii_tx_en          : out std_logic;
        gmii_tx_er          : out std_logic;
        gmii_rxd            : in  byte_t;
        gmii_rx_dv          : in  std_logic;
        gmii_rx_er          : in  std_logic;
        tx_busy             : out std_logic;
        rx_error_bad_frame  : out std_logic;
        rx_error_bad_fcs    : out std_logic
    );
end entity;

architecture rtl of eth_mac_1g_gmii_fifo is
begin
    mac_fifo: entity work.eth_mac_1g_fifo
        generic map (
            MIN_FRAME_LENGTH => MIN_FRAME_LENGTH,
            IFG_LENGTH => IFG_LENGTH,
            TX_FIFO_DEPTH => TX_FIFO_DEPTH,
            RX_FIFO_DEPTH => RX_FIFO_DEPTH
        )
        port map (
            clk => clk,
            rst => rst,
            tx_axis_tdata => tx_axis_tdata,
            tx_axis_tvalid => tx_axis_tvalid,
            tx_axis_tready => tx_axis_tready,
            tx_axis_tlast => tx_axis_tlast,
            tx_axis_tuser => tx_axis_tuser,
            rx_axis_tdata => rx_axis_tdata,
            rx_axis_tvalid => rx_axis_tvalid,
            rx_axis_tready => rx_axis_tready,
            rx_axis_tlast => rx_axis_tlast,
            rx_axis_tuser => rx_axis_tuser,
            gmii_txd => gmii_txd,
            gmii_tx_en => gmii_tx_en,
            gmii_tx_er => gmii_tx_er,
            gmii_rxd => gmii_rxd,
            gmii_rx_dv => gmii_rx_dv,
            gmii_rx_er => gmii_rx_er,
            tx_busy => tx_busy,
            rx_error_bad_frame => rx_error_bad_frame,
            rx_error_bad_fcs => rx_error_bad_fcs
        );
end architecture;
