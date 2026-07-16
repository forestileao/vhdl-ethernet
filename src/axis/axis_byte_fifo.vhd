-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_fifo is
    generic (
        DEPTH : positive := 16
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

architecture rtl of axis_byte_fifo is
    type byte_mem_t is array (0 to DEPTH - 1) of byte_t;
    type bit_mem_t is array (0 to DEPTH - 1) of std_logic;
    signal data_mem  : byte_mem_t := (others => (others => '0'));
    signal last_mem  : bit_mem_t := (others => '0');
    signal user_mem  : bit_mem_t := (others => '0');
    signal wr_ptr    : natural range 0 to DEPTH - 1 := 0;
    signal rd_ptr    : natural range 0 to DEPTH - 1 := 0;
    signal count     : natural range 0 to DEPTH := 0;
begin
    s_axis_tready <= '1' when count < DEPTH else '0';
    m_axis_tvalid <= '1' when count > 0 else '0';
    m_axis_tdata  <= data_mem(rd_ptr);
    m_axis_tlast  <= last_mem(rd_ptr);
    m_axis_tuser  <= user_mem(rd_ptr);

    process (clk)
        variable push : boolean;
        variable pop  : boolean;
        variable next_count : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;
            else
                push := s_axis_tvalid = '1' and s_axis_tready = '1';
                pop  := m_axis_tready = '1' and count > 0;

                if push then
                    data_mem(wr_ptr) <= s_axis_tdata;
                    last_mem(wr_ptr) <= s_axis_tlast;
                    user_mem(wr_ptr) <= s_axis_tuser;
                    if wr_ptr = DEPTH - 1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                if pop then
                    if rd_ptr = DEPTH - 1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                next_count := count;
                if push then
                    next_count := next_count + 1;
                end if;
                if pop then
                    next_count := next_count - 1;
                end if;
                count <= next_count;
            end if;
        end if;
    end process;
end architecture;
