-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_stat_counter is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        clear           : in  std_logic;
        s_axis_tdata    : in  byte_t;
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        s_axis_tlast    : in  std_logic;
        s_axis_tuser    : in  std_logic;
        m_axis_tdata    : out byte_t;
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tuser    : out std_logic;
        byte_count      : out std_logic_vector(31 downto 0);
        frame_count     : out std_logic_vector(31 downto 0);
        bad_frame_count : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of axis_byte_stat_counter is
    signal bytes_reg : unsigned(31 downto 0) := (others => '0');
    signal frames_reg : unsigned(31 downto 0) := (others => '0');
    signal bad_reg : unsigned(31 downto 0) := (others => '0');
begin
    s_axis_tready <= m_axis_tready;
    m_axis_tdata  <= s_axis_tdata;
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tlast  <= s_axis_tlast;
    m_axis_tuser  <= s_axis_tuser;

    byte_count <= std_logic_vector(bytes_reg);
    frame_count <= std_logic_vector(frames_reg);
    bad_frame_count <= std_logic_vector(bad_reg);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or clear = '1' then
                bytes_reg <= (others => '0');
                frames_reg <= (others => '0');
                bad_reg <= (others => '0');
            elsif s_axis_tvalid = '1' and m_axis_tready = '1' then
                bytes_reg <= bytes_reg + 1;
                if s_axis_tlast = '1' then
                    frames_reg <= frames_reg + 1;
                    if s_axis_tuser = '1' then
                        bad_reg <= bad_reg + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
