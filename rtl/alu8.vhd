library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu8 is
  port (
    a, b : in std_logic_vector(7 downto 0);
    op : in std_logic_vector(1 downto 0);
    result : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of alu8 is
begin
  process(all)
  begin
    case op is
      when "00" => result <= std_logic_vector(unsigned(a) + unsigned(b));
      when "01" => result <= std_logic_vector(unsigned(a) - unsigned(b));
      when "10" => result <= a and b;
      when "11" => result <= a or b;
      when others => result <= (others => '0');
    end case;
  end process;
end architecture;
