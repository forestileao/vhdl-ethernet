-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_gmii_rx is
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        gmii_rxd            : in  byte_t;
        gmii_rx_dv          : in  std_logic;
        gmii_rx_er          : in  std_logic;
        m_axis_tdata        : out byte_t;
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in  std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tuser        : out std_logic;
        error_bad_frame     : out std_logic;
        error_bad_fcs       : out std_logic
    );
end entity;

architecture rtl of axis_gmii_rx is
    type state_t is (S_IDLE, S_PREAMBLE, S_PAYLOAD);
    type byte_pipe_t is array (0 to 4) of byte_t;
    signal state       : state_t := S_IDLE;
    signal pipe        : byte_pipe_t := (others => (others => '0'));
    signal used        : natural range 0 to 5 := 0;
    signal crc_reg     : std_logic_vector(31 downto 0) := (others => '1');
    signal frame_error : std_logic := '0';
    signal out_data    : byte_t := (others => '0');
    signal out_valid   : std_logic := '0';
    signal out_last    : std_logic := '0';
    signal out_user    : std_logic := '0';
    signal bad_frame   : std_logic := '0';
    signal bad_fcs     : std_logic := '0';
begin
    m_axis_tdata    <= out_data;
    m_axis_tvalid   <= out_valid;
    m_axis_tlast    <= out_last;
    m_axis_tuser    <= out_user;
    error_bad_frame <= bad_frame;
    error_bad_fcs   <= bad_fcs;

    process (clk)
        variable expect : std_logic_vector(31 downto 0);
        variable got    : std_logic_vector(31 downto 0);
        variable bad    : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= S_IDLE;
                pipe        <= (others => (others => '0'));
                used        <= 0;
                crc_reg     <= (others => '1');
                frame_error <= '0';
                out_data    <= (others => '0');
                out_valid   <= '0';
                out_last    <= '0';
                out_user    <= '0';
                bad_frame   <= '0';
                bad_fcs     <= '0';
            else
                out_valid <= '0';
                out_last  <= '0';
                out_user  <= '0';
                bad_frame <= '0';
                bad_fcs   <= '0';

                case state is
                    when S_IDLE =>
                        used        <= 0;
                        crc_reg     <= (others => '1');
                        frame_error <= '0';
                        if gmii_rx_dv = '1' and gmii_rxd = x"55" then
                            state <= S_PREAMBLE;
                        elsif gmii_rx_dv = '1' and gmii_rxd = x"D5" then
                            state <= S_PAYLOAD;
                        end if;

                    when S_PREAMBLE =>
                        if gmii_rx_dv = '0' then
                            state <= S_IDLE;
                        elsif gmii_rxd = x"D5" then
                            state <= S_PAYLOAD;
                        elsif gmii_rxd /= x"55" then
                            state <= S_IDLE;
                        end if;

                    when S_PAYLOAD =>
                        if gmii_rx_dv = '1' then
                            frame_error <= frame_error or gmii_rx_er;
                            if used < 5 then
                                pipe(used) <= gmii_rxd;
                                used <= used + 1;
                            elsif m_axis_tready = '1' then
                                out_data  <= pipe(0);
                                out_valid <= '1';
                                crc_reg   <= crc32_next(crc_reg, pipe(0));
                                pipe(0)   <= pipe(1);
                                pipe(1)   <= pipe(2);
                                pipe(2)   <= pipe(3);
                                pipe(3)   <= pipe(4);
                                pipe(4)   <= gmii_rxd;
                            end if;
                        else
                            if used < 5 then
                                bad_frame <= '1';
                            elsif m_axis_tready = '1' then
                                expect := not crc32_next(crc_reg, pipe(0));
                                got    := pipe(4) & pipe(3) & pipe(2) & pipe(1);
                                if expect = got and frame_error = '0' then
                                    bad := '0';
                                else
                                    bad := '1';
                                end if;
                                out_data  <= pipe(0);
                                out_valid <= '1';
                                out_last  <= '1';
                                out_user  <= bad;
                                bad_fcs   <= bad;
                                state     <= S_IDLE;
                                used      <= 0;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
