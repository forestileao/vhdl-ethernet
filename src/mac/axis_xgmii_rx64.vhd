-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_xgmii_rx64 is
    generic (
        MAX_FRAME_BYTES : positive := 2048
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        xgmii_rxd       : in  word64_t;
        xgmii_rxc       : in  keep8_t;
        m_axis_tdata    : out word64_t;
        m_axis_tkeep    : out keep8_t;
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tuser    : out std_logic;
        error_bad_frame : out std_logic;
        error_bad_fcs   : out std_logic
    );
end entity;

architecture rtl of axis_xgmii_rx64 is
    type byte_mem_t is array (0 to MAX_FRAME_BYTES + 3) of byte_t;
    type state_t is (IDLE, COLLECT, EMIT);

    signal state : state_t := IDLE;
    signal mem : byte_mem_t := (others => (others => '0'));
    signal raw_len : natural range 0 to MAX_FRAME_BYTES + 4 := 0;
    signal payload_len : natural range 0 to MAX_FRAME_BYTES := 0;
    signal out_pos : natural range 0 to MAX_FRAME_BYTES := 0;
    signal skip_count : natural range 0 to 7 := 0;
    signal frame_error : std_logic := '0';
    signal bad_frame_reg : std_logic := '0';
    signal bad_fcs_reg : std_logic := '0';
    signal out_user : std_logic := '0';
    signal out_data : word64_t := (others => '0');
    signal out_keep : keep8_t := (others => '0');
begin
    m_axis_tdata <= out_data;
    m_axis_tkeep <= out_keep;
    m_axis_tvalid <= '1' when state = EMIT else '0';
    m_axis_tlast <= '1' when state = EMIT and out_pos + 8 >= payload_len else '0';
    m_axis_tuser <= out_user when state = EMIT and out_pos + 8 >= payload_len else '0';
    error_bad_frame <= bad_frame_reg;
    error_bad_fcs <= bad_fcs_reg;

    process (all)
        variable data_v : word64_t;
        variable keep_v : keep8_t;
    begin
        data_v := (others => '0');
        keep_v := (others => '0');
        for lane in 0 to 7 loop
            if state = EMIT and out_pos + lane < payload_len then
                data_v(lane * 8 + 7 downto lane * 8) := mem(out_pos + lane);
                keep_v(lane) := '1';
            end if;
        end loop;
        out_data <= data_v;
        out_keep <= keep_v;
    end process;

    process (clk)
        variable b : byte_t;
        variable crc : std_logic_vector(31 downto 0);
        variable expect : std_logic_vector(31 downto 0);
        variable got : std_logic_vector(31 downto 0);
        variable bad : std_logic;
        variable frame : byte_mem_t;
        variable wr_len : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                raw_len <= 0;
                payload_len <= 0;
                out_pos <= 0;
                skip_count <= 0;
                frame_error <= '0';
                bad_frame_reg <= '0';
                bad_fcs_reg <= '0';
                out_user <= '0';
            else
                bad_frame_reg <= '0';
                bad_fcs_reg <= '0';

                case state is
                    when IDLE =>
                        raw_len <= 0;
                        payload_len <= 0;
                        out_pos <= 0;
                        skip_count <= 0;
                        frame_error <= '0';
                        for lane in 0 to 7 loop
                            if xgmii_rxc(lane) = '1' and lane_byte(xgmii_rxd, lane) = x"FB" then
                                state <= COLLECT;
                                skip_count <= 0;
                            end if;
                        end loop;

                    when COLLECT =>
                        frame := mem;
                        wr_len := raw_len;
                        for lane in 0 to 7 loop
                            b := lane_byte(xgmii_rxd, lane);
                            if xgmii_rxc(lane) = '1' then
                                if b = x"FD" then
                                    if wr_len < 5 then
                                        bad := '1';
                                        payload_len <= 1;
                                        mem(0) <= (others => '0');
                                    else
                                        crc := (others => '1');
                                        for i in 0 to MAX_FRAME_BYTES - 1 loop
                                            if i < wr_len - 4 then
                                                crc := crc32_next(crc, frame(i));
                                            end if;
                                        end loop;
                                        expect := not crc;
                                        got := frame(wr_len - 1) & frame(wr_len - 2) &
                                            frame(wr_len - 3) & frame(wr_len - 4);
                                        if got = expect and frame_error = '0' then
                                            bad := '0';
                                        else
                                            bad := '1';
                                        end if;
                                        payload_len <= wr_len - 4;
                                    end if;
                                    out_user <= bad;
                                    bad_fcs_reg <= bad;
                                    out_pos <= 0;
                                    state <= EMIT;
                                    exit;
                                elsif b /= x"07" then
                                    frame_error <= '1';
                                end if;
                            elsif skip_count > 0 then
                                skip_count <= skip_count - 1;
                            elsif wr_len < MAX_FRAME_BYTES + 4 then
                                frame(wr_len) := b;
                                mem(wr_len) <= b;
                                wr_len := wr_len + 1;
                                raw_len <= wr_len;
                            else
                                frame_error <= '1';
                            end if;
                        end loop;

                    when EMIT =>
                        if m_axis_tready = '1' then
                            if out_pos + 8 >= payload_len then
                                state <= IDLE;
                            else
                                out_pos <= out_pos + 8;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
