-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_baser_phy_10g is
end entity;

architecture sim of tb_baser_phy_10g is
    type frame_t is array (natural range <>) of byte_t;
    constant payload : frame_t := (
        x"A0", x"A1", x"A2", x"A3", x"A4", x"A5", x"A6", x"A7", x"A8", x"A9", x"AA"
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
    signal blk_h : std_logic_vector(1 downto 0);
    signal blk_d : word64_t;
    signal blk_v : std_logic;
    signal tx_encode_error : std_logic;
    signal rx_block_error : std_logic;
    signal bad_frame : std_logic;
    signal bad_fcs : std_logic;
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.eth_mac_phy_10g
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
            tx_block_header => blk_h,
            tx_block_data => blk_d,
            tx_block_valid => blk_v,
            rx_block_header => blk_h,
            rx_block_data => blk_d,
            rx_block_valid => blk_v,
            tx_busy => open,
            tx_encode_error => tx_encode_error,
            rx_block_error => rx_block_error,
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
        for i in 0 to 2 loop
            word_v(i * 8 + 7 downto i * 8) := payload(i + 8);
            keep_v(i) := '1';
        end loop;
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

        assert done report "BASE-R block loopback did not complete" severity failure;
        assert tx_encode_error = '0' report "BASE-R encode error" severity failure;
        assert rx_block_error = '0' report "BASE-R decode error" severity failure;
        assert bad_frame = '0' report "BASE-R MAC bad frame flag" severity failure;
        assert bad_fcs = '0' report "BASE-R MAC bad FCS flag" severity failure;
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
                assert rx_user = '0' report "BASE-R RX user error" severity failure;
                for lane in 0 to 7 loop
                    if rx_keep(lane) = '1' then
                        assert pos < payload'length report "BASE-R output too long" severity failure;
                        assert lane_byte(rx_data, lane) = payload(pos)
                            report "BASE-R payload mismatch" severity failure;
                        pos := pos + 1;
                    end if;
                end loop;
                if rx_last = '1' then
                    assert pos = payload'length report "BASE-R payload length mismatch" severity failure;
                    done <= true;
                end if;
            end if;
        end if;
    end process;
end architecture;
