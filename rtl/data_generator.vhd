library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_generator is
  port (
    clk, rst : in std_logic;
    ready : in std_logic;
    valid : out std_logic;
    a, b : out std_logic_vector(7 downto 0);
    op : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of data_generator is
  signal a_reg : unsigned(7 downto 0) := (others => '0');
  signal b_reg : unsigned(7 downto 0) := (others => '1');
  signal op_reg : unsigned(1 downto 0) := (others => '0');
begin
  valid <= not rst;
  a <= std_logic_vector(a_reg);
  b <= std_logic_vector(b_reg);
  op <= std_logic_vector(op_reg);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        a_reg <= (others => '0');
        b_reg <= (others => '1');
        op_reg <= (others => '0');
      elsif ready = '1' then
        a_reg <= a_reg + 1;
        b_reg <= b_reg + 3;
        op_reg <= op_reg + 1;
      end if;
    end if;
  end process;
end architecture;
