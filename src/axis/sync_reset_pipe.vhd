-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity sync_reset_pipe is
    generic (
        STAGES : positive := 4
    );
    port (
        clk       : in  std_logic;
        arst      : in  std_logic;
        sync_rst  : out std_logic
    );
end entity;

architecture rtl of sync_reset_pipe is
    signal pipe : std_logic_vector(STAGES - 1 downto 0) := (others => '1');
begin
    sync_rst <= pipe(STAGES - 1);

    process (clk, arst)
    begin
        if arst = '1' then
            pipe <= (others => '1');
        elsif rising_edge(clk) then
            pipe <= pipe(STAGES - 2 downto 0) & '0';
        end if;
    end process;
end architecture;
