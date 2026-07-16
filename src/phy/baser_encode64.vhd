-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity baser_encode64 is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        xgmii_txd    : in  word64_t;
        xgmii_txc    : in  keep8_t;
        block_header : out std_logic_vector(1 downto 0);
        block_data   : out word64_t;
        block_valid  : out std_logic;
        encode_error : out std_logic
    );
end entity;

architecture rtl of baser_encode64 is
    signal header_reg : std_logic_vector(1 downto 0) := "10";
    signal data_reg : word64_t := (others => '0');
    signal valid_reg : std_logic := '0';
    signal error_reg : std_logic := '0';

    function is_idle_word(data : word64_t; ctrl : keep8_t) return boolean is
    begin
        if ctrl /= x"FF" then
            return false;
        end if;
        for lane in 0 to 7 loop
            if lane_byte(data, lane) /= x"07" then
                return false;
            end if;
        end loop;
        return true;
    end function;

    function is_start_word(data : word64_t; ctrl : keep8_t) return boolean is
    begin
        return ctrl = x"01" and lane_byte(data, 0) = x"FB";
    end function;

    function term_lane(data : word64_t; ctrl : keep8_t) return integer is
    begin
        for lane in 0 to 7 loop
            if ctrl(lane) = '1' and lane_byte(data, lane) = x"FD" then
                return lane;
            end if;
        end loop;
        return -1;
    end function;

    function legal_term(data : word64_t; ctrl : keep8_t; lane : integer) return boolean is
    begin
        if lane < 0 then
            return false;
        end if;
        for i in 0 to 7 loop
            if i < lane then
                if ctrl(i) /= '0' then
                    return false;
                end if;
            elsif i = lane then
                if ctrl(i) /= '1' or lane_byte(data, i) /= x"FD" then
                    return false;
                end if;
            else
                if ctrl(i) /= '1' or lane_byte(data, i) /= x"07" then
                    return false;
                end if;
            end if;
        end loop;
        return true;
    end function;
begin
    block_header <= header_reg;
    block_data <= data_reg;
    block_valid <= valid_reg;
    encode_error <= error_reg;

    process (clk)
        variable enc : word64_t;
        variable lane : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                header_reg <= "10";
                data_reg <= (others => '0');
                valid_reg <= '0';
                error_reg <= '0';
            else
                valid_reg <= '1';
                error_reg <= '0';
                lane := term_lane(xgmii_txd, xgmii_txc);

                if xgmii_txc = x"00" then
                    header_reg <= "01";
                    data_reg <= xgmii_txd;
                elsif is_idle_word(xgmii_txd, xgmii_txc) then
                    header_reg <= "10";
                    data_reg <= x"000000000000001E";
                elsif is_start_word(xgmii_txd, xgmii_txc) then
                    enc := (others => '0');
                    enc(7 downto 0) := x"78";
                    enc(63 downto 8) := xgmii_txd(63 downto 8);
                    header_reg <= "10";
                    data_reg <= enc;
                elsif legal_term(xgmii_txd, xgmii_txc, lane) then
                    enc := (others => '0');
                    enc(7 downto 0) := std_logic_vector(to_unsigned(16#80# + lane, 8));
                    for i in 0 to 6 loop
                        if i < lane then
                            enc((i + 1) * 8 + 7 downto (i + 1) * 8) :=
                                lane_byte(xgmii_txd, i);
                        end if;
                    end loop;
                    header_reg <= "10";
                    data_reg <= enc;
                else
                    header_reg <= "10";
                    data_reg <= x"00000000000000FF";
                    error_reg <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
