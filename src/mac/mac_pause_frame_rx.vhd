-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.eth_types_pkg.all;

entity mac_pause_frame_rx is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_axis_tdata     : in  byte_t;
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in  std_logic;
        s_axis_tuser     : in  std_logic;
        m_pause_valid    : out std_logic;
        m_pause_ready    : in  std_logic;
        m_source_mac     : out mac_addr_t;
        m_pause_quanta   : out word16_t;
        error_bad_frame  : out std_logic
    );
end entity;

architecture rtl of mac_pause_frame_rx is
    type byte_array_t is array (0 to 17) of byte_t;
    signal ptr : natural range 0 to 17 := 0;
    signal frame : byte_array_t := (others => (others => '0'));
    signal valid_reg : std_logic := '0';
    signal bad_reg : std_logic := '0';
    signal src_reg : mac_addr_t := (others => '0');
    signal quanta_reg : word16_t := (others => '0');
begin
    s_axis_tready <= '1';
    m_pause_valid <= valid_reg;
    m_source_mac <= src_reg;
    m_pause_quanta <= quanta_reg;
    error_bad_frame <= bad_reg;

    process (clk)
        variable is_pause : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ptr <= 0;
                frame <= (others => (others => '0'));
                valid_reg <= '0';
                bad_reg <= '0';
                src_reg <= (others => '0');
                quanta_reg <= (others => '0');
            else
                bad_reg <= '0';
                if valid_reg = '1' and m_pause_ready = '1' then
                    valid_reg <= '0';
                end if;

                if s_axis_tvalid = '1' then
                    frame(ptr) <= s_axis_tdata;
                    if s_axis_tlast = '1' then
                        is_pause := ptr = 17 and s_axis_tuser = '0' and
                            frame(0) = x"01" and frame(1) = x"80" and frame(2) = x"C2" and
                            frame(3) = x"00" and frame(4) = x"00" and frame(5) = x"01" and
                            frame(12) = x"88" and frame(13) = x"08" and
                            frame(14) = x"00" and frame(15) = x"01";

                        if is_pause then
                            src_reg <= frame(6) & frame(7) & frame(8) & frame(9) & frame(10) & frame(11);
                            quanta_reg <= frame(16) & s_axis_tdata;
                            valid_reg <= '1';
                        else
                            bad_reg <= '1';
                        end if;
                        ptr <= 0;
                    elsif ptr = 17 then
                        bad_reg <= '1';
                        ptr <= 0;
                    else
                        ptr <= ptr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
