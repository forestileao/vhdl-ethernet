-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_cobs is
end entity;

architecture sim of tb_axis_cobs is
    type frame_t is array (natural range <>) of byte_t;
    constant INPUT_FRAME : frame_t := (
        x"11", x"00", x"22", x"33", x"00", x"44", x"55", x"66"
    );

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal enc_s_data : byte_t := (others => '0');
    signal enc_s_valid : std_logic := '0';
    signal enc_s_ready : std_logic;
    signal enc_s_last : std_logic := '0';
    signal enc_s_user : std_logic := '0';

    signal enc_m_data : byte_t;
    signal enc_m_valid : std_logic;
    signal enc_m_ready : std_logic;
    signal enc_m_last : std_logic;
    signal enc_m_user : std_logic;
    signal dec_s_ready : std_logic;

    signal dec_m_data : byte_t;
    signal dec_m_valid : std_logic;
    signal dec_m_last : std_logic;
    signal dec_m_user : std_logic;
begin
    clk <= not clk after 5 ns;
    enc_m_ready <= dec_s_ready;

    encoder: entity work.axis_byte_cobs_encoder
        generic map (
            MAX_FRAME_BYTES => 64
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => enc_s_data,
            s_axis_tvalid => enc_s_valid,
            s_axis_tready => enc_s_ready,
            s_axis_tlast => enc_s_last,
            s_axis_tuser => enc_s_user,
            m_axis_tdata => enc_m_data,
            m_axis_tvalid => enc_m_valid,
            m_axis_tready => enc_m_ready,
            m_axis_tlast => enc_m_last,
            m_axis_tuser => enc_m_user
        );

    decoder: entity work.axis_byte_cobs_decoder
        generic map (
            MAX_FRAME_BYTES => 64
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => enc_m_data,
            s_axis_tvalid => enc_m_valid,
            s_axis_tready => dec_s_ready,
            s_axis_tlast => enc_m_last,
            s_axis_tuser => enc_m_user,
            m_axis_tdata => dec_m_data,
            m_axis_tvalid => dec_m_valid,
            m_axis_tready => '1',
            m_axis_tlast => dec_m_last,
            m_axis_tuser => dec_m_user
        );

    stimulus: process
        variable seen : natural := 0;
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        for i in INPUT_FRAME'range loop
            enc_s_data <= INPUT_FRAME(i);
            enc_s_valid <= '1';
            if i = INPUT_FRAME'high then
                enc_s_last <= '1';
            else
                enc_s_last <= '0';
            end if;
            wait until rising_edge(clk) and enc_s_ready = '1';
        end loop;
        enc_s_valid <= '0';
        enc_s_last <= '0';

        while seen < INPUT_FRAME'length loop
            wait until rising_edge(clk);
            if dec_m_valid = '1' then
                assert dec_m_data = INPUT_FRAME(seen)
                    report "COBS round trip data mismatch" severity failure;
                if seen = INPUT_FRAME'length - 1 then
                    assert dec_m_last = '1' report "COBS missing final tlast" severity failure;
                    assert dec_m_user = '0' report "COBS unexpected error flag" severity failure;
                else
                    assert dec_m_last = '0' report "COBS early tlast" severity failure;
                end if;
                seen := seen + 1;
            end if;
        end loop;

        wait for 40 ns;
        report "simulation finished" severity note;
        finish;
    end process;
end architecture;
