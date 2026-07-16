-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity ipv4_tx is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_payload_length     : in  word16_t;
        s_identification     : in  word16_t;
        s_flags_fragment     : in  word16_t;
        s_ttl                : in  byte_t;
        s_protocol           : in  byte_t;
        s_source_ip          : in  ipv4_addr_t;
        s_target_ip          : in  ipv4_addr_t;
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

architecture rtl of ipv4_tx is
    type state_t is (S_IDLE, S_HEADER, S_PAYLOAD);
    signal state      : state_t := S_IDLE;
    signal ptr        : natural range 0 to 19 := 0;
    signal len_reg    : word16_t := (others => '0');
    signal id_reg     : word16_t := (others => '0');
    signal frag_reg   : word16_t := (others => '0');
    signal ttl_reg    : byte_t := (others => '0');
    signal proto_reg  : byte_t := (others => '0');
    signal src_reg    : ipv4_addr_t := (others => '0');
    signal dst_reg    : ipv4_addr_t := (others => '0');
    signal csum_reg   : word16_t := (others => '0');

    function ip_byte(
        index : natural;
        len   : word16_t;
        ident : word16_t;
        frag  : word16_t;
        ttl   : byte_t;
        proto : byte_t;
        csum  : word16_t;
        src   : ipv4_addr_t;
        dst   : ipv4_addr_t
    ) return byte_t is
    begin
        case index is
            when 0  => return x"45";
            when 1  => return x"00";
            when 2  => return len(15 downto 8);
            when 3  => return len(7 downto 0);
            when 4  => return ident(15 downto 8);
            when 5  => return ident(7 downto 0);
            when 6  => return frag(15 downto 8);
            when 7  => return frag(7 downto 0);
            when 8  => return ttl;
            when 9  => return proto;
            when 10 => return csum(15 downto 8);
            when 11 => return csum(7 downto 0);
            when 12 to 15 => return sel_byte(src, index - 12);
            when others   => return sel_byte(dst, index - 16);
        end case;
    end function;
begin
    s_hdr_ready           <= '1' when state = S_IDLE else '0';
    s_axis_payload_tready <= m_axis_tready when state = S_PAYLOAD else '0';
    m_axis_tvalid         <= '1' when state = S_HEADER else s_axis_payload_tvalid when state = S_PAYLOAD else '0';
    m_axis_tdata          <= ip_byte(ptr, len_reg, id_reg, frag_reg, ttl_reg, proto_reg, csum_reg, src_reg, dst_reg) when state = S_HEADER else s_axis_payload_tdata;
    m_axis_tlast          <= s_axis_payload_tlast when state = S_PAYLOAD else '0';
    m_axis_tuser          <= s_axis_payload_tuser when state = S_PAYLOAD else '0';

    process (clk)
        variable total_len : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= S_IDLE;
                ptr       <= 0;
                len_reg   <= (others => '0');
                id_reg    <= (others => '0');
                frag_reg  <= (others => '0');
                ttl_reg   <= (others => '0');
                proto_reg <= (others => '0');
                src_reg   <= (others => '0');
                dst_reg   <= (others => '0');
                csum_reg  <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_hdr_valid = '1' then
                            total_len := unsigned(s_payload_length) + 20;
                            len_reg   <= std_logic_vector(total_len);
                            id_reg    <= s_identification;
                            frag_reg  <= s_flags_fragment;
                            ttl_reg   <= s_ttl;
                            proto_reg <= s_protocol;
                            src_reg   <= s_source_ip;
                            dst_reg   <= s_target_ip;
                            csum_reg  <= ipv4_header_checksum(std_logic_vector(total_len), s_identification, s_flags_fragment, s_ttl, s_protocol, s_source_ip, s_target_ip);
                            ptr       <= 0;
                            state     <= S_HEADER;
                        end if;

                    when S_HEADER =>
                        if m_axis_tready = '1' then
                            if ptr = 19 then
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
