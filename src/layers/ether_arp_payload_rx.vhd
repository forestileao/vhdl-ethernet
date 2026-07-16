-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity arp_eth_rx is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_axis_tdata     : in  byte_t;
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in  std_logic;
        s_axis_tuser     : in  std_logic;
        m_packet_valid   : out std_logic;
        m_packet_ready   : in  std_logic;
        m_oper           : out word16_t;
        m_sender_mac     : out mac_addr_t;
        m_sender_ip      : out ipv4_addr_t;
        m_target_mac     : out mac_addr_t;
        m_target_ip      : out ipv4_addr_t;
        error_bad_packet : out std_logic
    );
end entity;

architecture rtl of arp_eth_rx is
    signal ptr       : natural range 0 to 27 := 0;
    signal valid_i   : std_logic := '0';
    signal oper_reg  : word16_t := (others => '0');
    signal sha_reg   : mac_addr_t := (others => '0');
    signal spa_reg   : ipv4_addr_t := (others => '0');
    signal tha_reg   : mac_addr_t := (others => '0');
    signal tpa_reg   : ipv4_addr_t := (others => '0');
    signal bad_i     : std_logic := '0';
    signal fixed_ok  : std_logic := '1';
begin
    s_axis_tready    <= not valid_i or m_packet_ready;
    m_packet_valid   <= valid_i;
    m_oper           <= oper_reg;
    m_sender_mac     <= sha_reg;
    m_sender_ip      <= spa_reg;
    m_target_mac     <= tha_reg;
    m_target_ip      <= tpa_reg;
    error_bad_packet <= bad_i;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ptr      <= 0;
                valid_i  <= '0';
                oper_reg <= (others => '0');
                sha_reg  <= (others => '0');
                spa_reg  <= (others => '0');
                tha_reg  <= (others => '0');
                tpa_reg  <= (others => '0');
                bad_i    <= '0';
                fixed_ok <= '1';
            else
                bad_i <= '0';
                if valid_i = '1' and m_packet_ready = '1' then
                    valid_i <= '0';
                end if;

                if s_axis_tvalid = '1' and s_axis_tready = '1' then
                    case ptr is
                        when 0  => if s_axis_tdata /= x"00" then fixed_ok <= '0'; end if;
                        when 1  => if s_axis_tdata /= x"01" then fixed_ok <= '0'; end if;
                        when 2  => if s_axis_tdata /= x"08" then fixed_ok <= '0'; end if;
                        when 3  => if s_axis_tdata /= x"00" then fixed_ok <= '0'; end if;
                        when 4  => if s_axis_tdata /= x"06" then fixed_ok <= '0'; end if;
                        when 5  => if s_axis_tdata /= x"04" then fixed_ok <= '0'; end if;
                        when 6  => oper_reg(15 downto 8) <= s_axis_tdata;
                        when 7  => oper_reg(7 downto 0) <= s_axis_tdata;
                        when 8 to 13  => sha_reg(47 - (ptr - 8) * 8 downto 40 - (ptr - 8) * 8) <= s_axis_tdata;
                        when 14 to 17 => spa_reg(31 - (ptr - 14) * 8 downto 24 - (ptr - 14) * 8) <= s_axis_tdata;
                        when 18 to 23 => tha_reg(47 - (ptr - 18) * 8 downto 40 - (ptr - 18) * 8) <= s_axis_tdata;
                        when others   => tpa_reg(31 - (ptr - 24) * 8 downto 24 - (ptr - 24) * 8) <= s_axis_tdata;
                    end case;

                    if s_axis_tlast = '1' then
                        if ptr = 27 and fixed_ok = '1' and s_axis_tuser = '0' then
                            valid_i <= '1';
                        else
                            bad_i <= '1';
                        end if;
                        ptr      <= 0;
                        fixed_ok <= '1';
                    elsif ptr = 27 then
                        bad_i    <= '1';
                        ptr      <= 0;
                        fixed_ok <= '1';
                    else
                        ptr <= ptr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
