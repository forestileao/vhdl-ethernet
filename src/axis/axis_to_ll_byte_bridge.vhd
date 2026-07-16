-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_to_ll_byte_bridge is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_axis_tdata     : in  byte_t;
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in  std_logic;
        ll_data_out      : out byte_t;
        ll_sof_out_n     : out std_logic;
        ll_eof_out_n     : out std_logic;
        ll_src_rdy_out_n : out std_logic;
        ll_dst_rdy_in_n  : in  std_logic
    );
end entity;

architecture rtl of axis_to_ll_byte_bridge is
    signal last_was_last : std_logic := '1';
    signal transfer_ok : std_logic;
    signal invalid_one_byte : std_logic;
begin
    transfer_ok <= s_axis_tvalid and not ll_dst_rdy_in_n;
    invalid_one_byte <= s_axis_tvalid and s_axis_tlast and last_was_last;

    s_axis_tready <= not ll_dst_rdy_in_n;
    ll_data_out <= s_axis_tdata;
    ll_sof_out_n <= not (last_was_last and s_axis_tvalid and not invalid_one_byte);
    ll_eof_out_n <= not (s_axis_tlast and not invalid_one_byte);
    ll_src_rdy_out_n <= not (s_axis_tvalid and not invalid_one_byte);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                last_was_last <= '1';
            elsif transfer_ok = '1' then
                last_was_last <= s_axis_tlast;
            end if;
        end if;
    end process;
end architecture;
