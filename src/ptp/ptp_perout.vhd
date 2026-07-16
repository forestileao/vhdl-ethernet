-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ptp_perout is
    generic (
        TS_WIDTH : positive := 96
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        enable     : in  std_logic;
        timestamp  : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        start_time : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        period     : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        pulse      : out std_logic
    );
end entity;

architecture rtl of ptp_perout is
    signal armed : std_logic := '0';
    signal next_fire : unsigned(TS_WIDTH - 1 downto 0) := (others => '0');
    signal pulse_reg : std_logic := '0';
begin
    pulse <= pulse_reg;

    process (clk)
        variable ts_v : unsigned(TS_WIDTH - 1 downto 0);
        variable period_v : unsigned(TS_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                armed <= '0';
                next_fire <= (others => '0');
                pulse_reg <= '0';
            else
                pulse_reg <= '0';
                ts_v := unsigned(timestamp);
                period_v := unsigned(period);

                if enable = '0' then
                    armed <= '0';
                    next_fire <= unsigned(start_time);
                elsif armed = '0' then
                    armed <= '1';
                    next_fire <= unsigned(start_time);
                elsif ts_v >= next_fire then
                    pulse_reg <= '1';
                    if period_v = 0 then
                        next_fire <= ts_v + 1;
                    else
                        next_fire <= next_fire + period_v;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
