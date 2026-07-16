-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_fcs64 is
end entity;

architecture sim of tb_fcs64 is
    type frame_t is array (natural range <>) of byte_t;
    constant PAYLOAD : frame_t := (
        x"DA", x"02", x"03", x"04", x"05", x"06", x"11", x"22", x"33", x"44", x"55"
    );

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal s_data : word64_t := (others => '0');
    signal s_keep : keep8_t := (others => '0');
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_last : std_logic := '0';

    signal f_data : word64_t;
    signal f_keep : keep8_t;
    signal f_valid : std_logic;
    signal f_ready : std_logic;
    signal f_last : std_logic;
    signal f_user : std_logic;

    signal m_data : word64_t;
    signal m_keep : keep8_t;
    signal m_valid : std_logic;
    signal m_last : std_logic;
    signal m_user : std_logic;
    signal bad_frame : std_logic;
    signal bad_fcs : std_logic;
begin
    clk <= not clk after 5 ns;
    f_ready <= '1';

    append: entity work.axis64_eth_fcs_append
        generic map (
            MAX_FRAME_BYTES => 64
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => s_data,
            s_axis_tkeep => s_keep,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tlast => s_last,
            s_axis_tuser => '0',
            m_axis_tdata => f_data,
            m_axis_tkeep => f_keep,
            m_axis_tvalid => f_valid,
            m_axis_tready => f_ready,
            m_axis_tlast => f_last,
            m_axis_tuser => f_user
        );

    strip: entity work.axis64_eth_fcs_strip
        generic map (
            MAX_FRAME_BYTES => 64
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => f_data,
            s_axis_tkeep => f_keep,
            s_axis_tvalid => f_valid,
            s_axis_tready => open,
            s_axis_tlast => f_last,
            s_axis_tuser => f_user,
            m_axis_tdata => m_data,
            m_axis_tkeep => m_keep,
            m_axis_tvalid => m_valid,
            m_axis_tready => '1',
            m_axis_tlast => m_last,
            m_axis_tuser => m_user,
            error_bad_frame => bad_frame,
            error_bad_fcs => bad_fcs
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
            word_v(i * 8 + 7 downto i * 8) := PAYLOAD(i);
            keep_v(i) := '1';
        end loop;
        s_data <= word_v;
        s_keep <= keep_v;
        s_valid <= '1';
        s_last <= '0';
        wait until rising_edge(clk) and s_ready = '1';

        word_v := (others => '0');
        keep_v := (others => '0');
        for i in 0 to 2 loop
            word_v(i * 8 + 7 downto i * 8) := PAYLOAD(i + 8);
            keep_v(i) := '1';
        end loop;
        s_data <= word_v;
        s_keep <= keep_v;
        s_last <= '1';
        wait until rising_edge(clk) and s_ready = '1';
        s_valid <= '0';
        s_last <= '0';

        wait for 300 ns;
        assert false report "FCS64 test timed out" severity failure;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
            elsif m_valid = '1' then
                assert m_user = '0' report "FCS64 output user error" severity failure;
                assert bad_frame = '0' report "FCS64 bad frame flag" severity failure;
                assert bad_fcs = '0' report "FCS64 bad FCS flag" severity failure;
                for lane in 0 to 7 loop
                    if m_keep(lane) = '1' then
                        assert pos < PAYLOAD'length report "FCS64 output too long" severity failure;
                        assert lane_byte(m_data, lane) = PAYLOAD(pos)
                            report "FCS64 data mismatch" severity failure;
                        pos := pos + 1;
                    end if;
                end loop;
                if m_last = '1' then
                    assert pos = PAYLOAD'length report "FCS64 output length mismatch" severity failure;
                    report "simulation finished" severity note;
                    finish;
                end if;
            end if;
        end if;
    end process;
end architecture;
