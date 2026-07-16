-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity priority_picker is
    generic (
        WIDTH : positive := 4
    );
    port (
        request     : in  std_logic_vector(WIDTH - 1 downto 0);
        grant       : out std_logic_vector(WIDTH - 1 downto 0);
        grant_index : out natural range 0 to WIDTH - 1;
        grant_valid : out std_logic
    );
end entity;

architecture rtl of priority_picker is
begin
    process (request)
        variable g : std_logic_vector(WIDTH - 1 downto 0);
        variable idx : natural range 0 to WIDTH - 1;
        variable valid : std_logic;
    begin
        g := (others => '0');
        idx := 0;
        valid := '0';
        for i in 0 to WIDTH - 1 loop
            if request(i) = '1' and valid = '0' then
                g(i) := '1';
                idx := i;
                valid := '1';
            end if;
        end loop;
        grant <= g;
        grant_index <= idx;
        grant_valid <= valid;
    end process;
end architecture;
