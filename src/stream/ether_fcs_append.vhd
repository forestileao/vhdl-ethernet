-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_eth_fcs_insert is
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        s_axis_tdata        : in  byte_t;
        s_axis_tvalid       : in  std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in  std_logic;
        s_axis_tuser        : in  std_logic;
        m_axis_tdata        : out byte_t;
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in  std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tuser        : out std_logic
    );
end entity;

architecture rtl of axis_eth_fcs_insert is
    type state_t is (S_PAYLOAD, S_FCS0, S_FCS1, S_FCS2, S_FCS3);
    signal state     : state_t := S_PAYLOAD;
    signal crc_reg   : std_logic_vector(31 downto 0) := (others => '1');
    signal fcs_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal out_data  : byte_t := (others => '0');
    signal out_valid : std_logic := '0';
    signal out_last  : std_logic := '0';
    signal out_user  : std_logic := '0';
begin
    m_axis_tdata  <= out_data;
    m_axis_tvalid <= out_valid;
    m_axis_tlast  <= out_last;
    m_axis_tuser  <= out_user;
    s_axis_tready <= '1' when state = S_PAYLOAD and (out_valid = '0' or m_axis_tready = '1') else '0';

    process (clk)
        variable can_send : boolean;
        variable cnext    : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= S_PAYLOAD;
                crc_reg   <= (others => '1');
                fcs_reg   <= (others => '0');
                out_data  <= (others => '0');
                out_valid <= '0';
                out_last  <= '0';
                out_user  <= '0';
            else
                can_send := (out_valid = '0') or (m_axis_tready = '1');

                if can_send then
                    out_valid <= '0';
                    out_last  <= '0';
                    out_user  <= '0';

                    case state is
                        when S_PAYLOAD =>
                            if s_axis_tvalid = '1' then
                                cnext := crc32_next(crc_reg, s_axis_tdata);
                                crc_reg   <= cnext;
                                out_data  <= s_axis_tdata;
                                out_valid <= '1';
                                out_user  <= s_axis_tuser;

                                if s_axis_tlast = '1' then
                                    fcs_reg <= not cnext;
                                    crc_reg <= (others => '1');
                                    state   <= S_FCS0;
                                end if;
                            end if;

                        when S_FCS0 =>
                            out_data  <= fcs_reg(7 downto 0);
                            out_valid <= '1';
                            state     <= S_FCS1;

                        when S_FCS1 =>
                            out_data  <= fcs_reg(15 downto 8);
                            out_valid <= '1';
                            state     <= S_FCS2;

                        when S_FCS2 =>
                            out_data  <= fcs_reg(23 downto 16);
                            out_valid <= '1';
                            state     <= S_FCS3;

                        when S_FCS3 =>
                            out_data  <= fcs_reg(31 downto 24);
                            out_valid <= '1';
                            out_last  <= '1';
                            state     <= S_PAYLOAD;
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;
