-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_xgmii_tx32 is
    generic (
        MAX_FRAME_BYTES : positive := 2048;
        IFG_WORDS       : natural := 3
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
        xgmii_txd     : out word32_t;
        xgmii_txc     : out keep4_t;
        busy          : out std_logic
    );
end entity;

architecture rtl of axis_xgmii_tx32 is
    constant OUT_BYTES : positive := MAX_FRAME_BYTES + 13;
    constant IDLE_WORD : word32_t := x"07070707";
    constant IDLE_CTRL : keep4_t := (others => '1');
    type byte_mem_t is array (0 to MAX_FRAME_BYTES + 3) of byte_t;
    type state_t is (COLLECT, EMIT, IFG);

    signal state : state_t := COLLECT;
    signal mem : byte_mem_t := (others => (others => '0'));
    signal frame_len : natural range 0 to MAX_FRAME_BYTES + 4 := 0;
    signal out_pos : natural range 0 to OUT_BYTES := 0;
    signal ifg_count : natural range 0 to IFG_WORDS := 0;
    signal txd_reg : word32_t := IDLE_WORD;
    signal txc_reg : keep4_t := IDLE_CTRL;

    function tx_byte(index : natural; payload_len : natural; bytes : byte_mem_t) return byte_t is
    begin
        if index = 0 then
            return x"FB";
        elsif index >= 1 and index <= 6 then
            return x"55";
        elsif index = 7 then
            return x"D5";
        elsif index < payload_len + 8 then
            return bytes(index - 8);
        elsif index = payload_len + 8 then
            return x"FD";
        else
            return x"07";
        end if;
    end function;

    function tx_ctrl(index : natural; payload_len : natural) return std_logic is
    begin
        if index = 0 or index >= payload_len + 8 then
            return '1';
        end if;
        return '0';
    end function;
begin
    s_axis_tready <= '1' when state = COLLECT else '0';
    xgmii_txd <= txd_reg;
    xgmii_txc <= txc_reg;
    busy <= '0' when state = COLLECT else '1';

    process (clk)
        variable wr_len : natural;
        variable crc : std_logic_vector(31 downto 0);
        variable b : byte_t;
        variable data_v : word32_t;
        variable ctrl_v : keep4_t;
        variable abs_idx : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= COLLECT;
                frame_len <= 0;
                out_pos <= 0;
                ifg_count <= 0;
                txd_reg <= IDLE_WORD;
                txc_reg <= IDLE_CTRL;
            else
                case state is
                    when COLLECT =>
                        txd_reg <= IDLE_WORD;
                        txc_reg <= IDLE_CTRL;
                        if s_axis_tvalid = '1' then
                            wr_len := frame_len;
                            for lane in 0 to 7 loop
                                if s_axis_tkeep(lane) = '1' then
                                    if wr_len < MAX_FRAME_BYTES then
                                        mem(wr_len) <= lane_byte(s_axis_tdata, lane);
                                        wr_len := wr_len + 1;
                                    end if;
                                end if;
                            end loop;

                            if s_axis_tlast = '1' then
                                crc := (others => '1');
                                for i in 0 to MAX_FRAME_BYTES - 1 loop
                                    if i < wr_len then
                                        if i >= frame_len then
                                            b := lane_byte(s_axis_tdata, i - frame_len);
                                        else
                                            b := mem(i);
                                        end if;
                                        crc := crc32_next(crc, b);
                                    end if;
                                end loop;
                                crc := not crc;
                                mem(wr_len) <= crc(7 downto 0);
                                mem(wr_len + 1) <= crc(15 downto 8);
                                mem(wr_len + 2) <= crc(23 downto 16);
                                mem(wr_len + 3) <= crc(31 downto 24);
                                frame_len <= wr_len + 4;
                                out_pos <= 0;
                                state <= EMIT;
                            else
                                frame_len <= wr_len;
                            end if;
                        end if;

                    when EMIT =>
                        data_v := (others => '0');
                        ctrl_v := (others => '0');
                        for lane in 0 to 3 loop
                            abs_idx := out_pos + lane;
                            data_v(lane * 8 + 7 downto lane * 8) := tx_byte(abs_idx, frame_len, mem);
                            ctrl_v(lane) := tx_ctrl(abs_idx, frame_len);
                        end loop;
                        txd_reg <= data_v;
                        txc_reg <= ctrl_v;

                        if out_pos + 4 > frame_len + 8 then
                            ifg_count <= 0;
                            state <= IFG;
                        else
                            out_pos <= out_pos + 4;
                        end if;

                    when IFG =>
                        txd_reg <= IDLE_WORD;
                        txc_reg <= IDLE_CTRL;
                        if ifg_count >= IFG_WORDS then
                            frame_len <= 0;
                            state <= COLLECT;
                        else
                            ifg_count <= ifg_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
