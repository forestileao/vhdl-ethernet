-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.eth_types_pkg.all;

entity tb_axis_async_fifo is
end entity;

architecture sim of tb_axis_async_fifo is
    signal s_clk : std_logic := '0';
    signal m_clk : std_logic := '0';
    signal s_rst : std_logic := '1';
    signal m_rst : std_logic := '1';
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
    signal done : boolean := false;
begin
    s_clk <= not s_clk after 4 ns;
    m_clk <= not m_clk after 7 ns;

    dut: entity work.axis_byte_async_fifo_adapter
        generic map (
            ADDR_WIDTH => 3
        )
        port map (
            s_clk => s_clk,
            s_rst => s_rst,
            s_axis_tdata => s_data,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tlast => s_last,
            s_axis_tuser => s_user,
            m_clk => m_clk,
            m_rst => m_rst,
            m_axis_tdata => m_data,
            m_axis_tvalid => m_valid,
            m_axis_tready => m_ready,
            m_axis_tlast => m_last,
            m_axis_tuser => m_user
        );

    stimulus: process
    begin
        wait for 40 ns;
        s_rst <= '0';
        m_rst <= '0';
        wait until rising_edge(s_clk);

        for i in 0 to 4 loop
            s_data <= std_logic_vector(to_unsigned(16#80# + i, 8));
            s_valid <= '1';
            if i = 4 then
                s_last <= '1';
                s_user <= '1';
            else
                s_last <= '0';
                s_user <= '0';
            end if;
            loop
                wait until rising_edge(s_clk);
                exit when s_ready = '1';
            end loop;
        end loop;
        s_valid <= '0';
        s_last <= '0';
        s_user <= '0';

        for i in 0 to 80 loop
            wait until rising_edge(m_clk);
            exit when done;
        end loop;

        assert done report "async fifo frame timed out" severity failure;
        finish;
    end process;

    scoreboard: process (m_clk)
        variable pos : natural := 0;
    begin
        if rising_edge(m_clk) then
            if m_rst = '1' then
                pos := 0;
                done <= false;
            elsif m_valid = '1' and m_ready = '1' then
                assert m_data = std_logic_vector(to_unsigned(16#80# + pos, 8))
                    report "async fifo data mismatch" severity failure;
                if m_last = '1' then
                    assert pos = 4 report "async fifo length mismatch" severity failure;
                    assert m_user = '1' report "async fifo user mismatch" severity failure;
                    done <= true;
                end if;
                pos := pos + 1;
            end if;
        end if;
    end process;
end architecture;
