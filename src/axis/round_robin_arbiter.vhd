-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity round_robin_arbiter is
    generic (
        WIDTH : positive := 4
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        request   : in  std_logic_vector(WIDTH - 1 downto 0);
        advance   : in  std_logic;
        grant     : out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of round_robin_arbiter is
    signal pointer : natural range 0 to WIDTH - 1 := 0;
    signal grant_i : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
begin
    grant <= grant_i;

    process (request, pointer)
        variable g : std_logic_vector(WIDTH - 1 downto 0);
        variable idx : natural range 0 to WIDTH - 1;
        variable selected : boolean;
    begin
        g := (others => '0');
        selected := false;
        for offset in 0 to WIDTH - 1 loop
            idx := (pointer + offset) mod WIDTH;
            if request(idx) = '1' and not selected then
                g(idx) := '1';
                selected := true;
            end if;
        end loop;
        grant_i <= g;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pointer <= 0;
            elsif advance = '1' then
                for i in 0 to WIDTH - 1 loop
                    if grant_i(i) = '1' then
                        if i = WIDTH - 1 then
                            pointer <= 0;
                        else
                            pointer <= i + 1;
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process;
end architecture;
