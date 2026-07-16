-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ptp_clock is
    generic (
        TS_WIDTH      : positive := 96;
        INCREMENT_NS  : natural := 1;
        PULSE_CYCLES  : positive := 100000000
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        set_valid     : in  std_logic;
        set_timestamp : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        timestamp     : out std_logic_vector(TS_WIDTH - 1 downto 0);
        pulse_1pps    : out std_logic
    );
end entity;

architecture rtl of ptp_clock is
    signal ts_reg : unsigned(TS_WIDTH - 1 downto 0) := (others => '0');
    signal cycle_count : natural range 0 to PULSE_CYCLES - 1 := 0;
    signal pulse_reg : std_logic := '0';
begin
    timestamp <= std_logic_vector(ts_reg);
    pulse_1pps <= pulse_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ts_reg <= (others => '0');
                cycle_count <= 0;
                pulse_reg <= '0';
            else
                pulse_reg <= '0';
                if set_valid = '1' then
                    ts_reg <= unsigned(set_timestamp);
                    cycle_count <= 0;
                else
                    ts_reg <= ts_reg + INCREMENT_NS;
                    if cycle_count = PULSE_CYCLES - 1 then
                        cycle_count <= 0;
                        pulse_reg <= '1';
                    else
                        cycle_count <= cycle_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
