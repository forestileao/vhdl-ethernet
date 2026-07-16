-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_eth_mac_1g_fifo is
end entity;

architecture sim of tb_eth_mac_1g_fifo is
    constant FRAME_LEN : natural := 60;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal tx_data  : byte_t := (others => '0');
    signal tx_valid : std_logic := '0';
    signal tx_ready : std_logic;
    signal tx_last  : std_logic := '0';
    signal tx_user  : std_logic := '0';
    signal rx_data  : byte_t;
    signal rx_valid : std_logic;
    signal rx_ready : std_logic := '1';
    signal rx_last  : std_logic;
    signal rx_user  : std_logic;
    signal gmii_txd   : byte_t;
    signal gmii_tx_en : std_logic;
    signal gmii_tx_er : std_logic;
    signal tx_busy    : std_logic;
    signal bad_frame  : std_logic;
    signal bad_fcs    : std_logic;
    signal done       : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.eth_mac_1g_gmii_fifo
        generic map (
            TX_FIFO_DEPTH => 128,
            RX_FIFO_DEPTH => 128
        )
        port map (
            clk => clk,
            rst => rst,
            tx_axis_tdata => tx_data,
            tx_axis_tvalid => tx_valid,
            tx_axis_tready => tx_ready,
            tx_axis_tlast => tx_last,
            tx_axis_tuser => tx_user,
            rx_axis_tdata => rx_data,
            rx_axis_tvalid => rx_valid,
            rx_axis_tready => rx_ready,
            rx_axis_tlast => rx_last,
            rx_axis_tuser => rx_user,
            gmii_txd => gmii_txd,
            gmii_tx_en => gmii_tx_en,
            gmii_tx_er => gmii_tx_er,
            gmii_rxd => gmii_txd,
            gmii_rx_dv => gmii_tx_en,
            gmii_rx_er => gmii_tx_er,
            tx_busy => tx_busy,
            rx_error_bad_frame => bad_frame,
            rx_error_bad_fcs => bad_fcs
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        for i in 0 to FRAME_LEN - 1 loop
            tx_data <= std_logic_vector(to_unsigned((16#70# + i) mod 256, 8));
            tx_valid <= '1';
            if i = FRAME_LEN - 1 then
                tx_last <= '1';
            else
                tx_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when tx_ready = '1';
            end loop;
        end loop;

        tx_valid <= '0';
        tx_last <= '0';
        tx_data <= (others => '0');

        for i in 0 to 250 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "GMII FIFO MAC loopback timed out" severity failure;
        assert bad_frame = '0' report "GMII FIFO MAC reported bad frame" severity failure;
        assert bad_fcs = '0' report "GMII FIFO MAC reported bad FCS" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
            elsif rx_valid = '1' and rx_ready = '1' then
                assert rx_data = std_logic_vector(to_unsigned((16#70# + pos) mod 256, 8))
                    report "GMII FIFO MAC loopback byte mismatch" severity failure;
                assert rx_user = '0' report "GMII FIFO MAC loopback user flag set" severity failure;
                if rx_last = '1' then
                    assert pos = FRAME_LEN - 1 report "GMII FIFO MAC loopback ended at wrong length" severity failure;
                    done <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
