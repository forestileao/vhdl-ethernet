-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity axis_byte_ram_switch2 is
    generic (
        FIFO_DEPTH : positive := 32
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        s0_dest        : in  std_logic;
        s0_axis_tdata  : in  byte_t;
        s0_axis_tvalid : in  std_logic;
        s0_axis_tready : out std_logic;
        s0_axis_tlast  : in  std_logic;
        s0_axis_tuser  : in  std_logic;
        s1_dest        : in  std_logic;
        s1_axis_tdata  : in  byte_t;
        s1_axis_tvalid : in  std_logic;
        s1_axis_tready : out std_logic;
        s1_axis_tlast  : in  std_logic;
        s1_axis_tuser  : in  std_logic;
        m0_axis_tdata  : out byte_t;
        m0_axis_tvalid : out std_logic;
        m0_axis_tready : in  std_logic;
        m0_axis_tlast  : out std_logic;
        m0_axis_tuser  : out std_logic;
        m1_axis_tdata  : out byte_t;
        m1_axis_tvalid : out std_logic;
        m1_axis_tready : in  std_logic;
        m1_axis_tlast  : out std_logic;
        m1_axis_tuser  : out std_logic
    );
end entity;

architecture rtl of axis_byte_ram_switch2 is
    signal out0_lock : natural range 0 to 2 := 0;
    signal out1_lock : natural range 0 to 2 := 0;
    signal out0_rr   : std_logic := '0';
    signal out1_rr   : std_logic := '0';

    signal g0_s0 : std_logic;
    signal g0_s1 : std_logic;
    signal g1_s0 : std_logic;
    signal g1_s1 : std_logic;

    signal f0_s_data  : byte_t;
    signal f0_s_valid : std_logic;
    signal f0_s_ready : std_logic;
    signal f0_s_last  : std_logic;
    signal f0_s_user  : std_logic;
    signal f1_s_data  : byte_t;
    signal f1_s_valid : std_logic;
    signal f1_s_ready : std_logic;
    signal f1_s_last  : std_logic;
    signal f1_s_user  : std_logic;
begin
    g0_s0 <= '1' when s0_axis_tvalid = '1' and s0_dest = '0' and
        (out0_lock = 1 or (out0_lock = 0 and (s1_axis_tvalid = '0' or s1_dest = '1' or out0_rr = '0'))) else '0';
    g0_s1 <= '1' when s1_axis_tvalid = '1' and s1_dest = '0' and
        (out0_lock = 2 or (out0_lock = 0 and (s0_axis_tvalid = '0' or s0_dest = '1' or out0_rr = '1'))) else '0';
    g1_s0 <= '1' when s0_axis_tvalid = '1' and s0_dest = '1' and
        (out1_lock = 1 or (out1_lock = 0 and (s1_axis_tvalid = '0' or s1_dest = '0' or out1_rr = '0'))) else '0';
    g1_s1 <= '1' when s1_axis_tvalid = '1' and s1_dest = '1' and
        (out1_lock = 2 or (out1_lock = 0 and (s0_axis_tvalid = '0' or s0_dest = '0' or out1_rr = '1'))) else '0';

    s0_axis_tready <= (g0_s0 and f0_s_ready) or (g1_s0 and f1_s_ready);
    s1_axis_tready <= (g0_s1 and f0_s_ready) or (g1_s1 and f1_s_ready);

    f0_s_valid <= (g0_s0 and s0_axis_tvalid) or (g0_s1 and s1_axis_tvalid);
    f0_s_data  <= s1_axis_tdata when g0_s1 = '1' else s0_axis_tdata;
    f0_s_last  <= s1_axis_tlast when g0_s1 = '1' else s0_axis_tlast;
    f0_s_user  <= s1_axis_tuser when g0_s1 = '1' else s0_axis_tuser;

    f1_s_valid <= (g1_s0 and s0_axis_tvalid) or (g1_s1 and s1_axis_tvalid);
    f1_s_data  <= s1_axis_tdata when g1_s1 = '1' else s0_axis_tdata;
    f1_s_last  <= s1_axis_tlast when g1_s1 = '1' else s0_axis_tlast;
    f1_s_user  <= s1_axis_tuser when g1_s1 = '1' else s0_axis_tuser;

    out0_fifo: entity work.axis_byte_fifo
        generic map (
            DEPTH => FIFO_DEPTH
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => f0_s_data,
            s_axis_tvalid => f0_s_valid,
            s_axis_tready => f0_s_ready,
            s_axis_tlast => f0_s_last,
            s_axis_tuser => f0_s_user,
            m_axis_tdata => m0_axis_tdata,
            m_axis_tvalid => m0_axis_tvalid,
            m_axis_tready => m0_axis_tready,
            m_axis_tlast => m0_axis_tlast,
            m_axis_tuser => m0_axis_tuser
        );

    out1_fifo: entity work.axis_byte_fifo
        generic map (
            DEPTH => FIFO_DEPTH
        )
        port map (
            clk => clk,
            rst => rst,
            s_axis_tdata => f1_s_data,
            s_axis_tvalid => f1_s_valid,
            s_axis_tready => f1_s_ready,
            s_axis_tlast => f1_s_last,
            s_axis_tuser => f1_s_user,
            m_axis_tdata => m1_axis_tdata,
            m_axis_tvalid => m1_axis_tvalid,
            m_axis_tready => m1_axis_tready,
            m_axis_tlast => m1_axis_tlast,
            m_axis_tuser => m1_axis_tuser
        );

    process (clk)
        variable push0 : boolean;
        variable push1 : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out0_lock <= 0;
                out1_lock <= 0;
                out0_rr <= '0';
                out1_rr <= '0';
            else
                push0 := f0_s_valid = '1' and f0_s_ready = '1';
                push1 := f1_s_valid = '1' and f1_s_ready = '1';

                if push0 then
                    if out0_lock = 0 and f0_s_last = '0' then
                        if g0_s0 = '1' then
                            out0_lock <= 1;
                        else
                            out0_lock <= 2;
                        end if;
                    elsif f0_s_last = '1' then
                        out0_lock <= 0;
                        out0_rr <= not out0_rr;
                    end if;
                end if;

                if push1 then
                    if out1_lock = 0 and f1_s_last = '0' then
                        if g1_s0 = '1' then
                            out1_lock <= 1;
                        else
                            out1_lock <= 2;
                        end if;
                    elsif f1_s_last = '1' then
                        out1_lock <= 0;
                        out1_rr <= not out1_rr;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
