-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity udp_checksum_gen is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        s_hdr_valid          : in  std_logic;
        s_hdr_ready          : out std_logic;
        s_source_ip          : in  ipv4_addr_t;
        s_target_ip          : in  ipv4_addr_t;
        s_source_port        : in  word16_t;
        s_target_port        : in  word16_t;
        s_payload_length     : in  word16_t;
        s_axis_payload_tdata : in  byte_t;
        s_axis_payload_tvalid: in  std_logic;
        s_axis_payload_tready: out std_logic;
        s_axis_payload_tlast : in  std_logic;
        s_axis_payload_tuser : in  std_logic;
        m_axis_payload_tdata : out byte_t;
        m_axis_payload_tvalid: out std_logic;
        m_axis_payload_tready: in  std_logic;
        m_axis_payload_tlast : out std_logic;
        m_axis_payload_tuser : out std_logic;
        m_checksum           : out word16_t;
        m_checksum_valid     : out std_logic;
        m_checksum_ready     : in  std_logic
    );
end entity;

architecture rtl of udp_checksum_gen is
    type state_t is (S_IDLE, S_PAYLOAD, S_RESULT);
    signal state : state_t := S_IDLE;
    signal sum_reg : unsigned(31 downto 0) := (others => '0');
    signal odd_reg : std_logic := '0';
    signal high_reg : byte_t := (others => '0');
    signal checksum_reg : word16_t := (others => '0');

    function add_word(sum : unsigned(31 downto 0); word : word16_t) return unsigned is
    begin
        return sum + resize(unsigned(word), sum'length);
    end function;

    function fold_checksum(sum_in : unsigned(31 downto 0)) return word16_t is
        variable sum : unsigned(31 downto 0) := sum_in;
        variable folded : unsigned(15 downto 0);
    begin
        for i in 0 to 3 loop
            folded := sum(15 downto 0) + resize(sum(31 downto 16), folded'length);
            sum := resize(folded, sum'length);
        end loop;
        return std_logic_vector(not folded);
    end function;
begin
    s_hdr_ready <= '1' when state = S_IDLE else '0';
    s_axis_payload_tready <= m_axis_payload_tready when state = S_PAYLOAD else '0';
    m_axis_payload_tdata  <= s_axis_payload_tdata;
    m_axis_payload_tvalid <= s_axis_payload_tvalid when state = S_PAYLOAD else '0';
    m_axis_payload_tlast  <= s_axis_payload_tlast when state = S_PAYLOAD else '0';
    m_axis_payload_tuser  <= s_axis_payload_tuser when state = S_PAYLOAD else '0';
    m_checksum <= checksum_reg;
    m_checksum_valid <= '1' when state = S_RESULT else '0';

    process (clk)
        variable udp_len : word16_t;
        variable next_sum : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
                sum_reg <= (others => '0');
                odd_reg <= '0';
                high_reg <= (others => '0');
                checksum_reg <= (others => '0');
            else
                case state is
                    when S_IDLE =>
                        if s_hdr_valid = '1' then
                            udp_len := std_logic_vector(unsigned(s_payload_length) + 8);
                            next_sum := (others => '0');
                            next_sum := add_word(next_sum, s_source_ip(31 downto 16));
                            next_sum := add_word(next_sum, s_source_ip(15 downto 0));
                            next_sum := add_word(next_sum, s_target_ip(31 downto 16));
                            next_sum := add_word(next_sum, s_target_ip(15 downto 0));
                            next_sum := add_word(next_sum, x"0011");
                            next_sum := add_word(next_sum, udp_len);
                            next_sum := add_word(next_sum, s_source_port);
                            next_sum := add_word(next_sum, s_target_port);
                            next_sum := add_word(next_sum, udp_len);
                            sum_reg <= next_sum;
                            odd_reg <= '0';
                            high_reg <= (others => '0');
                            state <= S_PAYLOAD;
                        end if;

                    when S_PAYLOAD =>
                        if s_axis_payload_tvalid = '1' and m_axis_payload_tready = '1' then
                            next_sum := sum_reg;
                            if odd_reg = '0' then
                                if s_axis_payload_tlast = '1' then
                                    next_sum := add_word(next_sum, s_axis_payload_tdata & x"00");
                                    checksum_reg <= fold_checksum(next_sum);
                                    odd_reg <= '0';
                                    state <= S_RESULT;
                                else
                                    high_reg <= s_axis_payload_tdata;
                                    odd_reg <= '1';
                                end if;
                            else
                                next_sum := add_word(next_sum, high_reg & s_axis_payload_tdata);
                                if s_axis_payload_tlast = '1' then
                                    checksum_reg <= fold_checksum(next_sum);
                                    odd_reg <= '0';
                                    state <= S_RESULT;
                                else
                                    odd_reg <= '0';
                                end if;
                            end if;
                            sum_reg <= next_sum;
                        end if;

                    when S_RESULT =>
                        if m_checksum_ready = '1' then
                            state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
