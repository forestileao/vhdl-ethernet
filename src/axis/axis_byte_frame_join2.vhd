-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_frame_join2 is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        s0_axis_tdata  : in  byte_t;
        s0_axis_tvalid : in  std_logic;
        s0_axis_tready : out std_logic;
        s0_axis_tlast  : in  std_logic;
        s0_axis_tuser  : in  std_logic;
        s1_axis_tdata  : in  byte_t;
        s1_axis_tvalid : in  std_logic;
        s1_axis_tready : out std_logic;
        s1_axis_tlast  : in  std_logic;
        s1_axis_tuser  : in  std_logic;
        m_axis_tdata   : out byte_t;
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic;
        m_axis_tlast   : out std_logic;
        m_axis_tuser   : out std_logic;
        busy           : out std_logic
    );
end entity;

architecture rtl of axis_byte_frame_join2 is
    type state_t is (S_PORT0, S_PORT1);
    signal state : state_t := S_PORT0;
    signal user_seen : std_logic := '0';
begin
    s0_axis_tready <= m_axis_tready when state = S_PORT0 else '0';
    s1_axis_tready <= m_axis_tready when state = S_PORT1 else '0';

    m_axis_tdata  <= s1_axis_tdata when state = S_PORT1 else s0_axis_tdata;
    m_axis_tvalid <= s1_axis_tvalid when state = S_PORT1 else s0_axis_tvalid;
    m_axis_tlast  <= s1_axis_tlast when state = S_PORT1 else '0';
    m_axis_tuser  <= (user_seen or s1_axis_tuser) when state = S_PORT1 else s0_axis_tuser;
    busy <= '1' when state = S_PORT1 else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_PORT0;
                user_seen <= '0';
            else
                case state is
                    when S_PORT0 =>
                        if s0_axis_tvalid = '1' and m_axis_tready = '1' then
                            user_seen <= user_seen or s0_axis_tuser;
                            if s0_axis_tlast = '1' then
                                state <= S_PORT1;
                            end if;
                        end if;

                    when S_PORT1 =>
                        if s1_axis_tvalid = '1' and m_axis_tready = '1' and s1_axis_tlast = '1' then
                            state <= S_PORT0;
                            user_seen <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
