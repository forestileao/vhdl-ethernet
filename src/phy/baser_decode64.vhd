-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity baser_decode64 is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        block_header : in  std_logic_vector(1 downto 0);
        block_data   : in  word64_t;
        block_valid  : in  std_logic;
        xgmii_rxd    : out word64_t;
        xgmii_rxc    : out keep8_t;
        block_error  : out std_logic
    );
end entity;

architecture rtl of baser_decode64 is
    constant IDLE_WORD : word64_t := x"0707070707070707";
    signal data_reg : word64_t := IDLE_WORD;
    signal ctrl_reg : keep8_t := (others => '1');
    signal error_reg : std_logic := '0';
begin
    xgmii_rxd <= data_reg;
    xgmii_rxc <= ctrl_reg;
    block_error <= error_reg;

    process (clk)
        variable dec : word64_t;
        variable ctrl : keep8_t;
        variable code : byte_t;
        variable code_i : integer;
        variable lane : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                data_reg <= IDLE_WORD;
                ctrl_reg <= (others => '1');
                error_reg <= '0';
            elsif block_valid = '1' then
                dec := IDLE_WORD;
                ctrl := (others => '1');
                code := block_data(7 downto 0);
                code_i := to_integer(unsigned(code));
                error_reg <= '0';

                if block_header = "01" then
                    dec := block_data;
                    ctrl := (others => '0');
                elsif block_header = "10" and code = x"1E" then
                    dec := IDLE_WORD;
                    ctrl := (others => '1');
                elsif block_header = "10" and code = x"78" then
                    dec := block_data;
                    dec(7 downto 0) := x"FB";
                    ctrl := (others => '0');
                    ctrl(0) := '1';
                elsif block_header = "10" and code_i >= 16#80# and code_i <= 16#87# then
                    lane := code_i - 16#80#;
                    dec := IDLE_WORD;
                    ctrl := (others => '1');
                    for i in 0 to 6 loop
                        if i < lane then
                            dec(i * 8 + 7 downto i * 8) :=
                                block_data((i + 1) * 8 + 7 downto (i + 1) * 8);
                            ctrl(i) := '0';
                        end if;
                    end loop;
                    dec(lane * 8 + 7 downto lane * 8) := x"FD";
                else
                    error_reg <= '1';
                end if;

                data_reg <= dec;
                ctrl_reg <= ctrl;
            end if;
        end if;
    end process;
end architecture;
