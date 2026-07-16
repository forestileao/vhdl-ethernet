-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ptp_td_leaf is
    generic (
        TS_WIDTH : positive := 96
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        enable       : in  std_logic;
        source_time  : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        path_delay   : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        leaf_time    : out std_logic_vector(TS_WIDTH - 1 downto 0);
        leaf_valid   : out std_logic
    );
end entity;

architecture rtl of ptp_td_leaf is
    signal time_reg : unsigned(TS_WIDTH - 1 downto 0) := (others => '0');
    signal valid_reg : std_logic := '0';
begin
    leaf_time <= std_logic_vector(time_reg);
    leaf_valid <= valid_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                time_reg <= (others => '0');
                valid_reg <= '0';
            else
                valid_reg <= '0';
                if enable = '1' then
                    time_reg <= unsigned(source_time) + unsigned(path_delay);
                    valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
