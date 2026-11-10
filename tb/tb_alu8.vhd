library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_alu8 is
end entity;

architecture test of tb_alu8 is
  signal a, b, result : std_logic_vector(7 downto 0);
  signal op : std_logic_vector(1 downto 0);

  -- Integer arithmetic and per-bit integer logic avoid repeating DUT operators.
  function reference(a_int, b_int, operation : natural) return natural is
    variable value, bit_a, bit_b : natural := 0;
  begin
    if operation = 0 then
      return (a_int + b_int) mod 256;
    elsif operation = 1 then
      return (integer(a_int) - integer(b_int)) mod 256;
    end if;
    for bit_index in 0 to 7 loop
      bit_a := (a_int / (2**bit_index)) mod 2;
      bit_b := (b_int / (2**bit_index)) mod 2;
      if (operation = 2 and bit_a + bit_b = 2) or
         (operation = 3 and bit_a + bit_b > 0) then
        value := value + 2**bit_index;
      end if;
    end loop;
    return value;
  end function;
begin
  dut : entity work.alu8
    port map (a => a, b => b, op => op, result => result);

  process
    variable expected : natural;
  begin
    for operation in 0 to 3 loop
      for a_int in 0 to 255 loop
        for b_int in 0 to 255 loop
          a <= std_logic_vector(to_unsigned(a_int, 8));
          b <= std_logic_vector(to_unsigned(b_int, 8));
          op <= std_logic_vector(to_unsigned(operation, 2));
          expected := reference(a_int, b_int, operation);
          wait for 1 ns;
          assert result = std_logic_vector(to_unsigned(expected, 8))
            report "ALU mismatch: op=" & integer'image(operation) &
                   " A=" & integer'image(a_int) & " B=" & integer'image(b_int) &
                   " expected=" & integer'image(expected) & " got=" & to_hstring(result)
            severity failure;
        end loop;
      end loop;
    end loop;
    report "PASS tb_alu8: 262144 exhaustive input/operation combinations";
    finish;
  end process;
end architecture;
