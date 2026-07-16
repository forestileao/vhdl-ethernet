-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_udp_checksum_lfsr is
end entity;

architecture sim of tb_udp_checksum_lfsr is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal load_lfsr : std_logic := '0';
    signal enable_lfsr : std_logic := '0';
    signal lfsr_value : std_logic_vector(7 downto 0);

    signal hdr_valid : std_logic := '0';
    signal hdr_ready : std_logic;
    signal in_data : byte_t := (others => '0');
    signal in_valid : std_logic := '0';
    signal in_ready : std_logic;
    signal in_last : std_logic := '0';
    signal out_data : byte_t;
    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';
    signal out_last : std_logic;
    signal checksum : word16_t;
    signal checksum_valid : std_logic;
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns;

    lfsr: entity work.prbs_lfsr
        generic map (
            WIDTH => 8,
            TAP_MASK => x"1D"
        )
        port map (
            clk => clk,
            rst => rst,
            enable => enable_lfsr,
            seed => x"A5",
            load => load_lfsr,
            value => lfsr_value
        );

    checksum_dut: entity work.udp_checksum_gen
        port map (
            clk => clk,
            rst => rst,
            s_hdr_valid => hdr_valid,
            s_hdr_ready => hdr_ready,
            s_source_ip => x"C0A8010A",
            s_target_ip => x"C0A80114",
            s_source_port => x"1234",
            s_target_port => x"5678",
            s_payload_length => x"0003",
            s_axis_payload_tdata => in_data,
            s_axis_payload_tvalid => in_valid,
            s_axis_payload_tready => in_ready,
            s_axis_payload_tlast => in_last,
            s_axis_payload_tuser => '0',
            m_axis_payload_tdata => out_data,
            m_axis_payload_tvalid => out_valid,
            m_axis_payload_tready => out_ready,
            m_axis_payload_tlast => out_last,
            m_axis_payload_tuser => open,
            m_checksum => checksum,
            m_checksum_valid => checksum_valid,
            m_checksum_ready => '1'
        );

    stimulus: process
    begin
        wait for 40 ns;
        rst <= '0';
        wait until rising_edge(clk);

        load_lfsr <= '1';
        wait until rising_edge(clk);
        load_lfsr <= '0';
        wait for 1 ns;
        assert lfsr_value = x"A5" report "lfsr load mismatch" severity failure;

        enable_lfsr <= '1';
        wait until rising_edge(clk);
        enable_lfsr <= '0';
        wait for 1 ns;
        assert lfsr_value = x"57" report "lfsr step mismatch" severity failure;

        hdr_valid <= '1';
        loop
            wait until rising_edge(clk);
            exit when hdr_ready = '1';
        end loop;
        hdr_valid <= '0';

        for i in 0 to 2 loop
            in_data <= std_logic_vector(to_unsigned(16#61# + i, 8));
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
        in_last <= '0';

        for i in 0 to 40 loop
            wait until rising_edge(clk);
            exit when done;
        end loop;

        assert done report "udp checksum result timed out" severity failure;
        assert checksum = x"4F5A" report "udp checksum mismatch" severity failure;
        finish;
    end process;

    scoreboard: process (clk)
        variable pos : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pos := 0;
                done <= false;
            else
                if out_valid = '1' and out_ready = '1' then
                    assert out_data = std_logic_vector(to_unsigned(16#61# + pos, 8))
                        report "checksum payload pass-through mismatch" severity failure;
                    if out_last = '1' then
                        assert pos = 2 report "checksum payload length mismatch" severity failure;
                    end if;
                    pos := pos + 1;
                end if;

                if checksum_valid = '1' then
                    done <= true;
                end if;
            end if;
        end if;
    end process;
end architecture;
