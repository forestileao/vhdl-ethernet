-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_eth_fcs_check is
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
        m_axis_tuser        : out std_logic;
        error_bad_frame     : out std_logic;
        error_bad_fcs       : out std_logic
    );
end entity;

architecture rtl of axis_eth_fcs_check is
    type byte_pipe_t is array (0 to 3) of byte_t;
    signal pipe      : byte_pipe_t := (others => (others => '0'));
    signal used      : natural range 0 to 4 := 0;
    signal crc_reg   : std_logic_vector(31 downto 0) := (others => '1');
    signal out_data  : byte_t := (others => '0');
    signal out_valid : std_logic := '0';
    signal out_last  : std_logic := '0';
    signal out_user  : std_logic := '0';
    signal bad_frame : std_logic := '0';
    signal bad_fcs   : std_logic := '0';
begin
    m_axis_tdata    <= out_data;
    m_axis_tvalid   <= out_valid;
    m_axis_tlast    <= out_last;
    m_axis_tuser    <= out_user;
    error_bad_frame <= bad_frame;
    error_bad_fcs   <= bad_fcs;
    s_axis_tready   <= '1' when out_valid = '0' or m_axis_tready = '1' else '0';

    process (clk)
        variable can_send : boolean;
        variable expect   : std_logic_vector(31 downto 0);
        variable got      : std_logic_vector(31 downto 0);
        variable is_bad   : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pipe      <= (others => (others => '0'));
                used      <= 0;
                crc_reg   <= (others => '1');
                out_data  <= (others => '0');
                out_valid <= '0';
                out_last  <= '0';
                out_user  <= '0';
                bad_frame <= '0';
                bad_fcs   <= '0';
            else
                can_send := (out_valid = '0') or (m_axis_tready = '1');
                bad_frame <= '0';
                bad_fcs   <= '0';

                if can_send then
                    out_valid <= '0';
                    out_last  <= '0';
                    out_user  <= '0';

                    if s_axis_tvalid = '1' then
                        if used < 4 then
                            pipe(used) <= s_axis_tdata;
                            used <= used + 1;

                            if s_axis_tlast = '1' then
                                bad_frame <= '1';
                                used      <= 0;
                                crc_reg   <= (others => '1');
                            end if;
                        else
                            out_data  <= pipe(0);
                            out_valid <= '1';
                            crc_reg   <= crc32_next(crc_reg, pipe(0));
                            pipe(0)   <= pipe(1);
                            pipe(1)   <= pipe(2);
                            pipe(2)   <= pipe(3);
                            pipe(3)   <= s_axis_tdata;

                            if s_axis_tlast = '1' then
                                expect := not crc32_next(crc_reg, pipe(0));
                                got    := s_axis_tdata & pipe(3) & pipe(2) & pipe(1);
                                if expect = got and s_axis_tuser = '0' then
                                    is_bad := '0';
                                else
                                    is_bad := '1';
                                end if;

                                out_last  <= '1';
                                out_user  <= is_bad;
                                bad_fcs   <= is_bad;
                                used      <= 0;
                                crc_reg   <= (others => '1');
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
