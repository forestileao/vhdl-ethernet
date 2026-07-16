-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_switch2 is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        select_input    : in  std_logic;
        select_output   : in  std_logic;
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

architecture rtl of axis_byte_switch2 is
    signal mid_data  : byte_t;
    signal mid_valid : std_logic;
    signal mid_ready : std_logic;
    signal mid_last  : std_logic;
    signal mid_user  : std_logic;
begin
    mux: entity work.axis_byte_mux2
        port map (
            clk => clk,
            rst => rst,
            select_port => select_input,
            s0_axis_tdata => s0_axis_tdata,
            s0_axis_tvalid => s0_axis_tvalid,
            s0_axis_tready => s0_axis_tready,
            s0_axis_tlast => s0_axis_tlast,
            s0_axis_tuser => s0_axis_tuser,
            s1_axis_tdata => s1_axis_tdata,
            s1_axis_tvalid => s1_axis_tvalid,
            s1_axis_tready => s1_axis_tready,
            s1_axis_tlast => s1_axis_tlast,
            s1_axis_tuser => s1_axis_tuser,
            m_axis_tdata => mid_data,
            m_axis_tvalid => mid_valid,
            m_axis_tready => mid_ready,
            m_axis_tlast => mid_last,
            m_axis_tuser => mid_user
        );

    demux: entity work.axis_byte_demux2
        port map (
            clk => clk,
            rst => rst,
            select_port => select_output,
            s_axis_tdata => mid_data,
            s_axis_tvalid => mid_valid,
            s_axis_tready => mid_ready,
            s_axis_tlast => mid_last,
            s_axis_tuser => mid_user,
            m0_axis_tdata => m0_axis_tdata,
            m0_axis_tvalid => m0_axis_tvalid,
            m0_axis_tready => m0_axis_tready,
            m0_axis_tlast => m0_axis_tlast,
            m0_axis_tuser => m0_axis_tuser,
            m1_axis_tdata => m1_axis_tdata,
            m1_axis_tvalid => m1_axis_tvalid,
            m1_axis_tready => m1_axis_tready,
            m1_axis_tlast => m1_axis_tlast,
            m1_axis_tuser => m1_axis_tuser
        );
end architecture;
