-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_cobs_decoder is
    generic (
        MAX_FRAME_BYTES : positive := 2048
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_axis_tdata  : in  byte_t;
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

architecture rtl of axis_byte_cobs_decoder is
    constant IN_CAPACITY : positive := MAX_FRAME_BYTES + (MAX_FRAME_BYTES / 254) + 4;
    type input_mem_t is array (0 to IN_CAPACITY - 1) of byte_t;
    type output_mem_t is array (0 to MAX_FRAME_BYTES - 1) of byte_t;

    type state_t is (COLLECT, EMIT);
    signal state : state_t := COLLECT;
    signal input_mem : input_mem_t := (others => (others => '0'));
    signal output_mem : output_mem_t := (others => (others => '0'));
    signal input_len : natural range 0 to IN_CAPACITY := 0;
    signal output_len : natural range 0 to MAX_FRAME_BYTES := 0;
    signal output_pos : natural range 0 to MAX_FRAME_BYTES := 0;
    signal frame_user : std_logic := '0';
    signal overflow_error : std_logic := '0';
begin
    s_axis_tready <= '1' when state = COLLECT else '0';
    m_axis_tvalid <= '1' when state = EMIT else '0';
    m_axis_tdata <= output_mem(output_pos) when state = EMIT else (others => '0');
    m_axis_tlast <= '1' when state = EMIT and output_pos = output_len - 1 else '0';
    m_axis_tuser <= frame_user when state = EMIT and output_pos = output_len - 1 else '0';

    process (clk)
        variable wr_len : natural;
        variable rd_idx : natural;
        variable out_idx : natural;
        variable code_value : natural;
        variable limit_len : natural;
        variable stored_error : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= COLLECT;
                input_len <= 0;
                output_len <= 0;
                output_pos <= 0;
                frame_user <= '0';
                overflow_error <= '0';
            else
                case state is
                    when COLLECT =>
                        if s_axis_tvalid = '1' then
                            wr_len := input_len;
                            stored_error := overflow_error;

                            if input_len < IN_CAPACITY then
                                input_mem(input_len) <= s_axis_tdata;
                                wr_len := input_len + 1;
                            else
                                stored_error := '1';
                            end if;

                            if s_axis_tlast = '1' then
                                limit_len := wr_len;
                                if wr_len > 0 and s_axis_tdata = x"00" then
                                    limit_len := wr_len - 1;
                                end if;

                                rd_idx := 0;
                                out_idx := 0;

                                while rd_idx < limit_len loop
                                    if rd_idx = input_len and input_len < IN_CAPACITY then
                                        code_value := to_integer(unsigned(s_axis_tdata));
                                    else
                                        code_value := to_integer(unsigned(input_mem(rd_idx)));
                                    end if;
                                    rd_idx := rd_idx + 1;

                                    if code_value = 0 then
                                        stored_error := '1';
                                        rd_idx := limit_len;
                                    else
                                        for j in 1 to 254 loop
                                            if j < code_value then
                                                if rd_idx < limit_len and out_idx < MAX_FRAME_BYTES then
                                                    if rd_idx = input_len and input_len < IN_CAPACITY then
                                                        output_mem(out_idx) <= s_axis_tdata;
                                                    else
                                                        output_mem(out_idx) <= input_mem(rd_idx);
                                                    end if;
                                                    rd_idx := rd_idx + 1;
                                                    out_idx := out_idx + 1;
                                                else
                                                    stored_error := '1';
                                                    rd_idx := limit_len;
                                                end if;
                                            end if;
                                        end loop;

                                        if code_value < 255 and rd_idx < limit_len then
                                            if out_idx < MAX_FRAME_BYTES then
                                                output_mem(out_idx) <= x"00";
                                                out_idx := out_idx + 1;
                                            else
                                                stored_error := '1';
                                                rd_idx := limit_len;
                                            end if;
                                        end if;
                                    end if;
                                end loop;

                                if out_idx = 0 then
                                    output_mem(0) <= x"00";
                                    out_idx := 1;
                                end if;

                                frame_user <= stored_error or s_axis_tuser;
                                output_len <= out_idx;
                                output_pos <= 0;
                                input_len <= 0;
                                overflow_error <= '0';
                                state <= EMIT;
                            else
                                input_len <= wr_len;
                                overflow_error <= stored_error;
                            end if;
                        end if;

                    when EMIT =>
                        if m_axis_tready = '1' then
                            if output_pos = output_len - 1 then
                                output_pos <= 0;
                                output_len <= 0;
                                state <= COLLECT;
                            else
                                output_pos <= output_pos + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
