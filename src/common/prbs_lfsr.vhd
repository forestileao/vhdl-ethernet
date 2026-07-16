-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

entity prbs_lfsr is
    generic (
        WIDTH : positive := 32;
        TAP_MASK : std_logic_vector(WIDTH - 1 downto 0) := (others => '1')
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        enable : in  std_logic;
        seed   : in  std_logic_vector(WIDTH - 1 downto 0);
        load   : in  std_logic;
        value  : out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of prbs_lfsr is
    signal reg_value : std_logic_vector(WIDTH - 1 downto 0) := (others => '1');
begin
    value <= reg_value;

    process (clk)
        variable feedback : std_logic;
        variable next_value : std_logic_vector(WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_value <= (others => '1');
            elsif load = '1' then
                reg_value <= seed;
            elsif enable = '1' then
                feedback := reg_value(WIDTH - 1);
                next_value := reg_value(WIDTH - 2 downto 0) & '0';
                for i in 0 to WIDTH - 1 loop
                    if TAP_MASK(i) = '1' then
                        next_value(i) := next_value(i) xor feedback;
                    end if;
                end loop;
                reg_value <= next_value;
            end if;
        end if;
    end process;
end architecture;
