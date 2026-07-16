-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package eth_types_pkg is
    subtype byte_t is std_logic_vector(7 downto 0);
    subtype word16_t is std_logic_vector(15 downto 0);
    subtype mac_addr_t is std_logic_vector(47 downto 0);
    subtype ipv4_addr_t is std_logic_vector(31 downto 0);

    function sel_byte(data : std_logic_vector; byte_index : natural) return byte_t;
    function crc32_next(crc : std_logic_vector(31 downto 0); data : byte_t) return std_logic_vector;
    function ipv4_header_checksum(
        total_length   : word16_t;
        identification : word16_t;
        flags_fragment : word16_t;
        ttl            : byte_t;
        protocol       : byte_t;
        source_ip      : ipv4_addr_t;
        target_ip      : ipv4_addr_t
    ) return word16_t;
end package;

package body eth_types_pkg is
    function sel_byte(data : std_logic_vector; byte_index : natural) return byte_t is
        variable hi : integer := data'left - integer(byte_index * 8);
    begin
        return data(hi downto hi - 7);
    end function;

    function crc32_next(crc : std_logic_vector(31 downto 0); data : byte_t) return std_logic_vector is
        variable c   : std_logic_vector(31 downto 0) := crc;
        variable mix : std_logic;
    begin
        for i in 0 to 7 loop
            mix := c(0) xor data(i);
            c := '0' & c(31 downto 1);
            if mix = '1' then
                c := c xor x"EDB88320";
            end if;
        end loop;
        return c;
    end function;

    procedure add_word(variable acc : inout unsigned(19 downto 0); word : word16_t) is
    begin
        acc := acc + resize(unsigned(word), acc'length);
    end procedure;

    function fold_sum(sum_in : unsigned(19 downto 0)) return word16_t is
        variable sum : unsigned(19 downto 0) := sum_in;
        variable lo  : unsigned(15 downto 0);
    begin
        for i in 0 to 3 loop
            lo := sum(15 downto 0);
            sum := resize(lo, sum'length) + resize(sum(19 downto 16), sum'length);
        end loop;
        return std_logic_vector(not sum(15 downto 0));
    end function;

    function ipv4_header_checksum(
        total_length   : word16_t;
        identification : word16_t;
        flags_fragment : word16_t;
        ttl            : byte_t;
        protocol       : byte_t;
        source_ip      : ipv4_addr_t;
        target_ip      : ipv4_addr_t
    ) return word16_t is
        variable sum : unsigned(19 downto 0) := (others => '0');
    begin
        add_word(sum, x"4500");
        add_word(sum, total_length);
        add_word(sum, identification);
        add_word(sum, flags_fragment);
        add_word(sum, ttl & protocol);
        add_word(sum, x"0000");
        add_word(sum, source_ip(31 downto 16));
        add_word(sum, source_ip(15 downto 0));
        add_word(sum, target_ip(31 downto 16));
        add_word(sum, target_ip(15 downto 0));
        return fold_sum(sum);
    end function;
end package body;
