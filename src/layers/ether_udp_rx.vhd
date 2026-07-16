-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity udp_rx is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_axis_tdata         : in  byte_t;
        s_axis_tvalid        : in  std_logic;
        s_axis_tready        : out std_logic;
        s_axis_tlast         : in  std_logic;
        s_axis_tuser         : in  std_logic;
        m_hdr_valid          : out std_logic;
        m_hdr_ready          : in  std_logic;
        m_source_port        : out word16_t;
        m_target_port        : out word16_t;
        m_payload_length     : out word16_t;
        m_axis_payload_tdata : out byte_t;
        m_axis_payload_tvalid: out std_logic;
        m_axis_payload_tready: in  std_logic;
        m_axis_payload_tlast : out std_logic;
        m_axis_payload_tuser : out std_logic;
        error_bad_header     : out std_logic
    );
end entity;

architecture rtl of udp_rx is
    type state_t is (S_HEADER, S_PAYLOAD);
    type byte_array_t is array (0 to 7) of byte_t;
    signal state       : state_t := S_HEADER;
    signal ptr         : natural range 0 to 7 := 0;
    signal hdr         : byte_array_t := (others => (others => '0'));
    signal hdr_valid_i : std_logic := '0';
    signal src_reg     : word16_t := (others => '0');
    signal dst_reg     : word16_t := (others => '0');
    signal len_reg     : word16_t := (others => '0');
    signal bad_i       : std_logic := '0';
begin
    m_hdr_valid           <= hdr_valid_i;
    m_source_port         <= src_reg;
    m_target_port         <= dst_reg;
    m_payload_length      <= std_logic_vector(unsigned(len_reg) - 8);
    error_bad_header      <= bad_i;
    s_axis_tready         <= '1' when state = S_HEADER else
                             (m_axis_payload_tready and (m_hdr_ready or not hdr_valid_i));
    m_axis_payload_tvalid <= s_axis_tvalid when state = S_PAYLOAD and (m_hdr_ready = '1' or hdr_valid_i = '0') else '0';
    m_axis_payload_tdata  <= s_axis_tdata;
    m_axis_payload_tlast  <= s_axis_tlast when state = S_PAYLOAD else '0';
    m_axis_payload_tuser  <= s_axis_tuser when state = S_PAYLOAD else '0';

    process (clk)
        variable src : word16_t;
        variable dst : word16_t;
        variable len : word16_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= S_HEADER;
                ptr         <= 0;
                hdr         <= (others => (others => '0'));
                hdr_valid_i <= '0';
                src_reg     <= (others => '0');
                dst_reg     <= (others => '0');
                len_reg     <= (others => '0');
                bad_i       <= '0';
            else
                bad_i <= '0';
                if hdr_valid_i = '1' and m_hdr_ready = '1' then
                    hdr_valid_i <= '0';
                end if;

                if s_axis_tvalid = '1' and s_axis_tready = '1' then
                    case state is
                        when S_HEADER =>
                            hdr(ptr) <= s_axis_tdata;

                            if s_axis_tlast = '1' and ptr /= 7 then
                                bad_i <= '1';
                                ptr   <= 0;
                            elsif ptr = 7 then
                                src := hdr(0) & hdr(1);
                                dst := hdr(2) & hdr(3);
                                len := hdr(4) & hdr(5);

                                if unsigned(len) >= 8 and s_axis_tuser = '0' then
                                    src_reg     <= src;
                                    dst_reg     <= dst;
                                    len_reg     <= len;
                                    hdr_valid_i <= '1';
                                    state       <= S_PAYLOAD;
                                else
                                    bad_i <= '1';
                                    state <= S_HEADER;
                                end if;

                                ptr <= 0;
                                if s_axis_tlast = '1' then
                                    state <= S_HEADER;
                                end if;
                            else
                                ptr <= ptr + 1;
                            end if;

                        when S_PAYLOAD =>
                            if s_axis_tlast = '1' then
                                state <= S_HEADER;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;
