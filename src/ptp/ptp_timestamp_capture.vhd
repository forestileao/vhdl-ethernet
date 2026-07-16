-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity ptp_timestamp_capture is
    generic (
        TS_WIDTH : positive := 96
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        timestamp      : in  std_logic_vector(TS_WIDTH - 1 downto 0);
        s_axis_tdata   : in  word64_t;
        s_axis_tkeep   : in  keep8_t;
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;
        s_axis_tlast   : in  std_logic;
        s_axis_tuser   : in  std_logic;
        m_axis_tdata   : out word64_t;
        m_axis_tkeep   : out keep8_t;
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic;
        m_axis_tlast   : out std_logic;
        m_axis_tuser   : out std_logic;
        ts_valid       : out std_logic;
        ts_timestamp   : out std_logic_vector(TS_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of ptp_timestamp_capture is
    signal ts_valid_reg : std_logic := '0';
    signal ts_reg : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
begin
    s_axis_tready <= m_axis_tready;
    m_axis_tdata <= s_axis_tdata;
    m_axis_tkeep <= s_axis_tkeep;
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tlast <= s_axis_tlast;
    m_axis_tuser <= s_axis_tuser;
    ts_valid <= ts_valid_reg;
    ts_timestamp <= ts_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ts_valid_reg <= '0';
                ts_reg <= (others => '0');
            else
                ts_valid_reg <= '0';
                if s_axis_tvalid = '1' and m_axis_tready = '1' and s_axis_tlast = '1' then
                    ts_valid_reg <= '1';
                    ts_reg <= timestamp;
                end if;
            end if;
        end if;
    end process;
end architecture;
