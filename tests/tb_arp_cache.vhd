-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_arp_cache is
end entity;

architecture sim of tb_arp_cache is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal clear : std_logic := '0';
    signal write_valid : std_logic := '0';
    signal write_ip : ipv4_addr_t := (others => '0');
    signal write_mac : mac_addr_t := (others => '0');
    signal query_valid : std_logic := '0';
    signal query_ip : ipv4_addr_t := (others => '0');
    signal query_ready : std_logic;
    signal query_hit : std_logic;
    signal query_mac : mac_addr_t;
begin
    clk <= not clk after 5 ns;

    dut: entity work.ether_arp_cache
        generic map (ENTRY_COUNT => 8)
        port map (
            clk => clk,
            rst => rst,
            clear => clear,
            write_valid => write_valid,
            write_ip => write_ip,
            write_mac => write_mac,
            query_valid => query_valid,
            query_ip => query_ip,
            query_ready => query_ready,
            query_hit => query_hit,
            query_mac => query_mac
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        write_ip <= x"C0A80101";
        write_mac <= x"020000000001";
        write_valid <= '1';
        wait until rising_edge(clk);
        write_valid <= '0';

        query_ip <= x"C0A80101";
        query_valid <= '1';
        wait until rising_edge(clk);
        query_valid <= '0';
        wait until rising_edge(clk);
        assert query_ready = '1' report "ARP cache query_ready mismatch" severity failure;
        assert query_hit = '1' report "ARP cache did not hit" severity failure;
        assert query_mac = x"020000000001" report "ARP cache MAC mismatch" severity failure;

        query_ip <= x"C0A80102";
        query_valid <= '1';
        wait until rising_edge(clk);
        query_valid <= '0';
        wait until rising_edge(clk);
        assert query_hit = '0' report "ARP cache false hit" severity failure;

        clear <= '1';
        wait until rising_edge(clk);
        clear <= '0';
        query_ip <= x"C0A80101";
        query_valid <= '1';
        wait until rising_edge(clk);
        query_valid <= '0';
        wait until rising_edge(clk);
        assert query_hit = '0' report "ARP cache hit after clear" severity failure;

        finish;
    end process;
end architecture;
