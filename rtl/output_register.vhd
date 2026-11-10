library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_register is
  port (
    clk, rst, enable : in std_logic;
    data_in : in std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of output_register is
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        data_out <= (others => '0');
      elsif enable = '1' then
        data_out <= data_in;
      end if;
    end if;
  end process;
end architecture;
