-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_throughput is
end entity;

architecture sim of tb_throughput is
    constant FRAME_LEN      : natural := 512;
    constant MAX_LAT_CYCLES : natural := FRAME_LEN + 24;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal in_data  : byte_t := (others => '0');
    signal in_valid : std_logic := '0';
    signal in_ready : std_logic;
    signal in_last  : std_logic := '0';
    signal in_user  : std_logic := '0';

    signal fcs_data  : byte_t;
    signal fcs_valid : std_logic;
    signal fcs_ready : std_logic;
    signal fcs_last  : std_logic;
    signal fcs_user  : std_logic;

    signal out_data  : byte_t;
    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';
    signal out_last  : std_logic;
    signal out_user  : std_logic;
    signal bad_frame : std_logic;
    signal bad_fcs   : std_logic;
    signal measuring : boolean := false;
    signal done      : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut_insert: entity work.axis_eth_fcs_insert
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => in_data, s_axis_tvalid => in_valid, s_axis_tready => in_ready,
            s_axis_tlast => in_last, s_axis_tuser => in_user,
            m_axis_tdata => fcs_data, m_axis_tvalid => fcs_valid, m_axis_tready => fcs_ready,
            m_axis_tlast => fcs_last, m_axis_tuser => fcs_user
        );

    dut_check: entity work.axis_eth_fcs_check
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => fcs_data, s_axis_tvalid => fcs_valid, s_axis_tready => fcs_ready,
            s_axis_tlast => fcs_last, s_axis_tuser => fcs_user,
            m_axis_tdata => out_data, m_axis_tvalid => out_valid, m_axis_tready => out_ready,
            m_axis_tlast => out_last, m_axis_tuser => out_user,
            error_bad_frame => bad_frame, error_bad_fcs => bad_fcs
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        measuring <= true;
        for i in 0 to FRAME_LEN - 1 loop
            in_data  <= std_logic_vector(to_unsigned(i mod 256, 8));
            in_valid <= '1';
            if i = FRAME_LEN - 1 then
                in_last <= '1';
            else
                in_last <= '0';
            end if;

            loop
                wait until rising_edge(clk);
                exit when in_ready = '1';
            end loop;
        end loop;

        in_valid <= '0';
        in_last  <= '0';
        in_data  <= (others => '0');

        for i in 0 to MAX_LAT_CYCLES + 20 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "throughput bench timed out" severity failure;
        assert bad_frame = '0' report "throughput bench saw short frame" severity failure;
        assert bad_fcs = '0' report "throughput bench saw bad FCS" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos    : natural := 0;
        variable cycles : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos    := 0;
                cycles := 0;
                done   <= false;
            else
                if measuring and not done then
                    cycles := cycles + 1;
                end if;

                if out_valid = '1' and out_ready = '1' then
                    assert out_data = std_logic_vector(to_unsigned(pos mod 256, 8))
                        report "throughput payload mismatch" severity failure;
                    assert out_user = '0' report "throughput output user flag set" severity failure;

                    if out_last = '1' then
                        assert pos = FRAME_LEN - 1 report "throughput frame length mismatch" severity failure;
                        assert cycles <= MAX_LAT_CYCLES report "throughput budget exceeded" severity failure;
                        done <= true;
                    end if;
                    pos := pos + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
