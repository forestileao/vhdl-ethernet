-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_ipv4_udp64 is
end entity;

architecture sim of tb_ipv4_udp64 is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant payload : byte_vec_t := (
        x"41", x"58", x"49", x"36", x"34", x"2D", x"55", x"44", x"50"
    );
    constant src_ip  : ipv4_addr_t := x"C0A80110";
    constant dst_ip  : ipv4_addr_t := x"C0A80120";
    constant src_prt : word16_t := x"1001";
    constant dst_prt : word16_t := x"2002";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal hdr_valid : std_logic := '0';
    signal hdr_ready : std_logic;
    signal tx_p_data : word64_t := (others => '0');
    signal tx_p_keep : keep8_t := (others => '0');
    signal tx_p_valid : std_logic := '0';
    signal tx_p_ready : std_logic;
    signal tx_p_last : std_logic := '0';

    signal ip_data : word64_t;
    signal ip_keep : keep8_t;
    signal ip_valid : std_logic;
    signal ip_ready : std_logic;
    signal ip_last : std_logic;
    signal ip_user : std_logic;

    signal rx_hdr_valid : std_logic;
    signal rx_src_ip : ipv4_addr_t;
    signal rx_dst_ip : ipv4_addr_t;
    signal rx_src_prt : word16_t;
    signal rx_dst_prt : word16_t;
    signal rx_len : word16_t;
    signal rx_p_data : word64_t;
    signal rx_p_keep : keep8_t;
    signal rx_p_valid : std_logic;
    signal rx_p_last : std_logic;
    signal rx_p_user : std_logic;
    signal bad_ip : std_logic;
    signal bad_udp : std_logic;
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns;
    dut: entity work.udp_ipv4_complete64
        port map (
            clk => clk,
            rst => rst,
            tx_hdr_valid => hdr_valid,
            tx_hdr_ready => hdr_ready,
            tx_source_ip => src_ip,
            tx_target_ip => dst_ip,
            tx_identification => x"BEEF",
            tx_source_port => src_prt,
            tx_target_port => dst_prt,
            tx_payload_length => std_logic_vector(to_unsigned(payload'length, 16)),
            tx_payload_tdata => tx_p_data,
            tx_payload_tkeep => tx_p_keep,
            tx_payload_tvalid => tx_p_valid,
            tx_payload_tready => tx_p_ready,
            tx_payload_tlast => tx_p_last,
            tx_payload_tuser => '0',
            tx_ip_tdata => ip_data,
            tx_ip_tkeep => ip_keep,
            tx_ip_tvalid => ip_valid,
            tx_ip_tready => ip_ready,
            tx_ip_tlast => ip_last,
            tx_ip_tuser => ip_user,
            rx_ip_tdata => ip_data,
            rx_ip_tkeep => ip_keep,
            rx_ip_tvalid => ip_valid,
            rx_ip_tready => ip_ready,
            rx_ip_tlast => ip_last,
            rx_ip_tuser => ip_user,
            rx_hdr_valid => rx_hdr_valid,
            rx_hdr_ready => '1',
            rx_source_ip => rx_src_ip,
            rx_target_ip => rx_dst_ip,
            rx_source_port => rx_src_prt,
            rx_target_port => rx_dst_prt,
            rx_payload_length => rx_len,
            rx_payload_tdata => rx_p_data,
            rx_payload_tkeep => rx_p_keep,
            rx_payload_tvalid => rx_p_valid,
            rx_payload_tready => '1',
            rx_payload_tlast => rx_p_last,
            rx_payload_tuser => rx_p_user,
            rx_error_bad_ip_header => bad_ip,
            rx_error_bad_udp_header => bad_udp
        );

    stimulus: process
        variable word_v : word64_t;
        variable keep_v : keep8_t;
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        hdr_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when hdr_ready = '1';
        end loop;
        hdr_valid <= '0';

        word_v := (others => '0');
        keep_v := (others => '0');
        for i in 0 to 7 loop
            word_v(i * 8 + 7 downto i * 8) := payload(i);
            keep_v(i) := '1';
        end loop;
        tx_p_data <= word_v;
        tx_p_keep <= keep_v;
        tx_p_valid <= '1';
        tx_p_last <= '0';
        wait until rising_edge(clk) and tx_p_ready = '1';

        word_v := (others => '0');
        keep_v := (others => '0');
        word_v(7 downto 0) := payload(8);
        keep_v(0) := '1';
        tx_p_data <= word_v;
        tx_p_keep <= keep_v;
        tx_p_last <= '1';
        wait until rising_edge(clk) and tx_p_ready = '1';
        tx_p_valid <= '0';
        tx_p_last <= '0';

        for i in 0 to 300 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "64-bit UDP/IP payload did not complete" severity failure;
        assert bad_ip = '0' report "64-bit IPv4 wrapper reported bad header" severity failure;
        assert bad_udp = '0' report "64-bit UDP wrapper reported bad header" severity failure;
        report "simulation finished" severity note;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
            else
                if rx_hdr_valid = '1' then
                    assert rx_src_ip = src_ip report "64-bit source IP mismatch" severity failure;
                    assert rx_dst_ip = dst_ip report "64-bit target IP mismatch" severity failure;
                    assert rx_src_prt = src_prt report "64-bit source port mismatch" severity failure;
                    assert rx_dst_prt = dst_prt report "64-bit target port mismatch" severity failure;
                    assert rx_len = std_logic_vector(to_unsigned(payload'length, 16))
                        report "64-bit payload length mismatch" severity failure;
                end if;

                if rx_p_valid = '1' then
                    assert rx_p_user = '0' report "64-bit payload user error" severity failure;
                    for lane in 0 to 7 loop
                        if rx_p_keep(lane) = '1' then
                            assert pos < payload'length report "64-bit payload too long" severity failure;
                            assert lane_byte(rx_p_data, lane) = payload(pos)
                                report "64-bit payload byte mismatch" severity failure;
                            pos := pos + 1;
                        end if;
                    end loop;
                    if rx_p_last = '1' then
                        assert pos = payload'length report "64-bit payload length mismatch at end" severity failure;
                        done <= true;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
