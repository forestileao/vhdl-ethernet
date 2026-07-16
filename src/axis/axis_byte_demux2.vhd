-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_demux2 is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        select_port    : in  std_logic;
        s_axis_tdata   : in  byte_t;
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;
        s_axis_tlast   : in  std_logic;
        s_axis_tuser   : in  std_logic;
        m0_axis_tdata  : out byte_t;
        m0_axis_tvalid : out std_logic;
        m0_axis_tready : in  std_logic;
        m0_axis_tlast  : out std_logic;
        m0_axis_tuser  : out std_logic;
        m1_axis_tdata  : out byte_t;
        m1_axis_tvalid : out std_logic;
        m1_axis_tready : in  std_logic;
        m1_axis_tlast  : out std_logic;
        m1_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis_byte_demux2 is
    type state_t is (S_IDLE, S_PORT0, S_PORT1);
    signal state : state_t := S_IDLE;
    signal use_port1 : std_logic;
begin
    use_port1 <= '1' when state = S_PORT1 or (state = S_IDLE and select_port = '1') else '0';
    s_axis_tready <= m1_axis_tready when use_port1 = '1' else m0_axis_tready;

    m0_axis_tdata  <= s_axis_tdata;
    m0_axis_tvalid <= s_axis_tvalid when use_port1 = '0' else '0';
    m0_axis_tlast  <= s_axis_tlast;
    m0_axis_tuser  <= s_axis_tuser;

    m1_axis_tdata  <= s_axis_tdata;
    m1_axis_tvalid <= s_axis_tvalid when use_port1 = '1' else '0';
    m1_axis_tlast  <= s_axis_tlast;
    m1_axis_tuser  <= s_axis_tuser;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
            else
                case state is
                    when S_IDLE =>
                        if s_axis_tvalid = '1' then
                            if select_port = '1' then
                                state <= S_PORT1;
                            else
                                state <= S_PORT0;
                            end if;
                        end if;

                    when S_PORT0 =>
                        if s_axis_tvalid = '1' and m0_axis_tready = '1' and s_axis_tlast = '1' then
                            state <= S_IDLE;
                        end if;

                    when S_PORT1 =>
                        if s_axis_tvalid = '1' and m1_axis_tready = '1' and s_axis_tlast = '1' then
                            state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
