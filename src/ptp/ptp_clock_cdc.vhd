-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity ptp_clock_cdc is
    generic (
        TS_WIDTH : positive := 96
    );
    port (
        src_clk       : in  std_logic;
        src_rst       : in  std_logic;
        src_timestamp : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        dst_clk       : in  std_logic;
        dst_rst       : in  std_logic;
        dst_timestamp : out std_logic_vector(TS_WIDTH - 1 downto 0);
        dst_valid     : out std_logic
    );
end entity;

architecture rtl of ptp_clock_cdc is
    signal src_hold : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
    signal sync_a : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
    signal sync_b : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
    signal valid_pipe : std_logic_vector(1 downto 0) := (others => '0');
begin
    dst_timestamp <= sync_b;
    dst_valid <= valid_pipe(1);

    process (src_clk)
    begin
        if rising_edge(src_clk) then
            if src_rst = '1' then
                src_hold <= (others => '0');
            else
                src_hold <= src_timestamp;
            end if;
        end if;
    end process;

    process (dst_clk)
    begin
        if rising_edge(dst_clk) then
            if dst_rst = '1' then
                sync_a <= (others => '0');
                sync_b <= (others => '0');
                valid_pipe <= (others => '0');
            else
                sync_a <= src_hold;
                sync_b <= sync_a;
                valid_pipe <= valid_pipe(0) & '1';
            end if;
        end if;
    end process;
end architecture;
