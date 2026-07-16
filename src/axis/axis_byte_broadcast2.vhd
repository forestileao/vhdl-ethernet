-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_broadcast2 is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        s_axis_tdata    : in  byte_t;
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        s_axis_tlast    : in  std_logic;
        s_axis_tuser    : in  std_logic;
        m0_axis_tdata   : out byte_t;
        m0_axis_tvalid  : out std_logic;
        m0_axis_tready  : in  std_logic;
        m0_axis_tlast   : out std_logic;
        m0_axis_tuser   : out std_logic;
        m1_axis_tdata   : out byte_t;
        m1_axis_tvalid  : out std_logic;
        m1_axis_tready  : in  std_logic;
        m1_axis_tlast   : out std_logic;
        m1_axis_tuser   : out std_logic
    );
end entity;

architecture rtl of axis_byte_broadcast2 is
    signal seen0 : std_logic := '0';
    signal seen1 : std_logic := '0';
begin
    s_axis_tready <= (m0_axis_tready or seen0) and (m1_axis_tready or seen1);

    m0_axis_tdata  <= s_axis_tdata;
    m0_axis_tvalid <= s_axis_tvalid and not seen0;
    m0_axis_tlast  <= s_axis_tlast;
    m0_axis_tuser  <= s_axis_tuser;

    m1_axis_tdata  <= s_axis_tdata;
    m1_axis_tvalid <= s_axis_tvalid and not seen1;
    m1_axis_tlast  <= s_axis_tlast;
    m1_axis_tuser  <= s_axis_tuser;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or s_axis_tvalid = '0' then
                seen0 <= '0';
                seen1 <= '0';
            else
                if m0_axis_tready = '1' and seen0 = '0' then
                    seen0 <= '1';
                end if;
                if m1_axis_tready = '1' and seen1 = '0' then
                    seen1 <= '1';
                end if;
                if s_axis_tready = '1' then
                    seen0 <= '0';
                    seen1 <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
