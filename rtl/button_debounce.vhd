library ieee;
use ieee.std_logic_1164.all;

entity button_debounce is
  generic (STABLE_CYCLES : positive := 500_000);
  port (
    clk, rst : in std_logic;
    button_in : in std_logic;
    press_pulse : out std_logic
  );
end entity;

architecture rtl of button_debounce is
  signal button_meta, button_sync : std_logic := '0';
  signal debounced : std_logic := '0';
  signal count : natural range 0 to STABLE_CYCLES-1 := 0;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        button_meta <= '0';
        button_sync <= '0';
        debounced <= '0';
        count <= 0;
        press_pulse <= '0';
      else
        -- Only the second synchronizer stage feeds the debounce logic.
        button_meta <= button_in;
        button_sync <= button_meta;
        press_pulse <= '0';

        if button_sync = debounced then
          count <= 0;
        elsif count = STABLE_CYCLES-1 then
          -- Accept a change after N consecutive opposite-state samples.
          debounced <= button_sync;
          count <= 0;
          if button_sync = '1' then
            press_pulse <= '1';
          end if;
        else
          count <= count + 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
