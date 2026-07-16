-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_frame_adjust is
end entity;

architecture sim of tb_frame_adjust is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal min_len : word16_t := x"0000";
    signal max_len : word16_t := x"0000";
    signal s_data : byte_t := (others => '0');
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_last : std_logic := '0';
    signal s_user : std_logic := '0';
    signal m_data : byte_t;
    signal m_valid : std_logic;
    signal m_ready : std_logic := '1';
    signal m_last : std_logic;
    signal m_user : std_logic;
    signal original_len : word16_t;
    signal adjusted_len : word16_t;
    signal status_valid : std_logic;
    signal status_padded : std_logic;
    signal status_truncated : std_logic;
    signal mode : natural range 0 to 1 := 0;
    signal pad_output_done : boolean := false;
    signal pad_status_done : boolean := false;
    signal trunc_output_done : boolean := false;
    signal trunc_status_done : boolean := false;
begin
    clk <= not clk after 5 ns;

    dut: entity work.axis_frame_length_adjust_fifo
        generic map (FIFO_DEPTH => 8)
        port map (
            clk => clk,
            rst => rst,
            min_length => min_len,
            max_length => max_len,
            s_axis_tdata => s_data,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tlast => s_last,
            s_axis_tuser => s_user,
            m_axis_tdata => m_data,
            m_axis_tvalid => m_valid,
            m_axis_tready => m_ready,
            m_axis_tlast => m_last,
            m_axis_tuser => m_user,
            original_length => original_len,
            adjusted_length => adjusted_len,
            status_valid => status_valid,
            status_padded => status_padded,
            status_truncated => status_truncated
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        mode <= 0;
        min_len <= x"0005";
        max_len <= x"000A";
        for i in 0 to 2 loop
            s_data <= std_logic_vector(to_unsigned(16#40# + i, 8));
            s_valid <= '1';
            if i = 2 then
                s_last <= '1';
            else
                s_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when s_ready = '1';
            end loop;
        end loop;
        s_valid <= '0';
        s_last <= '0';

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when pad_output_done and pad_status_done;
        end loop;
        assert pad_output_done report "padded output timed out" severity failure;
        assert pad_status_done report "padded status timed out" severity failure;

        mode <= 1;
        min_len <= x"0000";
        max_len <= x"0003";
        wait until rising_edge(clk);
        for i in 0 to 4 loop
            s_data <= std_logic_vector(to_unsigned(16#50# + i, 8));
            s_valid <= '1';
            if i = 4 then
                s_last <= '1';
            else
                s_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when s_ready = '1';
            end loop;
        end loop;
        s_valid <= '0';
        s_last <= '0';

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when trunc_output_done and trunc_status_done;
        end loop;
        assert trunc_output_done report "truncated output timed out" severity failure;
        assert trunc_status_done report "truncated status timed out" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pad_pos : natural := 0;
        variable trunc_pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pad_pos := 0;
                trunc_pos := 0;
                pad_output_done <= false;
                pad_status_done <= false;
                trunc_output_done <= false;
                trunc_status_done <= false;
            else
                if m_valid = '1' and m_ready = '1' then
                    if mode = 0 then
                        if pad_pos < 3 then
                            assert m_data = std_logic_vector(to_unsigned(16#40# + pad_pos, 8))
                                report "padded frame data mismatch" severity failure;
                        else
                            assert m_data = x"00" report "padding byte mismatch" severity failure;
                        end if;
                        if m_last = '1' then
                            assert pad_pos = 4 report "padded frame length mismatch" severity failure;
                            assert m_user = '0' report "padded user flag mismatch" severity failure;
                            pad_output_done <= true;
                        end if;
                        pad_pos := pad_pos + 1;
                    else
                        assert m_data = std_logic_vector(to_unsigned(16#50# + trunc_pos, 8))
                            report "truncated frame data mismatch" severity failure;
                        if m_last = '1' then
                            assert trunc_pos = 2 report "truncated frame length mismatch" severity failure;
                            assert m_user = '1' report "truncated user flag mismatch" severity failure;
                            trunc_output_done <= true;
                        end if;
                        trunc_pos := trunc_pos + 1;
                    end if;
                end if;

                if status_valid = '1' then
                    if mode = 0 then
                        assert original_len = x"0003" report "padded original length mismatch" severity failure;
                        assert adjusted_len = x"0005" report "padded adjusted length mismatch" severity failure;
                        assert status_padded = '1' report "padded status missing" severity failure;
                        assert status_truncated = '0' report "unexpected truncated status on pad" severity failure;
                        pad_status_done <= true;
                    else
                        assert original_len = x"0005" report "truncated original length mismatch" severity failure;
                        assert adjusted_len = x"0003" report "truncated adjusted length mismatch" severity failure;
                        assert status_padded = '0' report "unexpected padded status on truncate" severity failure;
                        assert status_truncated = '1' report "truncated status missing" severity failure;
                        trunc_status_done <= true;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
