-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis64_to_byte_stream is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_axis_tdata  : in  word64_t;
        s_axis_tkeep  : in  keep8_t;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_axis_tdata  : out byte_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis64_to_byte_stream is
    type state_t is (EMPTY, SEND);
    signal state : state_t := EMPTY;
    signal data_reg : word64_t := (others => '0');
    signal keep_reg : keep8_t := (others => '0');
    signal last_reg : std_logic := '0';
    signal user_reg : std_logic := '0';
    signal idx : natural range 0 to 7 := 0;

    function any_keep(k : keep8_t) return boolean is
    begin
        for i in 0 to 7 loop
            if k(i) = '1' then
                return true;
            end if;
        end loop;
        return false;
    end function;

    function first_lane(k : keep8_t) return natural is
    begin
        for i in 0 to 7 loop
            if k(i) = '1' then
                return i;
            end if;
        end loop;
        return 0;
    end function;

    function has_later(k : keep8_t; current : natural) return boolean is
    begin
        for i in 0 to 7 loop
            if i > current and k(i) = '1' then
                return true;
            end if;
        end loop;
        return false;
    end function;

    function next_lane(k : keep8_t; current : natural) return natural is
    begin
        for i in 0 to 7 loop
            if i > current and k(i) = '1' then
                return i;
            end if;
        end loop;
        return current;
    end function;
begin
    s_axis_tready <= '1' when state = EMPTY else '0';
    m_axis_tvalid <= '1' when state = SEND else '0';
    m_axis_tdata <= lane_byte(data_reg, idx);
    m_axis_tlast <= last_reg when state = SEND and not has_later(keep_reg, idx) else '0';
    m_axis_tuser <= user_reg when state = SEND and last_reg = '1' and not has_later(keep_reg, idx) else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= EMPTY;
                data_reg <= (others => '0');
                keep_reg <= (others => '0');
                last_reg <= '0';
                user_reg <= '0';
                idx <= 0;
            else
                case state is
                    when EMPTY =>
                        if s_axis_tvalid = '1' then
                            data_reg <= s_axis_tdata;
                            keep_reg <= s_axis_tkeep;
                            last_reg <= s_axis_tlast;
                            user_reg <= s_axis_tuser;
                            idx <= first_lane(s_axis_tkeep);
                            if any_keep(s_axis_tkeep) then
                                state <= SEND;
                            end if;
                        end if;

                    when SEND =>
                        if m_axis_tready = '1' then
                            if has_later(keep_reg, idx) then
                                idx <= next_lane(keep_reg, idx);
                            else
                                state <= EMPTY;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
