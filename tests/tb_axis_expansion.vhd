-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_expansion is
end entity;

architecture sim of tb_axis_expansion is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal a_s_data : byte_t := (others => '0');
    signal a_s_valid : std_logic := '0';
    signal a_s_ready : std_logic;
    signal a_s_last : std_logic := '0';
    signal a_s_user : std_logic := '0';
    signal a_m_data : byte_t;
    signal a_m_valid : std_logic;
    signal a_m_ready : std_logic := '1';
    signal a_m_last : std_logic;
    signal a_m_user : std_logic;

    signal j0_data : byte_t := (others => '0');
    signal j0_valid : std_logic := '0';
    signal j0_ready : std_logic;
    signal j0_last : std_logic := '0';
    signal j0_user : std_logic := '0';
    signal j1_data : byte_t := (others => '0');
    signal j1_valid : std_logic := '0';
    signal j1_ready : std_logic;
    signal j1_last : std_logic := '0';
    signal j1_user : std_logic := '0';
    signal j_data : byte_t;
    signal j_valid : std_logic;
    signal j_last : std_logic;
    signal j_user : std_logic;
    signal j_busy : std_logic;

    signal x0_data : byte_t := x"A0";
    signal x0_valid : std_logic := '0';
    signal x0_ready : std_logic;
    signal x1_data : byte_t := x"B0";
    signal x1_valid : std_logic := '0';
    signal x1_ready : std_logic;
    signal xm0_data : byte_t;
    signal xm0_valid : std_logic;
    signal xm1_data : byte_t;
    signal xm1_valid : std_logic;

    signal sw0_data : byte_t := (others => '0');
    signal sw0_valid : std_logic := '0';
    signal sw0_ready : std_logic;
    signal sw1_data : byte_t := (others => '0');
    signal sw1_valid : std_logic := '0';
    signal sw1_ready : std_logic;
    signal sw1_last : std_logic := '0';
    signal swm0_data : byte_t;
    signal swm0_valid : std_logic;
    signal swm1_valid : std_logic;
    signal swm0_last : std_logic;

    signal b_s_data : byte_t := (others => '0');
    signal b_s_valid : std_logic := '0';
    signal b_s_ready : std_logic;
    signal b_s_last : std_logic := '0';
    signal ll_data : byte_t;
    signal ll_sof_n : std_logic;
    signal ll_eof_n : std_logic;
    signal ll_src_rdy_n : std_logic;
    signal ll_dst_rdy_n : std_logic;
    signal b_m_data : byte_t;
    signal b_m_valid : std_logic;
    signal b_m_last : std_logic;

    signal adapter_done : boolean := false;
    signal join_done : boolean := false;
    signal switch_done : boolean := false;
    signal bridge_done : boolean := false;
begin
    clk <= not clk after 5 ns;

    adapter_fifo: entity work.axis_byte_fifo_adapter
        generic map (DEPTH => 4)
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => a_s_data,
            s_axis_tvalid => a_s_valid,
            s_axis_tready => a_s_ready,
            s_axis_tlast => a_s_last,
            s_axis_tuser => a_s_user,
            m_axis_tdata => a_m_data,
            m_axis_tvalid => a_m_valid,
            m_axis_tready => a_m_ready,
            m_axis_tlast => a_m_last,
            m_axis_tuser => a_m_user
        );

    joiner: entity work.axis_byte_frame_join2
        port map (
            clk => clk,
            rst => rst,
            s0_axis_tdata => j0_data,
            s0_axis_tvalid => j0_valid,
            s0_axis_tready => j0_ready,
            s0_axis_tlast => j0_last,
            s0_axis_tuser => j0_user,
            s1_axis_tdata => j1_data,
            s1_axis_tvalid => j1_valid,
            s1_axis_tready => j1_ready,
            s1_axis_tlast => j1_last,
            s1_axis_tuser => j1_user,
            m_axis_tdata => j_data,
            m_axis_tvalid => j_valid,
            m_axis_tready => '1',
            m_axis_tlast => j_last,
            m_axis_tuser => j_user,
            busy => j_busy
        );

    crosspoint: entity work.axis_byte_crosspoint2
        port map (
            m0_select => '1',
            m1_select => '0',
            s0_axis_tdata => x0_data,
            s0_axis_tvalid => x0_valid,
            s0_axis_tready => x0_ready,
            s0_axis_tlast => '1',
            s0_axis_tuser => '0',
            s1_axis_tdata => x1_data,
            s1_axis_tvalid => x1_valid,
            s1_axis_tready => x1_ready,
            s1_axis_tlast => '1',
            s1_axis_tuser => '0',
            m0_axis_tdata => xm0_data,
            m0_axis_tvalid => xm0_valid,
            m0_axis_tready => '1',
            m0_axis_tlast => open,
            m0_axis_tuser => open,
            m1_axis_tdata => xm1_data,
            m1_axis_tvalid => xm1_valid,
            m1_axis_tready => '1',
            m1_axis_tlast => open,
            m1_axis_tuser => open
        );

    switcher: entity work.axis_byte_switch2
        port map (
            clk => clk,
            rst => rst,
            select_input => '1',
            select_output => '0',
            s0_axis_tdata => sw0_data,
            s0_axis_tvalid => sw0_valid,
            s0_axis_tready => sw0_ready,
            s0_axis_tlast => '0',
            s0_axis_tuser => '0',
            s1_axis_tdata => sw1_data,
            s1_axis_tvalid => sw1_valid,
            s1_axis_tready => sw1_ready,
            s1_axis_tlast => sw1_last,
            s1_axis_tuser => '0',
            m0_axis_tdata => swm0_data,
            m0_axis_tvalid => swm0_valid,
            m0_axis_tready => '1',
            m0_axis_tlast => swm0_last,
            m0_axis_tuser => open,
            m1_axis_tdata => open,
            m1_axis_tvalid => swm1_valid,
            m1_axis_tready => '1',
            m1_axis_tlast => open,
            m1_axis_tuser => open
        );

    axis_to_ll: entity work.axis_to_ll_byte_bridge
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => b_s_data,
            s_axis_tvalid => b_s_valid,
            s_axis_tready => b_s_ready,
            s_axis_tlast => b_s_last,
            ll_data_out => ll_data,
            ll_sof_out_n => ll_sof_n,
            ll_eof_out_n => ll_eof_n,
            ll_src_rdy_out_n => ll_src_rdy_n,
            ll_dst_rdy_in_n => ll_dst_rdy_n
        );

    ll_to_axis: entity work.ll_to_axis_byte_bridge
        port map (
            ll_data_in => ll_data,
            ll_sof_in_n => ll_sof_n,
            ll_eof_in_n => ll_eof_n,
            ll_src_rdy_in_n => ll_src_rdy_n,
            ll_dst_rdy_out_n => ll_dst_rdy_n,
            m_axis_tdata => b_m_data,
            m_axis_tvalid => b_m_valid,
            m_axis_tready => '1',
            m_axis_tlast => b_m_last
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        for i in 0 to 1 loop
            a_s_data <= std_logic_vector(to_unsigned(16#C0# + i, 8));
            a_s_valid <= '1';
            if i = 1 then
                a_s_last <= '1';
                a_s_user <= '1';
            else
                a_s_last <= '0';
                a_s_user <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when a_s_ready = '1';
            end loop;
        end loop;
        a_s_valid <= '0';
        a_s_last <= '0';
        a_s_user <= '0';

        x0_valid <= '1';
        x1_valid <= '1';
        wait for 1 ns;
        assert xm0_valid = '1' and xm0_data = x"B0" report "crosspoint output 0 mismatch" severity failure;
        assert xm1_valid = '1' and xm1_data = x"A0" report "crosspoint output 1 mismatch" severity failure;
        assert x0_ready = '1' and x1_ready = '1' report "crosspoint ready mismatch" severity failure;
        wait until rising_edge(clk);
        x0_valid <= '0';
        x1_valid <= '0';

        for i in 0 to 1 loop
            j0_data <= std_logic_vector(to_unsigned(16#10# + i, 8));
            j0_valid <= '1';
            if i = 1 then
                j0_last <= '1';
                j0_user <= '1';
            else
                j0_last <= '0';
                j0_user <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when j0_ready = '1';
            end loop;
        end loop;
        j0_valid <= '0';
        j0_last <= '0';
        j0_user <= '0';

        for i in 0 to 1 loop
            j1_data <= std_logic_vector(to_unsigned(16#20# + i, 8));
            j1_valid <= '1';
            if i = 1 then
                j1_last <= '1';
            else
                j1_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when j1_ready = '1';
            end loop;
        end loop;
        j1_valid <= '0';
        j1_last <= '0';

        for i in 0 to 1 loop
            sw1_data <= std_logic_vector(to_unsigned(16#D0# + i, 8));
            sw1_valid <= '1';
            if i = 1 then
                sw1_last <= '1';
            else
                sw1_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when sw1_ready = '1';
            end loop;
        end loop;
        sw1_valid <= '0';
        sw1_last <= '0';

        for i in 0 to 1 loop
            b_s_data <= std_logic_vector(to_unsigned(16#E0# + i, 8));
            b_s_valid <= '1';
            if i = 1 then
                b_s_last <= '1';
            else
                b_s_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when b_s_ready = '1';
            end loop;
        end loop;
        b_s_valid <= '0';
        b_s_last <= '0';

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when adapter_done and join_done and switch_done and bridge_done;
        end loop;

        assert adapter_done report "adapter/fifo adapter timed out" severity failure;
        assert join_done report "frame join timed out" severity failure;
        assert switch_done report "switch timed out" severity failure;
        assert bridge_done report "LocalLink bridge timed out" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable a_pos : natural := 0;
        variable j_pos : natural := 0;
        variable sw_pos : natural := 0;
        variable b_pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                a_pos := 0;
                j_pos := 0;
                sw_pos := 0;
                b_pos := 0;
                adapter_done <= false;
                join_done <= false;
                switch_done <= false;
                bridge_done <= false;
            else
                if a_m_valid = '1' and a_m_ready = '1' then
                    assert a_m_data = std_logic_vector(to_unsigned(16#C0# + a_pos, 8))
                        report "adapter output mismatch" severity failure;
                    if a_m_last = '1' then
                        assert a_pos = 1 report "adapter output length mismatch" severity failure;
                        assert a_m_user = '1' report "adapter user mismatch" severity failure;
                        adapter_done <= true;
                    end if;
                    a_pos := a_pos + 1;
                end if;

                if j_valid = '1' then
                    if j_pos < 2 then
                        assert j_data = std_logic_vector(to_unsigned(16#10# + j_pos, 8))
                            report "join first frame mismatch" severity failure;
                        assert j_last = '0' report "join ended on first frame" severity failure;
                    else
                        assert j_data = std_logic_vector(to_unsigned(16#20# + j_pos - 2, 8))
                            report "join second frame mismatch" severity failure;
                        if j_last = '1' then
                            assert j_pos = 3 report "join output length mismatch" severity failure;
                            assert j_user = '1' report "join user aggregation mismatch" severity failure;
                            join_done <= true;
                        end if;
                    end if;
                    j_pos := j_pos + 1;
                end if;

                if swm0_valid = '1' then
                    assert swm1_valid = '0' report "switch drove wrong output" severity failure;
                    assert swm0_data = std_logic_vector(to_unsigned(16#D0# + sw_pos, 8))
                        report "switch data mismatch" severity failure;
                    if swm0_last = '1' then
                        assert sw_pos = 1 report "switch output length mismatch" severity failure;
                        switch_done <= true;
                    end if;
                    sw_pos := sw_pos + 1;
                end if;

                if b_m_valid = '1' then
                    assert b_m_data = std_logic_vector(to_unsigned(16#E0# + b_pos, 8))
                        report "bridge data mismatch" severity failure;
                    if b_m_last = '1' then
                        assert b_pos = 1 report "bridge output length mismatch" severity failure;
                        bridge_done <= true;
                    end if;
                    b_pos := b_pos + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
