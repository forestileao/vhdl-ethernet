-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity ptp_tod_split is
    port (
        timestamp   : in  std_logic_vector(95 downto 0);
        seconds     : out std_logic_vector(63 downto 0);
        nanoseconds : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of ptp_tod_split is
begin
    seconds <= timestamp(95 downto 32);
    nanoseconds <= timestamp(31 downto 0);
end architecture;
