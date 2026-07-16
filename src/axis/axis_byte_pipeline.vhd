-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_pipeline is
    generic (
        STAGES : positive := 2
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_axis_tdata  : in  byte_t;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_axis_tdata  : out byte_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis_byte_pipeline is
    type byte_array_t is array (natural range <>) of byte_t;
    signal data_bus  : byte_array_t(0 to STAGES);
    signal valid_bus : std_logic_vector(0 to STAGES);
    signal ready_bus : std_logic_vector(0 to STAGES);
    signal last_bus  : std_logic_vector(0 to STAGES);
    signal user_bus  : std_logic_vector(0 to STAGES);
begin
    data_bus(0)  <= s_axis_tdata;
    valid_bus(0) <= s_axis_tvalid;
    s_axis_tready <= ready_bus(0);
    last_bus(0)  <= s_axis_tlast;
    user_bus(0)  <= s_axis_tuser;

    m_axis_tdata     <= data_bus(STAGES);
    m_axis_tvalid    <= valid_bus(STAGES);
    ready_bus(STAGES) <= m_axis_tready;
    m_axis_tlast     <= last_bus(STAGES);
    m_axis_tuser     <= user_bus(STAGES);

    pipe_chain: for i in 0 to STAGES - 1 generate
        stage: entity work.axis_byte_register
            port map (
                clk => clk,
                rst => rst,
                s_axis_tdata => data_bus(i),
                s_axis_tvalid => valid_bus(i),
                s_axis_tready => ready_bus(i),
                s_axis_tlast => last_bus(i),
                s_axis_tuser => user_bus(i),
                m_axis_tdata => data_bus(i + 1),
                m_axis_tvalid => valid_bus(i + 1),
                m_axis_tready => ready_bus(i + 1),
                m_axis_tlast => last_bus(i + 1),
                m_axis_tuser => user_bus(i + 1)
            );
    end generate;
end architecture;
