-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_async_fifo_adapter is
    generic (
        ADDR_WIDTH : positive := 4
    );
    port (
        s_clk         : in  std_logic;
        s_rst         : in  std_logic;
        s_axis_tdata  : in  byte_t;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_clk         : in  std_logic;
        m_rst         : in  std_logic;
        m_axis_tdata  : out byte_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis_byte_async_fifo_adapter is
    signal a_data : byte_t;
    signal a_valid : std_logic;
    signal a_ready : std_logic;
    signal a_last : std_logic;
    signal a_user : std_logic;
begin
    adapter: entity work.axis_byte_adapter
        port map (
            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            s_axis_tuser => s_axis_tuser,
            m_axis_tdata => a_data,
            m_axis_tvalid => a_valid,
            m_axis_tready => a_ready,
            m_axis_tlast => a_last,
            m_axis_tuser => a_user
        );

    fifo: entity work.axis_byte_async_fifo
        generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            s_clk => s_clk,
            s_rst => s_rst,
            s_axis_tdata => a_data,
            s_axis_tvalid => a_valid,
            s_axis_tready => a_ready,
            s_axis_tlast => a_last,
            s_axis_tuser => a_user,
            m_clk => m_clk,
            m_rst => m_rst,
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
            m_axis_tuser => m_axis_tuser
        );
end architecture;
