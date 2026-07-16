-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_helpers is
end entity;

architecture sim of tb_axis_helpers is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal arst : std_logic := '1';
    signal sync_rst : std_logic;

    signal req : std_logic_vector(3 downto 0) := (others => '0');
    signal grant_prio : std_logic_vector(3 downto 0);
    signal grant_rr : std_logic_vector(3 downto 0);
    signal grant_index : natural range 0 to 3;
    signal grant_valid : std_logic;
    signal advance : std_logic := '0';

    signal in_data  : byte_t := (others => '0');
    signal in_valid : std_logic := '0';
    signal in_ready : std_logic;
    signal in_last  : std_logic := '0';
    signal in_user  : std_logic := '0';

    signal reg_data  : byte_t;
    signal reg_valid : std_logic;
    signal reg_ready : std_logic;
    signal reg_last  : std_logic;
    signal reg_user  : std_logic;

    signal fifo_data  : byte_t;
    signal fifo_valid : std_logic;
    signal fifo_ready : std_logic := '1';
    signal fifo_last  : std_logic;
    signal fifo_user  : std_logic;

    signal b0_data  : byte_t;
    signal b0_valid : std_logic;
    signal b0_ready : std_logic := '1';
    signal b0_last  : std_logic;
    signal b0_user  : std_logic;

    signal b1_data  : byte_t;
    signal b1_valid : std_logic;
    signal b1_ready : std_logic := '1';
    signal b1_last  : std_logic;
    signal b1_user  : std_logic;
    signal stream_done : boolean := false;
begin
    clk <= not clk after 5 ns;

    rst_sync: entity work.sync_reset_pipe
        generic map (STAGES => 3)
        port map (
            clk => clk,
            arst => arst,
            sync_rst => sync_rst
        );

    prio: entity work.priority_picker
        generic map (WIDTH => 4)
        port map (
            request => req,
            grant => grant_prio,
            grant_index => grant_index,
            grant_valid => grant_valid
        );

    rr: entity work.round_robin_arbiter
        generic map (WIDTH => 4)
        port map (
            clk => clk,
            rst => rst,
            request => req,
            advance => advance,
            grant => grant_rr
        );

    reg_slice: entity work.axis_byte_register
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => in_data, s_axis_tvalid => in_valid, s_axis_tready => in_ready,
            s_axis_tlast => in_last, s_axis_tuser => in_user,
            m_axis_tdata => reg_data, m_axis_tvalid => reg_valid, m_axis_tready => reg_ready,
            m_axis_tlast => reg_last, m_axis_tuser => reg_user
        );

    fifo: entity work.axis_byte_fifo
        generic map (DEPTH => 4)
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => reg_data, s_axis_tvalid => reg_valid, s_axis_tready => reg_ready,
            s_axis_tlast => reg_last, s_axis_tuser => reg_user,
            m_axis_tdata => fifo_data, m_axis_tvalid => fifo_valid, m_axis_tready => fifo_ready,
            m_axis_tlast => fifo_last, m_axis_tuser => fifo_user
        );

    fanout: entity work.axis_byte_broadcast2
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => fifo_data, s_axis_tvalid => fifo_valid, s_axis_tready => fifo_ready,
            s_axis_tlast => fifo_last, s_axis_tuser => fifo_user,
            m0_axis_tdata => b0_data, m0_axis_tvalid => b0_valid, m0_axis_tready => b0_ready,
            m0_axis_tlast => b0_last, m0_axis_tuser => b0_user,
            m1_axis_tdata => b1_data, m1_axis_tvalid => b1_valid, m1_axis_tready => b1_ready,
            m1_axis_tlast => b1_last, m1_axis_tuser => b1_user
        );

    stimulus: process
    begin
        wait for 20 ns;
        arst <= '0';
        wait for 50 ns;
        assert sync_rst = '0' report "synchronized reset did not release" severity failure;

        rst <= '0';
        wait until rising_edge(clk);

        req <= "1010";
        wait for 1 ns;
        assert grant_prio = "0010" report "priority encoder grant mismatch" severity failure;
        assert grant_index = 1 report "priority encoder index mismatch" severity failure;
        assert grant_valid = '1' report "priority encoder valid mismatch" severity failure;

        wait until rising_edge(clk);
        assert grant_rr = "0010" report "round-robin first grant mismatch" severity failure;
        advance <= '1';
        wait until rising_edge(clk);
        advance <= '0';
        wait for 1 ns;
        assert grant_rr = "1000" report "round-robin second grant mismatch" severity failure;

        for i in 0 to 2 loop
            in_data  <= std_logic_vector(to_unsigned(16#90# + i, 8));
            in_valid <= '1';
            if i = 2 then
                in_last <= '1';
            else
                in_last <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when in_ready = '1';
            end loop;
        end loop;
        in_valid <= '0';
        in_last  <= '0';

        for i in 0 to 50 loop
            wait until rising_edge(clk);
            exit when stream_done;
        end loop;

        assert stream_done report "stream helper chain timed out" severity failure;
        finish;
    end process;

    stream_scoreboard: process (clk)
        variable pos0 : natural := 0;
        variable pos1 : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos0 := 0;
                pos1 := 0;
                stream_done <= false;
            else
                if b0_valid = '1' and b0_ready = '1' then
                    assert b0_data = std_logic_vector(to_unsigned(16#90# + pos0, 8))
                        report "broadcast output 0 data mismatch" severity failure;
                    assert b0_user = '0' report "broadcast output 0 user mismatch" severity failure;
                    if b0_last = '1' then
                        assert pos0 = 2 report "broadcast output 0 length mismatch" severity failure;
                    end if;
                    pos0 := pos0 + 1;
                end if;

                if b1_valid = '1' and b1_ready = '1' then
                    assert b1_data = std_logic_vector(to_unsigned(16#90# + pos1, 8))
                        report "broadcast output 1 data mismatch" severity failure;
                    assert b1_user = '0' report "broadcast output 1 user mismatch" severity failure;
                    if b1_last = '1' then
                        assert pos1 = 2 report "broadcast output 1 length mismatch" severity failure;
                        stream_done <= true;
                    end if;
                    pos1 := pos1 + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
