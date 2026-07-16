-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_eth_fcs is
end entity;

architecture sim of tb_axis_eth_fcs is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant payload : byte_vec_t := (x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38", x"39");

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal data      : byte_t := (others => '0');
    signal valid     : std_logic := '0';
    signal ready     : std_logic;
    signal last      : std_logic := '0';
    signal user      : std_logic := '0';
    signal fcs       : std_logic_vector(31 downto 0);
    signal fcs_valid : std_logic;
    signal done      : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.axis_eth_fcs
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => data,
            s_axis_tvalid => valid,
            s_axis_tready => ready,
            s_axis_tlast => last,
            s_axis_tuser => user,
            output_fcs => fcs,
            output_fcs_valid => fcs_valid
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        for i in payload'range loop
            data  <= payload(i);
            valid <= '1';
            if i = payload'high then
                last <= '1';
            else
                last <= '0';
            end if;

            loop
                wait until rising_edge(clk);
                exit when ready = '1';
            end loop;
        end loop;

        valid <= '0';
        last  <= '0';
        data  <= (others => '0');

        for i in 0 to 20 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "FCS calculator did not produce a result" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                done <= false;
            elsif fcs_valid = '1' then
                assert fcs = x"CBF43926" report "FCS calculator mismatch" severity failure;
                done <= true;
            end if;
        end if;
    end process;
end architecture;
