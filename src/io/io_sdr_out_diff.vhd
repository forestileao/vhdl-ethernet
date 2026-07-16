-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity io_sdr_out_diff is
    port (
        clk : in  std_logic;
        d   : in  std_logic;
        q_p : out std_logic;
        q_n : out std_logic
    );
end entity;

architecture rtl of io_sdr_out_diff is
    signal q_reg : std_logic := '0';
begin
    q_p <= q_reg;
    q_n <= not q_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            q_reg <= d;
        end if;
    end process;
end architecture;
