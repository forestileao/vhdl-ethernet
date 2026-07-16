-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_arp is
end entity;

architecture sim of tb_arp is
    constant oper       : word16_t := x"0001";
    constant sender_mac : mac_addr_t := x"020000000001";
    constant sender_ip  : ipv4_addr_t := x"C0A80164";
    constant target_mac : mac_addr_t := x"000000000000";
    constant target_ip  : ipv4_addr_t := x"C0A80101";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal req_valid : std_logic := '0';
    signal req_ready : std_logic;
    signal data      : byte_t;
    signal valid     : std_logic;
    signal ready     : std_logic;
    signal last      : std_logic;
    signal user      : std_logic;

    signal pkt_valid  : std_logic;
    signal pkt_ready  : std_logic := '1';
    signal rx_oper    : word16_t;
    signal rx_sha     : mac_addr_t;
    signal rx_spa     : ipv4_addr_t;
    signal rx_tha     : mac_addr_t;
    signal rx_tpa     : ipv4_addr_t;
    signal bad_packet : std_logic;
    signal done       : boolean := false;
begin
    clk <= not clk after 5 ns;

    tx: entity work.arp_eth_tx
        port map (
            clk => clk, rst => rst,
            s_request_valid => req_valid, s_request_ready => req_ready,
            s_oper => oper, s_sender_mac => sender_mac, s_sender_ip => sender_ip,
            s_target_mac => target_mac, s_target_ip => target_ip,
            m_axis_tdata => data, m_axis_tvalid => valid, m_axis_tready => ready,
            m_axis_tlast => last, m_axis_tuser => user
        );

    rx: entity work.arp_eth_rx
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => data, s_axis_tvalid => valid, s_axis_tready => ready,
            s_axis_tlast => last, s_axis_tuser => user,
            m_packet_valid => pkt_valid, m_packet_ready => pkt_ready,
            m_oper => rx_oper, m_sender_mac => rx_sha, m_sender_ip => rx_spa,
            m_target_mac => rx_tha, m_target_ip => rx_tpa,
            error_bad_packet => bad_packet
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        req_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when req_ready = '1';
        end loop;
        req_valid <= '0';

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "ARP packet was not decoded" severity failure;
        assert bad_packet = '0' report "ARP RX reported a bad packet" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                done <= false;
            elsif pkt_valid = '1' and pkt_ready = '1' then
                assert rx_oper = oper report "ARP operation mismatch" severity failure;
                assert rx_sha = sender_mac report "ARP sender MAC mismatch" severity failure;
                assert rx_spa = sender_ip report "ARP sender IP mismatch" severity failure;
                assert rx_tha = target_mac report "ARP target MAC mismatch" severity failure;
                assert rx_tpa = target_ip report "ARP target IP mismatch" severity failure;
                done <= true;
            end if;
        end if;
    end process;
end architecture;
