-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_ipv4_udp is
end entity;

architecture sim of tb_ipv4_udp is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant payload : byte_vec_t := (x"48", x"45", x"4C", x"4C", x"4F");
    constant src_ip  : ipv4_addr_t := x"0A000001";
    constant dst_ip  : ipv4_addr_t := x"0A000002";
    constant src_prt : word16_t := x"1234";
    constant dst_prt : word16_t := x"5678";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal udp_hdr_valid : std_logic := '0';
    signal udp_hdr_ready : std_logic;
    signal udp_p_data    : byte_t := (others => '0');
    signal udp_p_valid   : std_logic := '0';
    signal udp_p_ready   : std_logic;
    signal udp_p_last    : std_logic := '0';
    signal udp_p_user    : std_logic := '0';

    signal udp_data  : byte_t;
    signal udp_valid : std_logic;
    signal udp_ready : std_logic;
    signal udp_last  : std_logic;
    signal udp_user  : std_logic;

    signal ip_hdr_valid : std_logic := '0';
    signal ip_hdr_ready : std_logic;
    signal ip_data      : byte_t;
    signal ip_valid     : std_logic;
    signal ip_ready     : std_logic;
    signal ip_last      : std_logic;
    signal ip_user      : std_logic;

    signal rx_ip_hdr_valid : std_logic;
    signal rx_ip_hdr_ready : std_logic := '1';
    signal rx_ip_len       : word16_t;
    signal rx_ip_id        : word16_t;
    signal rx_ip_frag      : word16_t;
    signal rx_ip_ttl       : byte_t;
    signal rx_ip_proto     : byte_t;
    signal rx_src_ip       : ipv4_addr_t;
    signal rx_dst_ip       : ipv4_addr_t;
    signal ip_bad          : std_logic;

    signal rx_udp_data  : byte_t;
    signal rx_udp_valid : std_logic;
    signal rx_udp_ready : std_logic;
    signal rx_udp_last  : std_logic;
    signal rx_udp_user  : std_logic;

    signal rx_udp_hdr_valid : std_logic;
    signal rx_udp_hdr_ready : std_logic := '1';
    signal rx_src_prt       : word16_t;
    signal rx_dst_prt       : word16_t;
    signal rx_udp_len       : word16_t;
    signal final_data       : byte_t;
    signal final_valid      : std_logic;
    signal final_last       : std_logic;
    signal final_user       : std_logic;
    signal udp_bad          : std_logic;
    signal seen_ip_hdr      : boolean := false;
    signal seen_udp_hdr     : boolean := false;
    signal done             : boolean := false;

    procedure send_payload(
        signal clk_i   : in std_logic;
        signal data    : out byte_t;
        signal valid   : out std_logic;
        signal ready   : in std_logic;
        signal last    : out std_logic;
        constant bytes : in byte_vec_t
    ) is
    begin
        for i in bytes'range loop
            data  <= bytes(i);
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
        valid <= '0';
        last  <= '0';
        data  <= (others => '0');
    end procedure;
begin
    clk <= not clk after 5 ns;

    udp_encoder: entity work.udp_tx
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => udp_hdr_valid, s_hdr_ready => udp_hdr_ready,
            s_source_port => src_prt, s_target_port => dst_prt,
            s_payload_length => std_logic_vector(to_unsigned(payload'length, 16)),
            s_axis_payload_tdata => udp_p_data, s_axis_payload_tvalid => udp_p_valid,
            s_axis_payload_tready => udp_p_ready, s_axis_payload_tlast => udp_p_last,
            s_axis_payload_tuser => udp_p_user,
            m_axis_tdata => udp_data, m_axis_tvalid => udp_valid, m_axis_tready => udp_ready,
            m_axis_tlast => udp_last, m_axis_tuser => udp_user
        );

    ip_encoder: entity work.ipv4_tx
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => ip_hdr_valid, s_hdr_ready => ip_hdr_ready,
            s_payload_length => std_logic_vector(to_unsigned(payload'length + 8, 16)),
            s_identification => x"CAFE", s_flags_fragment => x"4000",
            s_ttl => x"40", s_protocol => x"11",
            s_source_ip => src_ip, s_target_ip => dst_ip,
            s_axis_payload_tdata => udp_data, s_axis_payload_tvalid => udp_valid,
            s_axis_payload_tready => udp_ready, s_axis_payload_tlast => udp_last,
            s_axis_payload_tuser => udp_user,
            m_axis_tdata => ip_data, m_axis_tvalid => ip_valid, m_axis_tready => ip_ready,
            m_axis_tlast => ip_last, m_axis_tuser => ip_user
        );

    ip_decoder: entity work.ipv4_rx
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => ip_data, s_axis_tvalid => ip_valid, s_axis_tready => ip_ready,
            s_axis_tlast => ip_last, s_axis_tuser => ip_user,
            m_hdr_valid => rx_ip_hdr_valid, m_hdr_ready => rx_ip_hdr_ready,
            m_payload_length => rx_ip_len, m_identification => rx_ip_id,
            m_flags_fragment => rx_ip_frag, m_ttl => rx_ip_ttl, m_protocol => rx_ip_proto,
            m_source_ip => rx_src_ip, m_target_ip => rx_dst_ip,
            m_axis_payload_tdata => rx_udp_data, m_axis_payload_tvalid => rx_udp_valid,
            m_axis_payload_tready => rx_udp_ready, m_axis_payload_tlast => rx_udp_last,
            m_axis_payload_tuser => rx_udp_user, error_bad_header => ip_bad
        );

    udp_decoder: entity work.udp_rx
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => rx_udp_data, s_axis_tvalid => rx_udp_valid, s_axis_tready => rx_udp_ready,
            s_axis_tlast => rx_udp_last, s_axis_tuser => rx_udp_user,
            m_hdr_valid => rx_udp_hdr_valid, m_hdr_ready => rx_udp_hdr_ready,
            m_source_port => rx_src_prt, m_target_port => rx_dst_prt, m_payload_length => rx_udp_len,
            m_axis_payload_tdata => final_data, m_axis_payload_tvalid => final_valid,
            m_axis_payload_tready => '1', m_axis_payload_tlast => final_last,
            m_axis_payload_tuser => final_user, error_bad_header => udp_bad
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        udp_hdr_valid <= '1';
        ip_hdr_valid  <= '1';
        loop
            wait until rising_edge(clk);
            exit when udp_hdr_ready = '1' and ip_hdr_ready = '1';
        end loop;
        udp_hdr_valid <= '0';
        ip_hdr_valid  <= '0';

        send_payload(clk, udp_p_data, udp_p_valid, udp_p_ready, udp_p_last, payload);

        for i in 0 to 200 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert seen_ip_hdr report "IPv4 header was not decoded" severity failure;
        assert seen_udp_hdr report "UDP header was not decoded" severity failure;
        assert done report "UDP payload did not complete" severity failure;
        assert ip_bad = '0' report "IPv4 RX reported a bad header" severity failure;
        assert udp_bad = '0' report "UDP RX reported a bad header" severity failure;
        finish;
    end process;

    header_checks: process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                seen_ip_hdr  <= false;
                seen_udp_hdr <= false;
            else
                if rx_ip_hdr_valid = '1' and rx_ip_hdr_ready = '1' then
                    assert rx_ip_len = std_logic_vector(to_unsigned(payload'length + 8, 16)) report "IPv4 payload length mismatch" severity failure;
                    assert rx_ip_id = x"CAFE" report "IPv4 identification mismatch" severity failure;
                    assert rx_ip_frag = x"4000" report "IPv4 flags/fragment mismatch" severity failure;
                    assert rx_ip_ttl = x"40" report "IPv4 TTL mismatch" severity failure;
                    assert rx_ip_proto = x"11" report "IPv4 protocol mismatch" severity failure;
                    assert rx_src_ip = src_ip report "IPv4 source mismatch" severity failure;
                    assert rx_dst_ip = dst_ip report "IPv4 target mismatch" severity failure;
                    seen_ip_hdr <= true;
                end if;

                if rx_udp_hdr_valid = '1' and rx_udp_hdr_ready = '1' then
                    assert rx_src_prt = src_prt report "UDP source port mismatch" severity failure;
                    assert rx_dst_prt = dst_prt report "UDP target port mismatch" severity failure;
                    assert rx_udp_len = std_logic_vector(to_unsigned(payload'length, 16)) report "UDP payload length mismatch" severity failure;
                    seen_udp_hdr <= true;
                end if;
            end if;
        end if;
    end process;

    payload_check: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
            elsif final_valid = '1' then
                assert final_data = payload(pos) report "UDP payload byte mismatch" severity failure;
                assert final_user = '0' report "UDP payload user flag set" severity failure;
                if final_last = '1' then
                    assert pos = payload'length - 1 report "UDP payload ended at the wrong byte" severity failure;
                    done <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
