-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity udp_tx is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_source_port        : in  word16_t;
        s_target_port        : in  word16_t;
        s_payload_length     : in  word16_t;
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

architecture rtl of udp_tx is
    type state_t is (S_IDLE, S_HEADER, S_PAYLOAD);
    signal state   : state_t := S_IDLE;
    signal ptr     : natural range 0 to 7 := 0;
    signal src_reg : word16_t := (others => '0');
    signal dst_reg : word16_t := (others => '0');
    signal len_reg : word16_t := (others => '0');

    function udp_byte(index : natural; src : word16_t; dst : word16_t; len : word16_t) return byte_t is
    begin
        case index is
            when 0 => return src(15 downto 8);
            when 1 => return src(7 downto 0);
            when 2 => return dst(15 downto 8);
            when 3 => return dst(7 downto 0);
            when 4 => return len(15 downto 8);
            when 5 => return len(7 downto 0);
            when 6 => return x"00";
            when others => return x"00";
        end case;
    end function;
begin
    s_hdr_ready           <= '1' when state = S_IDLE else '0';
    s_axis_payload_tready <= m_axis_tready when state = S_PAYLOAD else '0';
    m_axis_tvalid         <= '1' when state = S_HEADER else s_axis_payload_tvalid when state = S_PAYLOAD else '0';
    m_axis_tdata          <= udp_byte(ptr, src_reg, dst_reg, len_reg) when state = S_HEADER else s_axis_payload_tdata;
    m_axis_tlast          <= s_axis_payload_tlast when state = S_PAYLOAD else '0';
    m_axis_tuser          <= s_axis_payload_tuser when state = S_PAYLOAD else '0';

    process (clk)
        variable total_len : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= S_IDLE;
                ptr     <= 0;
                src_reg <= (others => '0');
                dst_reg <= (others => '0');
                len_reg <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_hdr_valid = '1' then
                            total_len := unsigned(s_payload_length) + 8;
                            src_reg <= s_source_port;
                            dst_reg <= s_target_port;
                            len_reg <= std_logic_vector(total_len);
                            ptr     <= 0;
                            state   <= S_HEADER;
                        end if;

                    when S_HEADER =>
                        if m_axis_tready = '1' then
                            if ptr = 7 then
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
