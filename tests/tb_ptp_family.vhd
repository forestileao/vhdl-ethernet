-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_ptp_family is
end entity;

architecture sim of tb_ptp_family is
    constant TS_WIDTH : positive := 16;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal set_valid : std_logic := '0';
    signal set_ts : std_logic_vector(TS_WIDTH - 1 downto 0) := (others => '0');
    signal ts : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal pulse_1pps : std_logic;
    signal per_pulse : std_logic;
    signal cdc_ts : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal cdc_valid : std_logic;
    signal s_data : word64_t := x"00000000000000CC";
    signal s_keep : keep8_t := x"01";
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_last : std_logic := '0';
    signal m_valid : std_logic;
    signal m_last : std_logic;
    signal cap_valid : std_logic;
    signal cap_ts : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal tag_valid : std_logic := '0';
    signal lookup_valid : std_logic := '0';
    signal result_valid : std_logic;
    signal result_match : std_logic;
    signal result_time : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal seconds : std_logic_vector(63 downto 0);
    signal nanoseconds : std_logic_vector(31 downto 0);
    signal extract_valid : std_logic;
    signal extract_ts : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal extract_error : std_logic;
    signal leaf_time : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal leaf_valid : std_logic;
    signal phc_ts : std_logic_vector(TS_WIDTH - 1 downto 0);
    signal phc_valid : std_logic;
begin
    clk <= not clk after 5 ns;

    clock_i: entity work.ptp_clock
        generic map (
            TS_WIDTH => TS_WIDTH,
            INCREMENT_NS => 5,
            PULSE_CYCLES => 4
        )
        port map (
            clk => clk,
            rst => rst,
            set_valid => set_valid,
            set_timestamp => set_ts,
            timestamp => ts,
            pulse_1pps => pulse_1pps
        );

    cdc_i: entity work.ptp_clock_cdc
        generic map (
            TS_WIDTH => TS_WIDTH
        )
        port map (
            src_clk => clk,
            src_rst => rst,
            src_timestamp => ts,
            dst_clk => clk,
            dst_rst => rst,
            dst_timestamp => cdc_ts,
            dst_valid => cdc_valid
        );

    perout_i: entity work.ptp_perout
        generic map (
            TS_WIDTH => TS_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            enable => '1',
            timestamp => ts,
            start_time => x"0078",
            period => x"000A",
            pulse => per_pulse
        );

    capture_i: entity work.ptp_timestamp_capture
        generic map (
            TS_WIDTH => TS_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            timestamp => ts,
            s_axis_tdata => s_data,
            s_axis_tkeep => s_keep,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tlast => s_last,
            s_axis_tuser => '0',
            m_axis_tdata => open,
            m_axis_tkeep => open,
            m_axis_tvalid => m_valid,
            m_axis_tready => '1',
            m_axis_tlast => m_last,
            m_axis_tuser => open,
            ts_valid => cap_valid,
            ts_timestamp => cap_ts
        );

    tags_i: entity work.ptp_tag_tracker
        generic map (
            TS_WIDTH => TS_WIDTH,
            TAG_WIDTH => 8
        )
        port map (
            clk => clk,
            rst => rst,
            tag_valid => tag_valid,
            tag_value => x"5A",
            timestamp => ts,
            lookup_valid => lookup_valid,
            lookup_tag => x"5A",
            result_valid => result_valid,
            result_match => result_match,
            result_time => result_time
        );

    tod_i: entity work.ptp_tod_split
        port map (
            timestamp => x"000000000000012300000456",
            seconds => seconds,
            nanoseconds => nanoseconds
        );

    extract_i: entity work.ptp_ts_extract
        generic map (
            TS_WIDTH => TS_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            timestamp => ts,
            s_axis_tdata => s_data,
            s_axis_tkeep => s_keep,
            s_axis_tvalid => s_valid,
            s_axis_tready => open,
            s_axis_tlast => s_last,
            s_axis_tuser => '0',
            ts_valid => extract_valid,
            ts_timestamp => extract_ts,
            frame_error => extract_error
        );

    leaf_i: entity work.ptp_td_leaf
        generic map (
            TS_WIDTH => TS_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            enable => '1',
            source_time => x"0100",
            path_delay => x"0005",
            leaf_time => leaf_time,
            leaf_valid => leaf_valid
        );

    phc_i: entity work.ptp_td_phc
        generic map (
            TS_WIDTH => TS_WIDTH,
            INCREMENT_NS => 2
        )
        port map (
            clk => clk,
            rst => rst,
            set_valid => set_valid,
            set_timestamp => set_ts,
            correction => x"0001",
            timestamp => phc_ts,
            timestamp_valid => phc_valid
        );

    stimulus: process
        variable saw_pps : boolean := false;
        variable saw_perout : boolean := false;
    begin
        wait for 40 ns;
        rst <= '0';
        set_ts <= x"0064";
        set_valid <= '1';
        wait until rising_edge(clk);
        set_valid <= '0';

        for i in 0 to 12 loop
            wait until rising_edge(clk);
            if pulse_1pps = '1' then
                saw_pps := true;
            end if;
            if per_pulse = '1' then
                saw_perout := true;
            end if;
        end loop;

        assert unsigned(ts) > 100 report "PTP clock did not advance" severity failure;
        assert saw_pps report "PTP clock pulse missing" severity failure;
        assert saw_perout report "PTP periodic output missing" severity failure;
        assert cdc_valid = '1' report "PTP CDC did not become valid" severity failure;
        assert unsigned(cdc_ts) > 0 report "PTP CDC timestamp missing" severity failure;

        s_valid <= '1';
        s_last <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert s_ready = '1' report "PTP capture stream not ready" severity failure;
        assert m_valid = '1' and m_last = '1' report "PTP capture stream pass-through failed" severity failure;
        assert cap_valid = '1' report "PTP capture did not report timestamp" severity failure;
        assert unsigned(cap_ts) > 0 report "PTP capture timestamp missing" severity failure;
        assert extract_valid = '1' report "PTP extractor did not report timestamp" severity failure;
        assert unsigned(extract_ts) > 0 report "PTP extractor timestamp missing" severity failure;
        assert extract_error = '0' report "PTP extractor reported frame error" severity failure;
        s_valid <= '0';
        s_last <= '0';

        tag_valid <= '1';
        wait until rising_edge(clk);
        tag_valid <= '0';
        lookup_valid <= '1';
        wait until rising_edge(clk);
        lookup_valid <= '0';
        wait for 1 ns;
        assert result_valid = '1' report "PTP tag lookup did not respond" severity failure;
        assert result_match = '1' report "PTP tag lookup missed" severity failure;
        assert result_time /= x"0000" report "PTP tag timestamp missing" severity failure;
        assert leaf_valid = '1' report "PTP leaf did not report valid time" severity failure;
        assert leaf_time = x"0105" report "PTP leaf time mismatch" severity failure;
        assert phc_valid = '1' report "PTP PHC did not become valid" severity failure;
        assert unsigned(phc_ts) > 100 report "PTP PHC did not advance" severity failure;

        assert seconds = x"0000000000000123" report "PTP seconds split mismatch" severity failure;
        assert nanoseconds = x"00000456" report "PTP nanoseconds split mismatch" severity failure;
        report "simulation finished" severity note;
        finish;
    end process;
end architecture;
