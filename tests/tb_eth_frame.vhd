-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_eth_frame is
end entity;

architecture sim of tb_eth_frame is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant payload : byte_vec_t := (x"11", x"22", x"33", x"44");
    constant dst_mac : mac_addr_t := x"DA0203040506";
    constant src_mac : mac_addr_t := x"5A1020304050";
    constant eth_typ : word16_t := x"88B5";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal hdr_valid : std_logic := '0';
    signal hdr_ready : std_logic;
    signal p_data    : byte_t := (others => '0');
    signal p_valid   : std_logic := '0';
    signal p_ready   : std_logic;
    signal p_last    : std_logic := '0';
    signal p_user    : std_logic := '0';

    signal wire_data  : byte_t;
    signal wire_valid : std_logic;
    signal wire_ready : std_logic;
    signal wire_last  : std_logic;
    signal wire_user  : std_logic;

    signal rx_hdr_valid : std_logic;
    signal rx_hdr_ready : std_logic := '1';
    signal rx_dst_mac   : mac_addr_t;
    signal rx_src_mac   : mac_addr_t;
    signal rx_eth_typ   : word16_t;
    signal rx_data      : byte_t;
    signal rx_valid     : std_logic;
    signal rx_ready     : std_logic := '1';
    signal rx_last      : std_logic;
    signal rx_user      : std_logic;
    signal hdr_early    : std_logic;
    signal seen_hdr     : boolean := false;
    signal done         : boolean := false;

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

    tx: entity work.eth_axis_tx
        port map (
            clk => clk, rst => rst,
            s_hdr_valid => hdr_valid, s_hdr_ready => hdr_ready,
            s_eth_dest_mac => dst_mac, s_eth_src_mac => src_mac, s_eth_type => eth_typ,
            s_axis_payload_tdata => p_data, s_axis_payload_tvalid => p_valid,
            s_axis_payload_tready => p_ready, s_axis_payload_tlast => p_last, s_axis_payload_tuser => p_user,
            m_axis_tdata => wire_data, m_axis_tvalid => wire_valid, m_axis_tready => wire_ready,
            m_axis_tlast => wire_last, m_axis_tuser => wire_user
        );

    rx: entity work.eth_axis_rx
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => wire_data, s_axis_tvalid => wire_valid, s_axis_tready => wire_ready,
            s_axis_tlast => wire_last, s_axis_tuser => wire_user,
            m_hdr_valid => rx_hdr_valid, m_hdr_ready => rx_hdr_ready,
            m_eth_dest_mac => rx_dst_mac, m_eth_src_mac => rx_src_mac, m_eth_type => rx_eth_typ,
            m_axis_payload_tdata => rx_data, m_axis_payload_tvalid => rx_valid,
            m_axis_payload_tready => rx_ready, m_axis_payload_tlast => rx_last,
            m_axis_payload_tuser => rx_user, error_header_early => hdr_early
        );

    stimulus: process
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

        send_payload(clk, p_data, p_valid, p_ready, p_last, payload);

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert seen_hdr report "Ethernet header was not decoded" severity failure;
        assert done report "Ethernet payload did not complete" severity failure;
        assert hdr_early = '0' report "Ethernet RX reported an early header" severity failure;
        finish;
    end process;

    header_check: process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                seen_hdr <= false;
            elsif rx_hdr_valid = '1' and rx_hdr_ready = '1' then
                assert rx_dst_mac = dst_mac report "Ethernet destination MAC mismatch" severity failure;
                assert rx_src_mac = src_mac report "Ethernet source MAC mismatch" severity failure;
                assert rx_eth_typ = eth_typ report "Ethernet type mismatch" severity failure;
                seen_hdr <= true;
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
            elsif rx_valid = '1' and rx_ready = '1' then
                assert rx_data = payload(pos) report "Ethernet payload byte mismatch" severity failure;
                assert rx_user = '0' report "Ethernet payload user error flag set" severity failure;
                if rx_last = '1' then
                    assert pos = payload'length - 1 report "Ethernet payload ended early/late" severity failure;
                    done <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
