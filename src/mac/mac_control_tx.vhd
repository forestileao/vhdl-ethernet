-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity mac_control_tx is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        pause_valid   : in  std_logic;
        pause_ready   : out std_logic;
        source_mac    : in  mac_addr_t;
        pause_quanta  : in  word16_t;
        m_axis_tdata  : out byte_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of mac_control_tx is
begin
    pause_tx: entity work.mac_pause_frame_tx
        port map (
            clk => clk,
            rst => rst,
            s_valid => pause_valid,
            s_ready => pause_ready,
            source_mac => source_mac,
            pause_quanta => pause_quanta,
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
            m_axis_tuser => m_axis_tuser
        );
end architecture;
