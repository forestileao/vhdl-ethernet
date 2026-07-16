-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity ether_arp_cache is
    generic (
        ENTRY_COUNT : positive := 8
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        clear        : in  std_logic;

        write_valid  : in  std_logic;
        write_ip     : in  ipv4_addr_t;
        write_mac    : in  mac_addr_t;

        query_valid  : in  std_logic;
        query_ip     : in  ipv4_addr_t;
        query_ready  : out std_logic;
        query_hit    : out std_logic;
        query_mac    : out mac_addr_t
    );
end entity;

architecture rtl of ether_arp_cache is
    type ip_mem_t is array (0 to ENTRY_COUNT - 1) of ipv4_addr_t;
    type mac_mem_t is array (0 to ENTRY_COUNT - 1) of mac_addr_t;
    type valid_mem_t is array (0 to ENTRY_COUNT - 1) of std_logic;

    signal ip_mem    : ip_mem_t := (others => (others => '0'));
    signal mac_mem   : mac_mem_t := (others => (others => '0'));
    signal valid_mem : valid_mem_t := (others => '0');
    signal hit_reg   : std_logic := '0';
    signal mac_reg   : mac_addr_t := (others => '0');

    function cache_index(ip_addr : ipv4_addr_t) return natural is
        variable folded : unsigned(7 downto 0);
    begin
        folded := unsigned(ip_addr(31 downto 24)) xor unsigned(ip_addr(23 downto 16)) xor
                  unsigned(ip_addr(15 downto 8)) xor unsigned(ip_addr(7 downto 0));
        return to_integer(folded mod ENTRY_COUNT);
    end function;
begin
    query_ready <= '1';
    query_hit   <= hit_reg;
    query_mac   <= mac_reg;

    process (clk)
        variable widx : natural range 0 to ENTRY_COUNT - 1;
        variable qidx : natural range 0 to ENTRY_COUNT - 1;
    begin
        if rising_edge(clk) then
            if rst = '1' or clear = '1' then
                valid_mem <= (others => '0');
                hit_reg   <= '0';
                mac_reg   <= (others => '0');
            else
                hit_reg <= '0';

                if write_valid = '1' then
                    widx := cache_index(write_ip);
                    ip_mem(widx)    <= write_ip;
                    mac_mem(widx)   <= write_mac;
                    valid_mem(widx) <= '1';
                end if;

                if query_valid = '1' then
                    qidx := cache_index(query_ip);
                    if valid_mem(qidx) = '1' and ip_mem(qidx) = query_ip then
                        hit_reg <= '1';
                        mac_reg <= mac_mem(qidx);
                    else
                        hit_reg <= '0';
                        mac_reg <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
