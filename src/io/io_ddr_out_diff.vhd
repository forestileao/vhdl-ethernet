-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity io_ddr_out_diff is
    port (
        clk    : in  std_logic;
        d_rise : in  std_logic;
        d_fall : in  std_logic;
        q_p    : out std_logic;
        q_n    : out std_logic
    );
end entity;

architecture rtl of io_ddr_out_diff is
    signal q_single : std_logic;
begin
    q_p <= q_single;
    q_n <= not q_single;

    ddr_out: entity work.io_ddr_out
        port map (
            clk => clk,
            d_rise => d_rise,
            d_fall => d_fall,
            q => q_single
        );
end architecture;
