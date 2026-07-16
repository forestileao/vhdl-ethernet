-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis64_eth_fcs_append is
    generic (
        MAX_FRAME_BYTES : positive := 2048
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_axis_tdata  : in  word64_t;
        s_axis_tkeep  : in  keep8_t;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_axis_tdata  : out word64_t;
        m_axis_tkeep  : out keep8_t;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis64_eth_fcs_append is
    constant OUT_CAPACITY : positive := MAX_FRAME_BYTES + 4;
    type byte_mem_t is array (0 to OUT_CAPACITY - 1) of byte_t;
    type state_t is (COLLECT, EMIT);

    signal state : state_t := COLLECT;
    signal mem : byte_mem_t := (others => (others => '0'));
    signal in_len : natural range 0 to OUT_CAPACITY := 0;
    signal out_len : natural range 0 to OUT_CAPACITY := 0;
    signal out_pos : natural range 0 to OUT_CAPACITY := 0;
    signal frame_user : std_logic := '0';
    signal overflow_error : std_logic := '0';
    signal out_data : word64_t := (others => '0');
    signal out_keep : keep8_t := (others => '0');
begin
    s_axis_tready <= '1' when state = COLLECT else '0';
    m_axis_tvalid <= '1' when state = EMIT else '0';
    m_axis_tdata <= out_data;
    m_axis_tkeep <= out_keep;
    m_axis_tlast <= '1' when state = EMIT and out_pos + 8 >= out_len else '0';
    m_axis_tuser <= frame_user when state = EMIT and out_pos + 8 >= out_len else '0';

    process (all)
        variable data_v : word64_t;
        variable keep_v : keep8_t;
    begin
        data_v := (others => '0');
        keep_v := (others => '0');
        for lane in 0 to 7 loop
            if state = EMIT and out_pos + lane < out_len then
                data_v(lane * 8 + 7 downto lane * 8) := mem(out_pos + lane);
                keep_v(lane) := '1';
            end if;
        end loop;
        out_data <= data_v;
        out_keep <= keep_v;
    end process;

    process (clk)
        variable wr_len : natural;
        variable crc : std_logic_vector(31 downto 0);
        variable stored_error : std_logic;
        variable b : byte_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= COLLECT;
                in_len <= 0;
                out_len <= 0;
                out_pos <= 0;
                frame_user <= '0';
                overflow_error <= '0';
            else
                case state is
                    when COLLECT =>
                        if s_axis_tvalid = '1' then
                            wr_len := in_len;
                            stored_error := overflow_error;

                            for lane in 0 to 7 loop
                                if s_axis_tkeep(lane) = '1' then
                                    if wr_len < MAX_FRAME_BYTES then
                                        mem(wr_len) <= lane_byte(s_axis_tdata, lane);
                                        wr_len := wr_len + 1;
                                    else
                                        stored_error := '1';
                                    end if;
                                end if;
                            end loop;

                            if s_axis_tlast = '1' then
                                crc := (others => '1');
                                for i in 0 to MAX_FRAME_BYTES - 1 loop
                                    if i < wr_len then
                                        if i >= in_len then
                                            b := lane_byte(s_axis_tdata, i - in_len);
                                        else
                                            b := mem(i);
                                        end if;
                                        crc := crc32_next(crc, b);
                                    end if;
                                end loop;
                                crc := not crc;

                                if wr_len + 4 <= OUT_CAPACITY then
                                    mem(wr_len) <= crc(7 downto 0);
                                    mem(wr_len + 1) <= crc(15 downto 8);
                                    mem(wr_len + 2) <= crc(23 downto 16);
                                    mem(wr_len + 3) <= crc(31 downto 24);
                                else
                                    stored_error := '1';
                                end if;

                                out_len <= wr_len + 4;
                                out_pos <= 0;
                                frame_user <= stored_error or s_axis_tuser;
                                in_len <= 0;
                                overflow_error <= '0';
                                state <= EMIT;
                            else
                                in_len <= wr_len;
                                overflow_error <= stored_error;
                            end if;
                        end if;

                    when EMIT =>
                        if m_axis_tready = '1' then
                            if out_pos + 8 >= out_len then
                                out_pos <= 0;
                                out_len <= 0;
                                state <= COLLECT;
                            else
                                out_pos <= out_pos + 8;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
