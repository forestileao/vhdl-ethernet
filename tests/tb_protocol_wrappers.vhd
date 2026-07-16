-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_protocol_wrappers is
end entity;

architecture sim of tb_protocol_wrappers is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant payload : byte_vec_t := (x"31", x"32", x"33");
    constant src_mac : mac_addr_t := x"020000000123";
    constant src_ip  : ipv4_addr_t := x"0A010203";
    constant dst_ip  : ipv4_addr_t := x"0A010204";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal arp_req_valid : std_logic := '0';
    signal arp_req_ready : std_logic;
    signal arp_data : byte_t;
    signal arp_valid : std_logic;
    signal arp_ready : std_logic;
    signal arp_last : std_logic;
    signal arp_user : std_logic;
    signal arp_rx_valid : std_logic;
    signal arp_rx_oper : word16_t;
    signal arp_rx_sha : mac_addr_t;
    signal arp_rx_spa : ipv4_addr_t;
    signal arp_rx_tha : mac_addr_t;
    signal arp_rx_tpa : ipv4_addr_t;
    signal arp_bad : std_logic;
    signal arp_done : boolean := false;

    signal pause_valid : std_logic := '0';
    signal pause_ready : std_logic;
    signal pause_data : byte_t;
    signal pause_axis_valid : std_logic;
    signal pause_axis_ready : std_logic;
    signal pause_last : std_logic;
    signal pause_user : std_logic;
    signal pause_rx_valid : std_logic;
    signal pause_rx_src : mac_addr_t;
    signal pause_rx_quanta : word16_t;
    signal pause_bad : std_logic;
    signal pause_done : boolean := false;

    signal udp_hdr_valid : std_logic := '0';
    signal udp_hdr_ready : std_logic;
    signal udp_tx_data : byte_t := (others => '0');
    signal udp_tx_valid : std_logic := '0';
    signal udp_tx_ready : std_logic;
    signal udp_tx_last : std_logic := '0';
    signal udp_ip_data : byte_t;
    signal udp_ip_valid : std_logic;
    signal udp_ip_ready : std_logic;
    signal udp_ip_last : std_logic;
    signal udp_ip_user : std_logic;
    signal udp_rx_hdr_valid : std_logic;
    signal udp_rx_src_ip : ipv4_addr_t;
    signal udp_rx_dst_ip : ipv4_addr_t;
    signal udp_rx_src_port : word16_t;
    signal udp_rx_dst_port : word16_t;
    signal udp_rx_len : word16_t;
    signal udp_rx_data : byte_t;
    signal udp_rx_valid : std_logic;
    signal udp_rx_last : std_logic;
    signal udp_rx_user : std_logic;
    signal udp_ip_bad : std_logic;
    signal udp_bad : std_logic;
    signal udp_done : boolean := false;

    procedure send_payload(
        signal clk_i : in std_logic;
        signal data  : out byte_t;
        signal valid : out std_logic;
        signal ready : in std_logic;
        signal last  : out std_logic;
        constant bytes : in byte_vec_t
    ) is
    begin
        for i in bytes'range loop
            data <= bytes(i);
            valid <= '1';
            if i = bytes'high then
                last <= '1';
            else
                last <= '0';
            end if;
            loop
                wait until rising_edge(clk_i);
                exit when ready = '1';
            end loop;
        end loop;
        data <= (others => '0');
        valid <= '0';
        last <= '0';
    end procedure;
begin
    clk <= not clk after 5 ns;

    arp: entity work.arp_stack
        port map (
            clk => clk,
            rst => rst,
            tx_hdr_valid => arp_req_valid,
            tx_hdr_ready => arp_req_ready,
            tx_oper => x"0001",
            tx_sender_mac => src_mac,
            tx_sender_ip => src_ip,
            tx_target_mac => x"000000000000",
            tx_target_ip => dst_ip,
            tx_axis_tdata => arp_data,
            tx_axis_tvalid => arp_valid,
            tx_axis_tready => arp_ready,
            tx_axis_tlast => arp_last,
            tx_axis_tuser => arp_user,
            rx_axis_tdata => arp_data,
            rx_axis_tvalid => arp_valid,
            rx_axis_tready => arp_ready,
            rx_axis_tlast => arp_last,
            rx_axis_tuser => arp_user,
            rx_hdr_valid => arp_rx_valid,
            rx_hdr_ready => '1',
            rx_oper => arp_rx_oper,
            rx_sender_mac => arp_rx_sha,
            rx_sender_ip => arp_rx_spa,
            rx_target_mac => arp_rx_tha,
            rx_target_ip => arp_rx_tpa,
            rx_error_bad_packet => arp_bad
        );

    pause_tx: entity work.mac_control_tx
        port map (
            clk => clk,
            rst => rst,
            pause_valid => pause_valid,
            pause_ready => pause_ready,
            source_mac => src_mac,
            pause_quanta => x"00FF",
            m_axis_tdata => pause_data,
            m_axis_tvalid => pause_axis_valid,
            m_axis_tready => pause_axis_ready,
            m_axis_tlast => pause_last,
            m_axis_tuser => pause_user
        );

    pause_rx: entity work.mac_control_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => pause_data,
            s_axis_tvalid => pause_axis_valid,
            s_axis_tready => pause_axis_ready,
            s_axis_tlast => pause_last,
            s_axis_tuser => pause_user,
            pause_valid => pause_rx_valid,
            pause_ready => '1',
            source_mac => pause_rx_src,
            pause_quanta => pause_rx_quanta,
            error_bad_frame => pause_bad
        );

    udp_complete: entity work.udp_ipv4_complete
        port map (
            clk => clk,
            rst => rst,
            tx_hdr_valid => udp_hdr_valid,
            tx_hdr_ready => udp_hdr_ready,
            tx_source_ip => src_ip,
            tx_target_ip => dst_ip,
            tx_identification => x"1234",
            tx_source_port => x"1111",
            tx_target_port => x"2222",
            tx_payload_length => std_logic_vector(to_unsigned(payload'length, 16)),
            tx_payload_tdata => udp_tx_data,
            tx_payload_tvalid => udp_tx_valid,
            tx_payload_tready => udp_tx_ready,
            tx_payload_tlast => udp_tx_last,
            tx_payload_tuser => '0',
            tx_ip_tdata => udp_ip_data,
            tx_ip_tvalid => udp_ip_valid,
            tx_ip_tready => udp_ip_ready,
            tx_ip_tlast => udp_ip_last,
            tx_ip_tuser => udp_ip_user,
            rx_ip_tdata => udp_ip_data,
            rx_ip_tvalid => udp_ip_valid,
            rx_ip_tready => udp_ip_ready,
            rx_ip_tlast => udp_ip_last,
            rx_ip_tuser => udp_ip_user,
            rx_hdr_valid => udp_rx_hdr_valid,
            rx_hdr_ready => '1',
            rx_source_ip => udp_rx_src_ip,
            rx_target_ip => udp_rx_dst_ip,
            rx_source_port => udp_rx_src_port,
            rx_target_port => udp_rx_dst_port,
            rx_payload_length => udp_rx_len,
            rx_payload_tdata => udp_rx_data,
            rx_payload_tvalid => udp_rx_valid,
            rx_payload_tready => '1',
            rx_payload_tlast => udp_rx_last,
            rx_payload_tuser => udp_rx_user,
            rx_error_bad_ip_header => udp_ip_bad,
            rx_error_bad_udp_header => udp_bad
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        arp_req_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when arp_req_ready = '1';
        end loop;
        arp_req_valid <= '0';

        pause_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when pause_ready = '1';
        end loop;
        pause_valid <= '0';

        udp_hdr_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when udp_hdr_ready = '1';
        end loop;
        udp_hdr_valid <= '0';
        send_payload(clk, udp_tx_data, udp_tx_valid, udp_tx_ready, udp_tx_last, payload);

        for i in 0 to 250 loop
            wait until rising_edge(clk);
            exit when arp_done and pause_done and udp_done;
        end loop;

        assert arp_done report "ARP stack wrapper timed out" severity failure;
        assert pause_done report "MAC pause control wrapper timed out" severity failure;
        assert udp_done report "UDP/IP complete wrapper timed out" severity failure;
        assert arp_bad = '0' report "ARP wrapper reported bad packet" severity failure;
        assert pause_bad = '0' report "pause control wrapper reported bad frame" severity failure;
        assert udp_ip_bad = '0' report "UDP/IP wrapper reported bad IP header" severity failure;
        assert udp_bad = '0' report "UDP/IP wrapper reported bad UDP header" severity failure;
        finish;
    end process;

    checks: process (clk)
        variable udp_pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                arp_done <= false;
                pause_done <= false;
                udp_done <= false;
                udp_pos := 0;
            else
                if arp_rx_valid = '1' then
                    assert arp_rx_oper = x"0001" report "ARP wrapper operation mismatch" severity failure;
                    assert arp_rx_sha = src_mac report "ARP wrapper sender MAC mismatch" severity failure;
                    assert arp_rx_spa = src_ip report "ARP wrapper sender IP mismatch" severity failure;
                    assert arp_rx_tpa = dst_ip report "ARP wrapper target IP mismatch" severity failure;
                    arp_done <= true;
                end if;

                if pause_rx_valid = '1' then
                    assert pause_rx_src = src_mac report "pause source MAC mismatch" severity failure;
                    assert pause_rx_quanta = x"00FF" report "pause quanta mismatch" severity failure;
                    pause_done <= true;
                end if;

                if udp_rx_hdr_valid = '1' then
                    assert udp_rx_src_ip = src_ip report "UDP/IP source IP mismatch" severity failure;
                    assert udp_rx_dst_ip = dst_ip report "UDP/IP target IP mismatch" severity failure;
                    assert udp_rx_src_port = x"1111" report "UDP/IP source port mismatch" severity failure;
                    assert udp_rx_dst_port = x"2222" report "UDP/IP target port mismatch" severity failure;
                    assert udp_rx_len = std_logic_vector(to_unsigned(payload'length, 16)) report "UDP/IP payload length mismatch" severity failure;
                end if;

                if udp_rx_valid = '1' then
                    assert udp_rx_data = payload(udp_pos) report "UDP/IP payload mismatch" severity failure;
                    assert udp_rx_user = '0' report "UDP/IP payload user mismatch" severity failure;
                    if udp_rx_last = '1' then
                        assert udp_pos = payload'length - 1 report "UDP/IP payload ended early" severity failure;
                        udp_done <= true;
                    end if;
                    udp_pos := udp_pos + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
