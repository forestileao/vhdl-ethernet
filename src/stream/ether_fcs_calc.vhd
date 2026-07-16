-- SPDX-License-Identifier: MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eth_types_pkg.all;

entity axis_eth_fcs is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        s_axis_tdata     : in  byte_t;
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in  std_logic;
        s_axis_tuser     : in  std_logic;
        output_fcs       : out std_logic_vector(31 downto 0);
        output_fcs_valid : out std_logic
    );
end entity;

architecture rtl of axis_eth_fcs is
    signal crc_reg       : std_logic_vector(31 downto 0) := (others => '1');
    signal fcs_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal fcs_valid_reg : std_logic := '0';
begin
    s_axis_tready    <= '1';
    output_fcs       <= fcs_reg;
    output_fcs_valid <= fcs_valid_reg;

    process (clk)
        variable cnext : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                crc_reg       <= (others => '1');
                fcs_reg       <= (others => '0');
                fcs_valid_reg <= '0';
            else
                fcs_valid_reg <= '0';

                if s_axis_tvalid = '1' then
                    cnext   := crc32_next(crc_reg, s_axis_tdata);
                    crc_reg <= cnext;

                    if s_axis_tlast = '1' then
                        fcs_reg       <= not cnext;
                        fcs_valid_reg <= not s_axis_tuser;
                        crc_reg       <= (others => '1');
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
