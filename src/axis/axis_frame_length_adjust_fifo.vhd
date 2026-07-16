-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_frame_length_adjust_fifo is
    generic (
        FIFO_DEPTH : positive := 16
    );
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;
        min_length        : in  word16_t;
        max_length        : in  word16_t;
        s_axis_tdata      : in  byte_t;
        s_axis_tvalid     : in  std_logic;
        s_axis_tready     : out std_logic;
        s_axis_tlast      : in  std_logic;
        s_axis_tuser      : in  std_logic;
        m_axis_tdata      : out byte_t;
        m_axis_tvalid     : out std_logic;
        m_axis_tready     : in  std_logic;
        m_axis_tlast      : out std_logic;
        m_axis_tuser      : out std_logic;
        original_length   : out word16_t;
        adjusted_length   : out word16_t;
        status_valid      : out std_logic;
        status_padded     : out std_logic;
        status_truncated  : out std_logic
    );
end entity;

architecture rtl of axis_frame_length_adjust_fifo is
    signal adj_data : byte_t;
    signal adj_valid : std_logic;
    signal adj_ready : std_logic;
    signal adj_last : std_logic;
    signal adj_user : std_logic;
begin
    adjust: entity work.axis_frame_length_adjuster
        port map (
            clk => clk,
            rst => rst,
            min_length => min_length,
            max_length => max_length,
            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            s_axis_tuser => s_axis_tuser,
            m_axis_tdata => adj_data,
            m_axis_tvalid => adj_valid,
            m_axis_tready => adj_ready,
            m_axis_tlast => adj_last,
            m_axis_tuser => adj_user,
            original_length => original_length,
            adjusted_length => adjusted_length,
            status_valid => status_valid,
            status_padded => status_padded,
            status_truncated => status_truncated
        );

    fifo: entity work.axis_byte_fifo
        generic map (
            DEPTH => FIFO_DEPTH
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => adj_data,
            s_axis_tvalid => adj_valid,
            s_axis_tready => adj_ready,
            s_axis_tlast => adj_last,
            s_axis_tuser => adj_user,
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
            m_axis_tuser => m_axis_tuser
        );
end architecture;
