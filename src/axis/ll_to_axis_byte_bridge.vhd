-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity ll_to_axis_byte_bridge is
    port (
        ll_data_in       : in  byte_t;
        ll_sof_in_n      : in  std_logic;
        ll_eof_in_n      : in  std_logic;
        ll_src_rdy_in_n  : in  std_logic;
        ll_dst_rdy_out_n : out std_logic;
        m_axis_tdata     : out byte_t;
        m_axis_tvalid    : out std_logic;
        m_axis_tready    : in  std_logic;
        m_axis_tlast     : out std_logic
    );
end entity;

architecture rtl of ll_to_axis_byte_bridge is
begin
    m_axis_tdata <= ll_data_in;
    m_axis_tvalid <= not ll_src_rdy_in_n;
    m_axis_tlast <= not ll_eof_in_n;
    ll_dst_rdy_out_n <= not m_axis_tready;
end architecture;
