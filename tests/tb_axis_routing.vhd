-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_routing is
end entity;

architecture sim of tb_axis_routing is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal s0_data : byte_t := x"A0";
    signal s0_valid : std_logic := '0';
    signal s0_ready : std_logic;
    signal s0_last : std_logic := '0';
    signal s0_user : std_logic := '0';
    signal s1_data : byte_t := x"B0";
    signal s1_valid : std_logic := '0';
    signal s1_ready : std_logic;
    signal s1_last : std_logic := '0';
    signal s1_user : std_logic := '0';
    signal sel : std_logic := '0';

    signal mux_data : byte_t;
    signal mux_valid : std_logic;
    signal mux_ready : std_logic;
    signal mux_last : std_logic;
    signal mux_user : std_logic;

    signal len_data : byte_t;
    signal len_valid : std_logic;
    signal len_ready : std_logic;
    signal len_last : std_logic;
    signal len_user : std_logic;
    signal frame_len : word16_t;
    signal frame_len_valid : std_logic;

    signal tap_data : byte_t;
    signal tap_valid : std_logic;
    signal tap_ready : std_logic := '1';
    signal tap_last : std_logic;
    signal tap_user : std_logic;

    signal d0_data : byte_t;
    signal d0_valid : std_logic;
    signal d0_ready : std_logic := '1';
    signal d0_last : std_logic;
    signal d0_user : std_logic;
    signal d1_data : byte_t;
    signal d1_valid : std_logic;
    signal d1_ready : std_logic := '1';
    signal d1_last : std_logic;
    signal d1_user : std_logic;
    signal done : boolean := false;
    signal length_seen : boolean := false;
begin
    clk <= not clk after 5 ns;

    mux: entity work.axis_byte_mux2
        port map (
            clk => clk, rst => rst, select_port => sel,
            s0_axis_tdata => s0_data, s0_axis_tvalid => s0_valid, s0_axis_tready => s0_ready,
            s0_axis_tlast => s0_last, s0_axis_tuser => s0_user,
            s1_axis_tdata => s1_data, s1_axis_tvalid => s1_valid, s1_axis_tready => s1_ready,
            s1_axis_tlast => s1_last, s1_axis_tuser => s1_user,
            m_axis_tdata => mux_data, m_axis_tvalid => mux_valid, m_axis_tready => mux_ready,
            m_axis_tlast => mux_last, m_axis_tuser => mux_user
        );

    length: entity work.axis_frame_length_meter
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => mux_data, s_axis_tvalid => mux_valid, s_axis_tready => mux_ready,
            s_axis_tlast => mux_last, s_axis_tuser => mux_user,
            m_axis_tdata => len_data, m_axis_tvalid => len_valid, m_axis_tready => len_ready,
            m_axis_tlast => len_last, m_axis_tuser => len_user,
            frame_length => frame_len, frame_length_valid => frame_len_valid
        );

    tap: entity work.axis_byte_tap
        port map (
            s_axis_tdata => len_data, s_axis_tvalid => len_valid, s_axis_tready => len_ready,
            s_axis_tlast => len_last, s_axis_tuser => len_user,
            m_axis_tdata => open, m_axis_tvalid => open, m_axis_tready => '1',
            m_axis_tlast => open, m_axis_tuser => open,
            tap_axis_tdata => tap_data, tap_axis_tvalid => tap_valid, tap_axis_tready => tap_ready,
            tap_axis_tlast => tap_last, tap_axis_tuser => tap_user
        );

    demux: entity work.axis_byte_demux2
        port map (
            clk => clk, rst => rst, select_port => '1',
            s_axis_tdata => tap_data, s_axis_tvalid => tap_valid, s_axis_tready => open,
            s_axis_tlast => tap_last, s_axis_tuser => tap_user,
            m0_axis_tdata => d0_data, m0_axis_tvalid => d0_valid, m0_axis_tready => d0_ready,
            m0_axis_tlast => d0_last, m0_axis_tuser => d0_user,
            m1_axis_tdata => d1_data, m1_axis_tvalid => d1_valid, m1_axis_tready => d1_ready,
            m1_axis_tlast => d1_last, m1_axis_tuser => d1_user
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        sel <= '1';
        for i in 0 to 2 loop
            s1_data <= std_logic_vector(to_unsigned(16#B0# + i, 8));
            s1_valid <= '1';
            if i = 2 then
                s1_last <= '1';
            else
                s1_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when s1_ready = '1';
            end loop;
        end loop;
        s1_valid <= '0';
        s1_last <= '0';

        for i in 0 to 50 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;
        wait until rising_edge(clk);

        assert done report "routing helper chain timed out" severity failure;
        assert length_seen report "frame length missing" severity failure;
        assert frame_len = x"0003" report "frame length mismatch after drain" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
                length_seen <= false;
            else
                assert d0_valid = '0' report "demux sent data to wrong output" severity failure;

                if frame_len_valid = '1' then
                    assert frame_len = x"0003" report "frame length mismatch" severity failure;
                    length_seen <= true;
                end if;

                if d1_valid = '1' and d1_ready = '1' then
                    assert d1_data = std_logic_vector(to_unsigned(16#B0# + pos, 8))
                        report "demux output data mismatch" severity failure;
                    assert d1_user = '0' report "demux output user mismatch" severity failure;
                    if d1_last = '1' then
                        assert pos = 2 report "demux output length mismatch" severity failure;
                        done <= true;
                    end if;
                    pos := pos + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
