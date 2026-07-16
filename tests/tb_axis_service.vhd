-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_service is
end entity;

architecture sim of tb_axis_service is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal s_data : byte_t := (others => '0');
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_last : std_logic := '0';
    signal s_user : std_logic := '0';

    signal p_data : byte_t;
    signal p_valid : std_logic;
    signal p_ready : std_logic;
    signal p_last : std_logic;
    signal p_user : std_logic;

    signal pf_data : byte_t;
    signal pf_valid : std_logic;
    signal pf_ready : std_logic;
    signal pf_last : std_logic;
    signal pf_user : std_logic;

    signal sr_data : byte_t;
    signal sr_valid : std_logic;
    signal sr_ready : std_logic;
    signal sr_last : std_logic;
    signal sr_user : std_logic;

    signal sf_data : byte_t;
    signal sf_valid : std_logic;
    signal sf_ready : std_logic;
    signal sf_last : std_logic;
    signal sf_user : std_logic;

    signal rl_data : byte_t;
    signal rl_valid : std_logic;
    signal rl_ready : std_logic;
    signal rl_last : std_logic;
    signal rl_user : std_logic;

    signal out_data : byte_t;
    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';
    signal out_last : std_logic;
    signal out_user : std_logic;
    signal byte_count : std_logic_vector(31 downto 0);
    signal frame_count : std_logic_vector(31 downto 0);
    signal bad_count : std_logic_vector(31 downto 0);
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns;

    pipeline: entity work.axis_byte_pipeline
        generic map (STAGES => 2)
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => s_data, s_axis_tvalid => s_valid, s_axis_tready => s_ready,
            s_axis_tlast => s_last, s_axis_tuser => s_user,
            m_axis_tdata => p_data, m_axis_tvalid => p_valid, m_axis_tready => p_ready,
            m_axis_tlast => p_last, m_axis_tuser => p_user
        );

    pipe_fifo: entity work.axis_byte_pipeline_fifo
        generic map (DEPTH => 4)
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => p_data, s_axis_tvalid => p_valid, s_axis_tready => p_ready,
            s_axis_tlast => p_last, s_axis_tuser => p_user,
            m_axis_tdata => pf_data, m_axis_tvalid => pf_valid, m_axis_tready => pf_ready,
            m_axis_tlast => pf_last, m_axis_tuser => pf_user
        );

    srl_reg: entity work.axis_byte_srl_register
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => pf_data, s_axis_tvalid => pf_valid, s_axis_tready => pf_ready,
            s_axis_tlast => pf_last, s_axis_tuser => pf_user,
            m_axis_tdata => sr_data, m_axis_tvalid => sr_valid, m_axis_tready => sr_ready,
            m_axis_tlast => sr_last, m_axis_tuser => sr_user
        );

    srl_fifo: entity work.axis_byte_srl_fifo
        generic map (DEPTH => 4)
        port map (
            clk => clk, rst => rst,
            s_axis_tdata => sr_data, s_axis_tvalid => sr_valid, s_axis_tready => sr_ready,
            s_axis_tlast => sr_last, s_axis_tuser => sr_user,
            m_axis_tdata => sf_data, m_axis_tvalid => sf_valid, m_axis_tready => sf_ready,
            m_axis_tlast => sf_last, m_axis_tuser => sf_user
        );

    limiter: entity work.axis_byte_rate_limit
        port map (
            clk => clk, rst => rst,
            enable => '1', cycle_gap => x"0001",
            s_axis_tdata => sf_data, s_axis_tvalid => sf_valid, s_axis_tready => sf_ready,
            s_axis_tlast => sf_last, s_axis_tuser => sf_user,
            m_axis_tdata => rl_data, m_axis_tvalid => rl_valid, m_axis_tready => rl_ready,
            m_axis_tlast => rl_last, m_axis_tuser => rl_user
        );

    stats: entity work.axis_byte_stat_counter
        port map (
            clk => clk, rst => rst, clear => '0',
            s_axis_tdata => rl_data, s_axis_tvalid => rl_valid, s_axis_tready => rl_ready,
            s_axis_tlast => rl_last, s_axis_tuser => rl_user,
            m_axis_tdata => out_data, m_axis_tvalid => out_valid, m_axis_tready => out_ready,
            m_axis_tlast => out_last, m_axis_tuser => out_user,
            byte_count => byte_count, frame_count => frame_count, bad_frame_count => bad_count
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        for i in 0 to 2 loop
            s_data <= std_logic_vector(to_unsigned(16#30# + i, 8));
            s_valid <= '1';
            if i = 2 then
                s_last <= '1';
                s_user <= '1';
            else
                s_last <= '0';
                s_user <= '0';
            end if;
            loop
                wait until rising_edge(clk);
                exit when s_ready = '1';
            end loop;
        end loop;
        s_valid <= '0';
        s_last <= '0';
        s_user <= '0';

        for i in 0 to 100 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "axis service chain timed out" severity failure;
        assert byte_count = x"00000003" report "byte counter mismatch" severity failure;
        assert frame_count = x"00000001" report "frame counter mismatch" severity failure;
        assert bad_count = x"00000001" report "bad frame counter mismatch" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
        variable last_cycle : natural := 0;
        variable cycles : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                cycles := 0;
                last_cycle := 0;
                done <= false;
            else
                cycles := cycles + 1;
                if out_valid = '1' and out_ready = '1' then
                    assert out_data = std_logic_vector(to_unsigned(16#30# + pos, 8))
                        report "axis service data mismatch" severity failure;
                    if pos > 0 then
                        assert cycles > last_cycle report "rate limiter did not advance time" severity failure;
                    end if;
                    last_cycle := cycles;
                    if out_last = '1' then
                        assert pos = 2 report "axis service frame length mismatch" severity failure;
                        assert out_user = '1' report "axis service user flag mismatch" severity failure;
                        done <= true;
                    end if;
                    pos := pos + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
