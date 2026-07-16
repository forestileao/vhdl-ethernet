-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_fcs is
end entity;

architecture sim of tb_fcs is
    type byte_vec_t is array (natural range <>) of byte_t;
    constant frame : byte_vec_t := (x"DA", x"02", x"03", x"04", x"55", x"AA", x"10");

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal in_data  : byte_t := (others => '0');
    signal in_valid : std_logic := '0';
    signal in_ready : std_logic;
    signal in_last  : std_logic := '0';
    signal in_user  : std_logic := '0';

    signal fcs_data  : byte_t;
    signal fcs_valid : std_logic;
    signal fcs_ready : std_logic;
    signal fcs_last  : std_logic;
    signal fcs_user  : std_logic;

    signal out_data  : byte_t;
    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';
    signal out_last  : std_logic;
    signal out_user  : std_logic;
    signal bad_frame : std_logic;
    signal bad_fcs   : std_logic;
    signal done      : boolean := false;

    procedure send_frame(
        signal clk_i   : in std_logic;
        signal data    : out byte_t;
        signal valid   : out std_logic;
        signal ready   : in std_logic;
        signal last    : out std_logic;
        constant bytes : in byte_vec_t
    ) is
    begin
        for i in bytes'range loop
            data  <= bytes(i);
            valid <= '1';
            if i = bytes'high then
                last <= '1';
            else
                last <= '0';
            end if;

            loop
                wait until rising_edge(clk_i);
                exit when ready = '1';
            end loop;
        end loop;

        valid <= '0';
        last  <= '0';
        data  <= (others => '0');
    end procedure;
begin
    clk <= not clk after 5 ns;

    dut_insert: entity work.axis_eth_fcs_insert
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => in_data, s_axis_tvalid => in_valid, s_axis_tready => in_ready,
            s_axis_tlast => in_last, s_axis_tuser => in_user,
            m_axis_tdata => fcs_data, m_axis_tvalid => fcs_valid, m_axis_tready => fcs_ready,
            m_axis_tlast => fcs_last, m_axis_tuser => fcs_user
        );

    dut_check: entity work.axis_eth_fcs_check
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => fcs_data, s_axis_tvalid => fcs_valid, s_axis_tready => fcs_ready,
            s_axis_tlast => fcs_last, s_axis_tuser => fcs_user,
            m_axis_tdata => out_data, m_axis_tvalid => out_valid, m_axis_tready => out_ready,
            m_axis_tlast => out_last, m_axis_tuser => out_user,
            error_bad_frame => bad_frame, error_bad_fcs => bad_fcs
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);
        send_frame(clk, in_data, in_valid, in_ready, in_last, frame);

        for i in 0 to 80 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "FCS round-trip timed out" severity failure;
        assert bad_frame = '0' report "FCS checker reported a short frame" severity failure;
        assert bad_fcs = '0' report "FCS checker reported a bad FCS" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
            elsif out_valid = '1' and out_ready = '1' then
                assert out_data = frame(pos) report "FCS output byte mismatch" severity failure;
                assert out_user = '0' report "FCS output user error flag set" severity failure;

                if out_last = '1' then
                    assert pos = frame'length - 1 report "FCS output ended at the wrong byte" severity failure;
                    done <= true;
                end if;

                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
