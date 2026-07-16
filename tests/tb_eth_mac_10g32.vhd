-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_eth_mac_10g32 is
end entity;

architecture sim of tb_eth_mac_10g32 is
    type frame_t is array (natural range <>) of byte_t;
    constant payload : frame_t := (
        x"30", x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38"
    );

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal tx_data : word64_t := (others => '0');
    signal tx_keep : keep8_t := (others => '0');
    signal tx_valid : std_logic := '0';
    signal tx_ready : std_logic;
    signal tx_last : std_logic := '0';
    signal rx_data : word64_t;
    signal rx_keep : keep8_t;
    signal rx_valid : std_logic;
    signal rx_last : std_logic;
    signal rx_user : std_logic;
    signal xgmii_d : word32_t;
    signal xgmii_c : keep4_t;
    signal bad_frame : std_logic;
    signal bad_fcs : std_logic;
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.eth_mac_10g32
        generic map (
            MAX_FRAME_BYTES => 64
        )
        port map (
            clk => clk,
            rst => rst,
            tx_axis_tdata => tx_data,
            tx_axis_tkeep => tx_keep,
            tx_axis_tvalid => tx_valid,
            tx_axis_tready => tx_ready,
            tx_axis_tlast => tx_last,
            tx_axis_tuser => '0',
            rx_axis_tdata => rx_data,
            rx_axis_tkeep => rx_keep,
            rx_axis_tvalid => rx_valid,
            rx_axis_tready => '1',
            rx_axis_tlast => rx_last,
            rx_axis_tuser => rx_user,
            xgmii_txd => xgmii_d,
            xgmii_txc => xgmii_c,
            xgmii_rxd => xgmii_d,
            xgmii_rxc => xgmii_c,
            tx_busy => open,
            rx_error_bad_frame => bad_frame,
            rx_error_bad_fcs => bad_fcs
        );

    stimulus: process
        variable word_v : word64_t;
        variable keep_v : keep8_t;
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        word_v := (others => '0');
        keep_v := (others => '0');
        for i in 0 to 7 loop
            word_v(i * 8 + 7 downto i * 8) := payload(i);
            keep_v(i) := '1';
        end loop;
        tx_data <= word_v;
        tx_keep <= keep_v;
        tx_valid <= '1';
        tx_last <= '0';
        wait until rising_edge(clk) and tx_ready = '1';

        word_v := (others => '0');
        keep_v := (others => '0');
        word_v(7 downto 0) := payload(8);
        keep_v(0) := '1';
        tx_data <= word_v;
        tx_keep <= keep_v;
        tx_last <= '1';
        wait until rising_edge(clk) and tx_ready = '1';
        tx_valid <= '0';
        tx_last <= '0';

        for i in 0 to 300 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "32-bit XGMII loopback did not complete" severity failure;
        assert bad_frame = '0' report "32-bit XGMII bad frame flag" severity failure;
        assert bad_fcs = '0' report "32-bit XGMII bad FCS flag" severity failure;
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
            elsif rx_valid = '1' then
                assert rx_user = '0' report "32-bit XGMII RX user error" severity failure;
                for lane in 0 to 7 loop
                    if rx_keep(lane) = '1' then
                        assert pos < payload'length report "32-bit XGMII output too long" severity failure;
                        assert lane_byte(rx_data, lane) = payload(pos)
                            report "32-bit XGMII payload mismatch" severity failure;
                        pos := pos + 1;
                    end if;
                end loop;
                if rx_last = '1' then
                    assert pos = payload'length report "32-bit XGMII payload length mismatch" severity failure;
                    done <= true;
                end if;
            end if;
        end if;
    end process;
end architecture;
