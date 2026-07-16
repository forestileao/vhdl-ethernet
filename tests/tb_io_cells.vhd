-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity tb_io_cells is
end entity;

architecture sim of tb_io_cells is
    signal clk : std_logic := '0';
    signal sdr_d : std_logic := '0';
    signal sdr_q_in : std_logic;
    signal sdr_q_out : std_logic;
    signal sdr_diff_q : std_logic;
    signal sdr_out_p : std_logic;
    signal sdr_out_n : std_logic;

    signal ddr_d : std_logic := '0';
    signal ddr_q_rise : std_logic;
    signal ddr_q_fall : std_logic;
    signal ddr_q : std_logic;
    signal ddr_diff_rise : std_logic;
    signal ddr_diff_fall : std_logic;
    signal ddr_out_p : std_logic;
    signal ddr_out_n : std_logic;
begin
    clk <= not clk after 5 ns;

    sdr_in: entity work.io_sdr_in
        port map (
            clk => clk,
            d => sdr_d,
            q => sdr_q_in
        );

    sdr_out: entity work.io_sdr_out
        port map (
            clk => clk,
            d => sdr_d,
            q => sdr_q_out
        );

    sdr_in_diff: entity work.io_sdr_in_diff
        port map (
            clk => clk,
            d_p => sdr_d,
            d_n => not sdr_d,
            q => sdr_diff_q
        );

    sdr_out_diff: entity work.io_sdr_out_diff
        port map (
            clk => clk,
            d => sdr_d,
            q_p => sdr_out_p,
            q_n => sdr_out_n
        );

    ddr_in: entity work.io_ddr_in
        port map (
            clk => clk,
            d => ddr_d,
            q_rise => ddr_q_rise,
            q_fall => ddr_q_fall
        );

    ddr_out: entity work.io_ddr_out
        port map (
            clk => clk,
            d_rise => '1',
            d_fall => '0',
            q => ddr_q
        );

    ddr_in_diff: entity work.io_ddr_in_diff
        port map (
            clk => clk,
            d_p => ddr_d,
            d_n => not ddr_d,
            q_rise => ddr_diff_rise,
            q_fall => ddr_diff_fall
        );

    ddr_out_diff: entity work.io_ddr_out_diff
        port map (
            clk => clk,
            d_rise => '1',
            d_fall => '0',
            q_p => ddr_out_p,
            q_n => ddr_out_n
        );

    stimulus: process
    begin
        sdr_d <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sdr_q_in = '1' report "SDR input sample mismatch" severity failure;
        assert sdr_q_out = '1' report "SDR output sample mismatch" severity failure;
        assert sdr_diff_q = '1' report "SDR differential input mismatch" severity failure;
        assert sdr_out_p = '1' and sdr_out_n = '0' report "SDR differential output mismatch" severity failure;

        ddr_d <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert ddr_q_rise = '1' report "DDR rising sample mismatch" severity failure;
        assert ddr_diff_rise = '1' report "DDR differential rising sample mismatch" severity failure;
        assert ddr_q = '1' report "DDR output rising value mismatch" severity failure;
        assert ddr_out_p = '1' and ddr_out_n = '0' report "DDR differential output rising mismatch" severity failure;

        ddr_d <= '0';
        wait until falling_edge(clk);
        wait for 1 ns;
        assert ddr_q_fall = '0' report "DDR falling sample mismatch" severity failure;
        assert ddr_diff_fall = '0' report "DDR differential falling sample mismatch" severity failure;
        assert ddr_q = '0' report "DDR output falling value mismatch" severity failure;
        assert ddr_out_p = '0' and ddr_out_n = '1' report "DDR differential output falling mismatch" severity failure;

        finish;
    end process;
end architecture;
