-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity mac_pause_frame_tx is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_valid       : in  std_logic;
        s_ready       : out std_logic;
        source_mac    : in  mac_addr_t;
        pause_quanta  : in  word16_t;
        m_axis_tdata  : out byte_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of mac_pause_frame_tx is
    type state_t is (S_IDLE, S_FRAME);
    signal state : state_t := S_IDLE;
    signal ptr : natural range 0 to 17 := 0;
    signal src_reg : mac_addr_t := (others => '0');
    signal quanta_reg : word16_t := (others => '0');

    function pause_byte(index : natural; src : mac_addr_t; quanta : word16_t) return byte_t is
    begin
        case index is
            when 0  => return x"01";
            when 1  => return x"80";
            when 2  => return x"C2";
            when 3  => return x"00";
            when 4  => return x"00";
            when 5  => return x"01";
            when 6 to 11 => return sel_byte(src, index - 6);
            when 12 => return x"88";
            when 13 => return x"08";
            when 14 => return x"00";
            when 15 => return x"01";
            when 16 => return quanta(15 downto 8);
            when others => return quanta(7 downto 0);
        end case;
    end function;
begin
    s_ready <= '1' when state = S_IDLE else '0';
    m_axis_tvalid <= '1' when state = S_FRAME else '0';
    m_axis_tdata <= pause_byte(ptr, src_reg, quanta_reg);
    m_axis_tlast <= '1' when state = S_FRAME and ptr = 17 else '0';
    m_axis_tuser <= '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
                ptr <= 0;
                src_reg <= (others => '0');
                quanta_reg <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_valid = '1' then
                            src_reg <= source_mac;
                            quanta_reg <= pause_quanta;
                            ptr <= 0;
                            state <= S_FRAME;
                        end if;

                    when S_FRAME =>
                        if m_axis_tready = '1' then
                            if ptr = 17 then
                                ptr <= 0;
                                state <= S_IDLE;
                            else
                                ptr <= ptr + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
