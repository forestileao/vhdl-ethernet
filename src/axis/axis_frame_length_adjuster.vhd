-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_frame_length_adjuster is
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;
        min_length        : in  word16_t;
        max_length        : in  word16_t;
        s_axis_tdata      : in  byte_t;
        s_axis_tvalid     : in  std_logic;
        s_axis_tready     : out std_logic;
        s_axis_tlast      : in  std_logic;
        s_axis_tuser      : in  std_logic;
        m_axis_tdata      : out byte_t;
        m_axis_tvalid     : out std_logic;
        m_axis_tready     : in  std_logic;
        m_axis_tlast      : out std_logic;
        m_axis_tuser      : out std_logic;
        original_length   : out word16_t;
        adjusted_length   : out word16_t;
        status_valid      : out std_logic;
        status_padded     : out std_logic;
        status_truncated  : out std_logic
    );
end entity;

architecture rtl of axis_frame_length_adjuster is
    type state_t is (S_PASS, S_PAD, S_DROP);
    signal state : state_t := S_PASS;
    signal count_reg : unsigned(15 downto 0) := (others => '0');
    signal original_reg : word16_t := (others => '0');
    signal adjusted_reg : word16_t := (others => '0');
    signal status_valid_reg : std_logic := '0';
    signal padded_reg : std_logic := '0';
    signal truncated_reg : std_logic := '0';

    signal pass_count : unsigned(15 downto 0);
    signal max_count : unsigned(15 downto 0);
    signal min_count : unsigned(15 downto 0);
    signal hit_max : std_logic;
    signal need_pad : std_logic;
    signal pad_last : std_logic;

    function clean_unsigned(value : std_logic_vector) return unsigned is
        variable result : unsigned(value'range);
    begin
        for i in value'range loop
            if value(i) = '1' then
                result(i) := '1';
            else
                result(i) := '0';
            end if;
        end loop;
        return result;
    end function;

    function any_one(value : unsigned) return boolean is
    begin
        for i in value'range loop
            if value(i) = '1' then
                return true;
            end if;
        end loop;
        return false;
    end function;

    function ge_clean(left_value : unsigned; right_value : unsigned) return boolean is
    begin
        for i in left_value'range loop
            if left_value(i) = '1' and right_value(i) /= '1' then
                return true;
            elsif left_value(i) /= '1' and right_value(i) = '1' then
                return false;
            end if;
        end loop;
        return true;
    end function;
begin
    pass_count <= count_reg + 1;
    max_count <= clean_unsigned(max_length);
    min_count <= clean_unsigned(min_length);
    hit_max <= '1' when any_one(max_count) and ge_clean(pass_count, max_count) else '0';
    need_pad <= '1' when not ge_clean(pass_count, min_count) else '0';
    pad_last <= '1' when ge_clean(pass_count, min_count) else '0';

    s_axis_tready <= m_axis_tready when state = S_PASS else
                     '1' when state = S_DROP else
                     '0';
    m_axis_tvalid <= s_axis_tvalid when state = S_PASS else
                     '1' when state = S_PAD else
                     '0';
    m_axis_tdata <= s_axis_tdata when state = S_PASS else (others => '0');
    m_axis_tlast <= '1' when state = S_PAD and pad_last = '1' else
                    '1' when state = S_PASS and (s_axis_tlast = '1' and need_pad = '0') else
                    '1' when state = S_PASS and hit_max = '1' else
                    '0';
    m_axis_tuser <= '1' when state = S_PASS and hit_max = '1' and s_axis_tlast = '0' else
                    s_axis_tuser when state = S_PASS else
                    '0';

    original_length <= original_reg;
    adjusted_length <= adjusted_reg;
    status_valid <= status_valid_reg;
    status_padded <= padded_reg;
    status_truncated <= truncated_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_PASS;
                count_reg <= (others => '0');
                original_reg <= (others => '0');
                adjusted_reg <= (others => '0');
                status_valid_reg <= '0';
                padded_reg <= '0';
                truncated_reg <= '0';
            else
                status_valid_reg <= '0';

                case state is
                    when S_PASS =>
                        if s_axis_tvalid = '1' and m_axis_tready = '1' then
                            if hit_max = '1' and s_axis_tlast = '0' then
                                adjusted_reg <= std_logic_vector(pass_count);
                                count_reg <= pass_count;
                                state <= S_DROP;
                            elsif s_axis_tlast = '1' then
                                original_reg <= std_logic_vector(pass_count);
                                if need_pad = '1' then
                                    count_reg <= pass_count;
                                    state <= S_PAD;
                                else
                                    adjusted_reg <= std_logic_vector(pass_count);
                                    status_valid_reg <= '1';
                                    padded_reg <= '0';
                                    truncated_reg <= '0';
                                    count_reg <= (others => '0');
                                end if;
                            else
                                count_reg <= pass_count;
                            end if;
                        end if;

                    when S_PAD =>
                        if m_axis_tready = '1' then
                            if pad_last = '1' then
                                adjusted_reg <= std_logic_vector(pass_count);
                                status_valid_reg <= '1';
                                padded_reg <= '1';
                                truncated_reg <= '0';
                                count_reg <= (others => '0');
                                state <= S_PASS;
                            else
                                count_reg <= pass_count;
                            end if;
                        end if;

                    when S_DROP =>
                        if s_axis_tvalid = '1' then
                            if s_axis_tlast = '1' then
                                original_reg <= std_logic_vector(count_reg + 1);
                                status_valid_reg <= '1';
                                padded_reg <= '0';
                                truncated_reg <= '1';
                                count_reg <= (others => '0');
                                state <= S_PASS;
                            else
                                count_reg <= count_reg + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
