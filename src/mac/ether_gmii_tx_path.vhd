-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_gmii_tx is
    generic (
        MIN_FRAME_LENGTH : positive := 64;
        IFG_LENGTH       : positive := 12
    );
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        s_axis_tdata        : in  byte_t;
        s_axis_tvalid       : in  std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in  std_logic;
        s_axis_tuser        : in  std_logic;
        gmii_txd            : out byte_t;
        gmii_tx_en          : out std_logic;
        gmii_tx_er          : out std_logic;
        busy                : out std_logic
    );
end entity;

architecture rtl of axis_gmii_tx is
    type state_t is (S_IDLE, S_PREAMBLE, S_PAYLOAD, S_PAD, S_FCS0, S_FCS1, S_FCS2, S_FCS3, S_IFG);
    signal state       : state_t := S_IDLE;
    signal pre_cnt     : natural range 0 to 7 := 0;
    signal ifg_cnt     : natural range 0 to IFG_LENGTH := 0;
    signal frame_count : natural range 0 to MIN_FRAME_LENGTH := 0;
    signal crc_reg     : std_logic_vector(31 downto 0) := (others => '1');
    signal fcs_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal txd_reg     : byte_t := (others => '0');
    signal tx_en_reg   : std_logic := '0';
    signal tx_er_reg   : std_logic := '0';
begin
    gmii_txd   <= txd_reg;
    gmii_tx_en <= tx_en_reg;
    gmii_tx_er <= tx_er_reg;
    busy       <= '0' when state = S_IDLE else '1';

    s_axis_tready <= '1' when state = S_PAYLOAD else '0';

    process (clk)
        variable cnext : std_logic_vector(31 downto 0);
        variable min_payload_with_fcs : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= S_IDLE;
                pre_cnt     <= 0;
                ifg_cnt     <= 0;
                frame_count <= 0;
                crc_reg     <= (others => '1');
                fcs_reg     <= (others => '0');
                txd_reg     <= (others => '0');
                tx_en_reg   <= '0';
                tx_er_reg   <= '0';
            else
                txd_reg   <= (others => '0');
                tx_en_reg <= '0';
                tx_er_reg <= '0';

                min_payload_with_fcs := MIN_FRAME_LENGTH;

                case state is
                    when S_IDLE =>
                        crc_reg     <= (others => '1');
                        frame_count <= 0;
                        if s_axis_tvalid = '1' then
                            pre_cnt <= 0;
                            state   <= S_PREAMBLE;
                        end if;

                    when S_PREAMBLE =>
                        tx_en_reg <= '1';
                        if pre_cnt = 7 then
                            txd_reg <= x"D5";
                            state   <= S_PAYLOAD;
                        else
                            txd_reg <= x"55";
                            pre_cnt <= pre_cnt + 1;
                        end if;

                    when S_PAYLOAD =>
                        if s_axis_tvalid = '1' then
                            tx_en_reg <= '1';
                            tx_er_reg <= s_axis_tuser and s_axis_tlast;
                            txd_reg   <= s_axis_tdata;
                            cnext     := crc32_next(crc_reg, s_axis_tdata);
                            crc_reg   <= cnext;

                            if frame_count < MIN_FRAME_LENGTH then
                                frame_count <= frame_count + 1;
                            end if;

                            if s_axis_tlast = '1' then
                                if s_axis_tuser = '1' then
                                    ifg_cnt <= 0;
                                    state   <= S_IFG;
                                elsif frame_count + 1 + 4 < min_payload_with_fcs then
                                    state <= S_PAD;
                                else
                                    fcs_reg <= not cnext;
                                    state   <= S_FCS0;
                                end if;
                            end if;
                        end if;

                    when S_PAD =>
                        tx_en_reg <= '1';
                        txd_reg   <= x"00";
                        cnext     := crc32_next(crc_reg, x"00");
                        crc_reg   <= cnext;

                        if frame_count < MIN_FRAME_LENGTH then
                            frame_count <= frame_count + 1;
                        end if;

                        if frame_count + 1 + 4 >= min_payload_with_fcs then
                            fcs_reg <= not cnext;
                            state   <= S_FCS0;
                        end if;

                    when S_FCS0 =>
                        tx_en_reg <= '1';
                        txd_reg   <= fcs_reg(7 downto 0);
                        state     <= S_FCS1;

                    when S_FCS1 =>
                        tx_en_reg <= '1';
                        txd_reg   <= fcs_reg(15 downto 8);
                        state     <= S_FCS2;

                    when S_FCS2 =>
                        tx_en_reg <= '1';
                        txd_reg   <= fcs_reg(23 downto 16);
                        state     <= S_FCS3;

                    when S_FCS3 =>
                        tx_en_reg <= '1';
                        txd_reg   <= fcs_reg(31 downto 24);
                        ifg_cnt   <= 0;
                        state     <= S_IFG;

                    when S_IFG =>
                        if ifg_cnt + 1 >= IFG_LENGTH then
                            state <= S_IDLE;
                        else
                            ifg_cnt <= ifg_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
