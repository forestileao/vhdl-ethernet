-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_crosspoint2 is
    port (
        m0_select       : in  std_logic;
        m1_select       : in  std_logic;
        s0_axis_tdata   : in  byte_t;
        s0_axis_tvalid  : in  std_logic;
        s0_axis_tready  : out std_logic;
        s0_axis_tlast   : in  std_logic;
        s0_axis_tuser   : in  std_logic;
        s1_axis_tdata   : in  byte_t;
        s1_axis_tvalid  : in  std_logic;
        s1_axis_tready  : out std_logic;
        s1_axis_tlast   : in  std_logic;
        s1_axis_tuser   : in  std_logic;
        m0_axis_tdata   : out byte_t;
        m0_axis_tvalid  : out std_logic;
        m0_axis_tready  : in  std_logic;
        m0_axis_tlast   : out std_logic;
        m0_axis_tuser   : out std_logic;
        m1_axis_tdata   : out byte_t;
        m1_axis_tvalid  : out std_logic;
        m1_axis_tready  : in  std_logic;
        m1_axis_tlast   : out std_logic;
        m1_axis_tuser   : out std_logic
    );
end entity;

architecture rtl of axis_byte_crosspoint2 is
    signal s0_ready_m0 : std_logic;
    signal s0_ready_m1 : std_logic;
    signal s1_ready_m0 : std_logic;
    signal s1_ready_m1 : std_logic;
begin
    m0_axis_tdata  <= s1_axis_tdata when m0_select = '1' else s0_axis_tdata;
    m0_axis_tvalid <= s1_axis_tvalid when m0_select = '1' else s0_axis_tvalid;
    m0_axis_tlast  <= s1_axis_tlast when m0_select = '1' else s0_axis_tlast;
    m0_axis_tuser  <= s1_axis_tuser when m0_select = '1' else s0_axis_tuser;

    m1_axis_tdata  <= s1_axis_tdata when m1_select = '1' else s0_axis_tdata;
    m1_axis_tvalid <= s1_axis_tvalid when m1_select = '1' else s0_axis_tvalid;
    m1_axis_tlast  <= s1_axis_tlast when m1_select = '1' else s0_axis_tlast;
    m1_axis_tuser  <= s1_axis_tuser when m1_select = '1' else s0_axis_tuser;

    s0_ready_m0 <= m0_axis_tready when m0_select = '0' else '0';
    s0_ready_m1 <= m1_axis_tready when m1_select = '0' else '0';
    s1_ready_m0 <= m0_axis_tready when m0_select = '1' else '0';
    s1_ready_m1 <= m1_axis_tready when m1_select = '1' else '0';
    s0_axis_tready <= s0_ready_m0 or s0_ready_m1;
    s1_axis_tready <= s1_ready_m0 or s1_ready_m1;
end architecture;
