-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity eth_axis_tx is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_eth_dest_mac       : in  mac_addr_t;
        s_eth_src_mac        : in  mac_addr_t;
        s_eth_type           : in  word16_t;
        s_axis_payload_tdata : in  byte_t;
        s_axis_payload_tvalid: in  std_logic;
        s_axis_payload_tready: out std_logic;
        s_axis_payload_tlast : in  std_logic;
        s_axis_payload_tuser : in  std_logic;
        m_axis_tdata         : out byte_t;
        m_axis_tvalid        : out std_logic;
        m_axis_tready        : in  std_logic;
        m_axis_tlast         : out std_logic;
        m_axis_tuser         : out std_logic
    );
end entity;

architecture rtl of eth_axis_tx is
    type state_t is (S_IDLE, S_HEADER, S_PAYLOAD);
    signal state    : state_t := S_IDLE;
    signal ptr      : natural range 0 to 13 := 0;
    signal dst_reg  : mac_addr_t := (others => '0');
    signal src_reg  : mac_addr_t := (others => '0');
    signal type_reg : word16_t := (others => '0');

    function header_byte(index : natural; dst : mac_addr_t; src : mac_addr_t; typ : word16_t) return byte_t is
    begin
        case index is
            when 0 to 5   => return sel_byte(dst, index);
            when 6 to 11  => return sel_byte(src, index - 6);
            when 12       => return typ(15 downto 8);
            when others   => return typ(7 downto 0);
        end case;
    end function;
begin
    s_hdr_ready           <= '1' when state = S_IDLE else '0';
    s_axis_payload_tready <= m_axis_tready when state = S_PAYLOAD else '0';
    m_axis_tvalid         <= '1' when state = S_HEADER else s_axis_payload_tvalid when state = S_PAYLOAD else '0';
    m_axis_tdata          <= header_byte(ptr, dst_reg, src_reg, type_reg) when state = S_HEADER else s_axis_payload_tdata;
    m_axis_tlast          <= s_axis_payload_tlast when state = S_PAYLOAD else '0';
    m_axis_tuser          <= s_axis_payload_tuser when state = S_PAYLOAD else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= S_IDLE;
                ptr      <= 0;
                dst_reg  <= (others => '0');
                src_reg  <= (others => '0');
                type_reg <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_hdr_valid = '1' then
                            dst_reg  <= s_eth_dest_mac;
                            src_reg  <= s_eth_src_mac;
                            type_reg <= s_eth_type;
                            ptr      <= 0;
                            state    <= S_HEADER;
                        end if;

                    when S_HEADER =>
                        if m_axis_tready = '1' then
                            if ptr = 13 then
                                ptr   <= 0;
                                state <= S_PAYLOAD;
                            else
                                ptr <= ptr + 1;
                            end if;
                        end if;

                    when S_PAYLOAD =>
                        if s_axis_payload_tvalid = '1' and m_axis_tready = '1' and s_axis_payload_tlast = '1' then
                            state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
