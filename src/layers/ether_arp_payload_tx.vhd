-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity arp_eth_tx is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_request_valid  : in  std_logic;
        s_request_ready  : out std_logic;
        s_oper           : in  word16_t;
        s_sender_mac     : in  mac_addr_t;
        s_sender_ip      : in  ipv4_addr_t;
        s_target_mac     : in  mac_addr_t;
        s_target_ip      : in  ipv4_addr_t;
        m_axis_tdata     : out byte_t;
        m_axis_tvalid    : out std_logic;
        m_axis_tready    : in  std_logic;
        m_axis_tlast     : out std_logic;
        m_axis_tuser     : out std_logic
    );
end entity;

architecture rtl of arp_eth_tx is
    type state_t is (S_IDLE, S_SEND);
    signal state      : state_t := S_IDLE;
    signal ptr        : natural range 0 to 27 := 0;
    signal oper_reg   : word16_t := (others => '0');
    signal sha_reg    : mac_addr_t := (others => '0');
    signal spa_reg    : ipv4_addr_t := (others => '0');
    signal tha_reg    : mac_addr_t := (others => '0');
    signal tpa_reg    : ipv4_addr_t := (others => '0');

    function arp_byte(
        index : natural;
        oper  : word16_t;
        sha   : mac_addr_t;
        spa   : ipv4_addr_t;
        tha   : mac_addr_t;
        tpa   : ipv4_addr_t
    ) return byte_t is
    begin
        case index is
            when 0  => return x"00";
            when 1  => return x"01";
            when 2  => return x"08";
            when 3  => return x"00";
            when 4  => return x"06";
            when 5  => return x"04";
            when 6  => return oper(15 downto 8);
            when 7  => return oper(7 downto 0);
            when 8 to 13  => return sel_byte(sha, index - 8);
            when 14 to 17 => return sel_byte(spa, index - 14);
            when 18 to 23 => return sel_byte(tha, index - 18);
            when others   => return sel_byte(tpa, index - 24);
        end case;
    end function;
begin
    s_request_ready <= '1' when state = S_IDLE else '0';
    m_axis_tvalid   <= '1' when state = S_SEND else '0';
    m_axis_tdata    <= arp_byte(ptr, oper_reg, sha_reg, spa_reg, tha_reg, tpa_reg);
    m_axis_tlast    <= '1' when state = S_SEND and ptr = 27 else '0';
    m_axis_tuser    <= '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= S_IDLE;
                ptr      <= 0;
                oper_reg <= (others => '0');
                sha_reg  <= (others => '0');
                spa_reg  <= (others => '0');
                tha_reg  <= (others => '0');
                tpa_reg  <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_request_valid = '1' then
                            oper_reg <= s_oper;
                            sha_reg  <= s_sender_mac;
                            spa_reg  <= s_sender_ip;
                            tha_reg  <= s_target_mac;
                            tpa_reg  <= s_target_ip;
                            ptr      <= 0;
                            state    <= S_SEND;
                        end if;

                    when S_SEND =>
                        if m_axis_tready = '1' then
                            if ptr = 27 then
                                ptr   <= 0;
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
