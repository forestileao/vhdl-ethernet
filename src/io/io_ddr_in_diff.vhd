-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity io_ddr_in_diff is
    port (
        clk    : in  std_logic;
        d_p    : in  std_logic;
        d_n    : in  std_logic;
        q_rise : out std_logic;
        q_fall : out std_logic
    );
end entity;

architecture rtl of io_ddr_in_diff is
    signal d_single : std_logic;
begin
    d_single <= d_p and not d_n;

    ddr_in: entity work.io_ddr_in
        port map (
            clk => clk,
            d => d_single,
            q_rise => q_rise,
            q_fall => q_fall
        );
end architecture;
