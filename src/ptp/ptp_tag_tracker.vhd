-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity ptp_tag_tracker is
    generic (
        TS_WIDTH  : positive := 96;
        TAG_WIDTH : positive := 16
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        tag_valid     : in  std_logic;
        tag_value     : in  std_logic_vector(TAG_WIDTH - 1 downto 0);
        timestamp     : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        lookup_valid  : in  std_logic;
        lookup_tag    : in  std_logic_vector(TAG_WIDTH - 1 downto 0);
        result_valid  : out std_logic;
        result_match  : out std_logic;
        result_time   : out std_logic_vector(TS_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of ptp_tag_tracker is
    signal stored_valid : std_logic := '0';
    signal stored_tag : std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => '0');
    signal stored_time : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
    signal result_valid_reg : std_logic := '0';
    signal result_match_reg : std_logic := '0';
begin
    result_valid <= result_valid_reg;
    result_match <= result_match_reg;
    result_time <= stored_time;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                stored_valid <= '0';
                stored_tag <= (others => '0');
                stored_time <= (others => '0');
                result_valid_reg <= '0';
                result_match_reg <= '0';
            else
                result_valid_reg <= '0';
                result_match_reg <= '0';

                if tag_valid = '1' then
                    stored_valid <= '1';
                    stored_tag <= tag_value;
                    stored_time <= timestamp;
                end if;

                if lookup_valid = '1' then
                    result_valid_reg <= '1';
                    if stored_valid = '1' and lookup_tag = stored_tag then
                        result_match_reg <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
