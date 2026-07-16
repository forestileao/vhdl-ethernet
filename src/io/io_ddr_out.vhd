-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity io_ddr_out is
    port (
        clk    : in  std_logic;
        d_rise : in  std_logic;
        d_fall : in  std_logic;
        q      : out std_logic
    );
end entity;

architecture rtl of io_ddr_out is
begin
    q <= d_rise when clk = '1' else d_fall;
end architecture;
