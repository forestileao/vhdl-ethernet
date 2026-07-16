-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ptp_td_phc is
    generic (
        TS_WIDTH     : positive := 96;
        INCREMENT_NS : natural := 1
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        set_valid     : in  std_logic;
        set_timestamp : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        correction    : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        timestamp     : out std_logic_vector(TS_WIDTH - 1 downto 0);
        timestamp_valid : out std_logic
    );
end entity;

architecture rtl of ptp_td_phc is
    signal ts_reg : unsigned(TS_WIDTH - 1 downto 0) := (others => '0');
    signal valid_reg : std_logic := '0';
begin
    timestamp <= std_logic_vector(ts_reg);
    timestamp_valid <= valid_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ts_reg <= (others => '0');
                valid_reg <= '0';
            else
                valid_reg <= '1';
                if set_valid = '1' then
                    ts_reg <= unsigned(set_timestamp);
                else
                    ts_reg <= ts_reg + INCREMENT_NS + unsigned(correction);
                end if;
            end if;
        end if;
    end process;
end architecture;
