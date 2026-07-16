-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_ram_switch is
end entity;

architecture sim of tb_axis_ram_switch is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal s0_dest : std_logic := '0';
    signal s0_data : byte_t := (others => '0');
    signal s0_valid : std_logic := '0';
    signal s0_ready : std_logic;
    signal s0_last : std_logic := '0';
    signal s1_dest : std_logic := '0';
    signal s1_data : byte_t := (others => '0');
    signal s1_valid : std_logic := '0';
    signal s1_ready : std_logic;
    signal s1_last : std_logic := '0';

    signal m0_data : byte_t;
    signal m0_valid : std_logic;
    signal m0_last : std_logic;
    signal m1_data : byte_t;
    signal m1_valid : std_logic;
    signal m1_last : std_logic;
    signal done0 : boolean := false;
    signal done1 : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.axis_byte_ram_switch2
        generic map (
            FIFO_DEPTH => 8
        )
        port map (
            clk => clk,
            rst => rst,
            s0_dest => s0_dest,
            s0_axis_tdata => s0_data,
            s0_axis_tvalid => s0_valid,
            s0_axis_tready => s0_ready,
            s0_axis_tlast => s0_last,
            s0_axis_tuser => '0',
            s1_dest => s1_dest,
            s1_axis_tdata => s1_data,
            s1_axis_tvalid => s1_valid,
            s1_axis_tready => s1_ready,
            s1_axis_tlast => s1_last,
            s1_axis_tuser => '0',
            m0_axis_tdata => m0_data,
            m0_axis_tvalid => m0_valid,
            m0_axis_tready => '1',
            m0_axis_tlast => m0_last,
            m0_axis_tuser => open,
            m1_axis_tdata => m1_data,
            m1_axis_tvalid => m1_valid,
            m1_axis_tready => '1',
            m1_axis_tlast => m1_last,
            m1_axis_tuser => open
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        s0_dest <= '0';
        s1_dest <= '1';
        for i in 0 to 2 loop
            s0_data <= std_logic_vector(to_unsigned(16#10# + i, 8));
            s1_data <= std_logic_vector(to_unsigned(16#80# + i, 8));
            s0_last <= '1' when i = 2 else '0';
            s1_last <= '1' when i = 2 else '0';
            s0_valid <= '1';
            s1_valid <= '1';
            loop
                wait until rising_edge(clk);
                exit when s0_ready = '1' and s1_ready = '1';
            end loop;
        end loop;
        s0_valid <= '0';
        s1_valid <= '0';
        s0_last <= '0';
        s1_last <= '0';

        for i in 0 to 30 loop
            wait until rising_edge(clk);
            exit when done0 and done1;
        end loop;

        assert done0 report "output 0 did not complete" severity failure;
        assert done1 report "output 1 did not complete" severity failure;
        report "simulation finished" severity note;
        finish;
    end process;

    check0: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done0 <= false;
            elsif m0_valid = '1' then
                assert m0_data = std_logic_vector(to_unsigned(16#10# + pos, 8))
                    report "RAM switch output 0 data mismatch" severity failure;
                if m0_last = '1' then
                    assert pos = 2 report "RAM switch output 0 length mismatch" severity failure;
                    done0 <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;

    check1: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done1 <= false;
            elsif m1_valid = '1' then
                assert m1_data = std_logic_vector(to_unsigned(16#80# + pos, 8))
                    report "RAM switch output 1 data mismatch" severity failure;
                if m1_last = '1' then
                    assert pos = 2 report "RAM switch output 1 length mismatch" severity failure;
                    done1 <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
