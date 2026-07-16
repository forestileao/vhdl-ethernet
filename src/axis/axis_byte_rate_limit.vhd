-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_rate_limit is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        enable        : in  std_logic;
        cycle_gap     : in  word16_t;
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

architecture rtl of axis_byte_rate_limit is
    signal data_reg  : byte_t := (others => '0');
    signal valid_reg : std_logic := '0';
    signal last_reg  : std_logic := '0';
    signal user_reg  : std_logic := '0';
    signal gap_count : unsigned(15 downto 0) := (others => '0');
    signal gated_ok  : std_logic;
begin
    gated_ok <= '1' when enable = '0' or gap_count = 0 else '0';
    s_axis_tready <= not valid_reg;
    m_axis_tdata  <= data_reg;
    m_axis_tvalid <= valid_reg and gated_ok;
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
                gap_count <= (others => '0');
            else
                if gap_count /= 0 then
                    gap_count <= gap_count - 1;
                end if;

                if s_axis_tvalid = '1' and s_axis_tready = '1' then
                    data_reg  <= s_axis_tdata;
                    valid_reg <= '1';
                    last_reg  <= s_axis_tlast;
                    user_reg  <= s_axis_tuser;
                elsif valid_reg = '1' and gated_ok = '1' and m_axis_tready = '1' then
                    valid_reg <= '0';
                    if enable = '1' then
                        gap_count <= unsigned(cycle_gap);
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
