-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_register is
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

architecture rtl of axis_byte_register is
    signal data_reg  : byte_t := (others => '0');
    signal valid_reg : std_logic := '0';
    signal last_reg  : std_logic := '0';
    signal user_reg  : std_logic := '0';
begin
    s_axis_tready <= not valid_reg or m_axis_tready;
    m_axis_tdata  <= data_reg;
    m_axis_tvalid <= valid_reg;
    m_axis_tlast  <= last_reg;
    m_axis_tuser  <= user_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                data_reg  <= (others => '0');
                valid_reg <= '0';
                last_reg  <= '0';
                user_reg  <= '0';
            elsif s_axis_tready = '1' then
                data_reg  <= s_axis_tdata;
                valid_reg <= s_axis_tvalid;
                last_reg  <= s_axis_tlast;
                user_reg  <= s_axis_tuser;
            end if;
        end if;
    end process;
end architecture;
