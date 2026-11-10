library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity input_register is
  port (
    clk, rst, enable : in std_logic;
    a_in, b_in : in std_logic_vector(7 downto 0);
    op_in : in std_logic_vector(1 downto 0);
    a_out, b_out : out std_logic_vector(7 downto 0);
    op_out : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of input_register is
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        a_out <= (others => '0');
        b_out <= (others => '0');
        op_out <= (others => '0');
      elsif enable = '1' then
        a_out <= a_in;
        b_out <= b_in;
        op_out <= op_in;
      end if;
    end if;
  end process;
end architecture;
