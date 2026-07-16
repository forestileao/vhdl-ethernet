-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_async_fifo is
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

architecture rtl of axis_byte_async_fifo is
    constant DEPTH : natural := 2 ** ADDR_WIDTH;
    subtype ptr_t is unsigned(ADDR_WIDTH downto 0);
    type byte_mem_t is array (0 to DEPTH - 1) of byte_t;
    type bit_mem_t is array (0 to DEPTH - 1) of std_logic;

    signal data_mem : byte_mem_t := (others => (others => '0'));
    signal last_mem : bit_mem_t := (others => '0');
    signal user_mem : bit_mem_t := (others => '0');

    signal wr_bin : ptr_t := (others => '0');
    signal wr_gray : ptr_t := (others => '0');
    signal rd_bin : ptr_t := (others => '0');
    signal rd_gray : ptr_t := (others => '0');

    signal rd_gray_wr1 : ptr_t := (others => '0');
    signal rd_gray_wr2 : ptr_t := (others => '0');
    signal wr_gray_rd1 : ptr_t := (others => '0');
    signal wr_gray_rd2 : ptr_t := (others => '0');

    signal full_i : std_logic := '0';
    signal empty_i : std_logic := '1';
    signal out_data_reg : byte_t := (others => '0');
    signal out_last_reg : std_logic := '0';
    signal out_user_reg : std_logic := '0';

    function bin_to_gray(value : ptr_t) return ptr_t is
    begin
        return value xor ('0' & value(value'high downto 1));
    end function;
begin
    s_axis_tready <= not full_i;
    m_axis_tvalid <= not empty_i;
    m_axis_tdata <= out_data_reg;
    m_axis_tlast <= out_last_reg;
    m_axis_tuser <= out_user_reg;

    process (s_clk)
        variable wr_next : ptr_t;
        variable wr_gray_next : ptr_t;
        variable full_next : std_logic;
    begin
        if rising_edge(s_clk) then
            if s_rst = '1' then
                wr_bin <= (others => '0');
                wr_gray <= (others => '0');
                rd_gray_wr1 <= (others => '0');
                rd_gray_wr2 <= (others => '0');
                full_i <= '0';
            else
                rd_gray_wr1 <= rd_gray;
                rd_gray_wr2 <= rd_gray_wr1;

                wr_next := wr_bin;
                if s_axis_tvalid = '1' and full_i = '0' then
                    data_mem(to_integer(wr_bin(ADDR_WIDTH - 1 downto 0))) <= s_axis_tdata;
                    last_mem(to_integer(wr_bin(ADDR_WIDTH - 1 downto 0))) <= s_axis_tlast;
                    user_mem(to_integer(wr_bin(ADDR_WIDTH - 1 downto 0))) <= s_axis_tuser;
                    wr_next := wr_bin + 1;
                end if;

                wr_gray_next := bin_to_gray(wr_next);
                full_next := '0';
                if wr_gray_next(ADDR_WIDTH downto ADDR_WIDTH - 1) = not rd_gray_wr2(ADDR_WIDTH downto ADDR_WIDTH - 1) and
                   wr_gray_next(ADDR_WIDTH - 2 downto 0) = rd_gray_wr2(ADDR_WIDTH - 2 downto 0) then
                    full_next := '1';
                end if;

                wr_bin <= wr_next;
                wr_gray <= wr_gray_next;
                full_i <= full_next;
            end if;
        end if;
    end process;

    process (m_clk)
        variable rd_next : ptr_t;
    begin
        if rising_edge(m_clk) then
            if m_rst = '1' then
                rd_bin <= (others => '0');
                rd_gray <= (others => '0');
                wr_gray_rd1 <= (others => '0');
                wr_gray_rd2 <= (others => '0');
                empty_i <= '1';
                out_data_reg <= (others => '0');
                out_last_reg <= '0';
                out_user_reg <= '0';
            else
                wr_gray_rd1 <= wr_gray;
                wr_gray_rd2 <= wr_gray_rd1;

                rd_next := rd_bin;
                if empty_i = '0' and m_axis_tready = '1' then
                    rd_next := rd_bin + 1;
                end if;

                rd_bin <= rd_next;
                rd_gray <= bin_to_gray(rd_next);

                if bin_to_gray(rd_next) = wr_gray_rd2 then
                    empty_i <= '1';
                else
                    empty_i <= '0';
                    out_data_reg <= data_mem(to_integer(rd_next(ADDR_WIDTH - 1 downto 0)));
                    out_last_reg <= last_mem(to_integer(rd_next(ADDR_WIDTH - 1 downto 0)));
                    out_user_reg <= user_mem(to_integer(rd_next(ADDR_WIDTH - 1 downto 0)));
                end if;
            end if;
        end if;
    end process;
end architecture;
