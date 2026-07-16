-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity io_ddr_in is
    port (
        clk    : in  std_logic;
        d      : in  std_logic;
        q_rise : out std_logic;
        q_fall : out std_logic
    );
end entity;

architecture rtl of io_ddr_in is
    signal rise_reg : std_logic := '0';
    signal fall_reg : std_logic := '0';
begin
    q_rise <= rise_reg;
    q_fall <= fall_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            rise_reg <= d;
        elsif falling_edge(clk) then
            fall_reg <= d;
        end if;
    end process;
end architecture;
