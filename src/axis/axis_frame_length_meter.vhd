-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_frame_length_meter is
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;
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
        frame_length      : out word16_t;
        frame_length_valid: out std_logic
    );
end entity;

architecture rtl of axis_frame_length_meter is
    signal count_reg : unsigned(15 downto 0) := (others => '0');
    signal len_reg   : word16_t := (others => '0');
    signal len_valid : std_logic := '0';
begin
    s_axis_tready <= m_axis_tready;
    m_axis_tdata  <= s_axis_tdata;
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tlast  <= s_axis_tlast;
    m_axis_tuser  <= s_axis_tuser;
    frame_length <= len_reg;
    frame_length_valid <= len_valid;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count_reg <= (others => '0');
                len_reg   <= (others => '0');
                len_valid <= '0';
            else
                len_valid <= '0';
                if s_axis_tvalid = '1' and m_axis_tready = '1' then
                    if s_axis_tlast = '1' then
                        len_reg <= std_logic_vector(count_reg + 1);
                        len_valid <= '1';
                        count_reg <= (others => '0');
                    else
                        count_reg <= count_reg + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
