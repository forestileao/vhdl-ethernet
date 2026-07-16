-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity mac_control_rx is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_axis_tdata     : in  byte_t;
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in  std_logic;
        s_axis_tuser     : in  std_logic;
        pause_valid      : out std_logic;
        pause_ready      : in  std_logic;
        source_mac       : out mac_addr_t;
        pause_quanta     : out word16_t;
        error_bad_frame  : out std_logic
    );
end entity;

architecture rtl of mac_control_rx is
begin
    pause_rx: entity work.mac_pause_frame_rx
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            s_axis_tuser => s_axis_tuser,
            m_pause_valid => pause_valid,
            m_pause_ready => pause_ready,
            m_source_mac => source_mac,
            m_pause_quanta => pause_quanta,
            error_bad_frame => error_bad_frame
        );
end architecture;
