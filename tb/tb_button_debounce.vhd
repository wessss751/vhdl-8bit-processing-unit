library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_button_debounce is
  generic (STABLE_CYCLES : positive := 4);
end entity;

architecture test of tb_button_debounce is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal button_in : std_logic := '0';
  signal press_pulse : std_logic;
begin
  clk <= not clk after 5 ns;
  dut : entity work.button_debounce
    generic map (STABLE_CYCLES => STABLE_CYCLES)
    port map (clk => clk, rst => rst, button_in => button_in, press_pulse => press_pulse);

  process
    variable pulses : natural := 0;
    variable previous_pulse : std_logic := '0';

    procedure tick(value : std_logic; expected : std_logic := '0'; reset_now : boolean := false) is
    begin
      wait until falling_edge(clk);
      wait for 1 ns; -- The asynchronous input changes away from clock edges.
      button_in <= value;
      if reset_now then rst <= '1'; else rst <= '0'; end if;
      wait until rising_edge(clk);
      wait for 1 ns;
      assert press_pulse = expected
        report "Button pulse timing mismatch: expected " & std_logic'image(expected) &
               " got " & std_logic'image(press_pulse) severity failure;
      assert not (previous_pulse = '1' and press_pulse = '1')
        report "Button pulse lasted more than one cycle" severity failure;
      if press_pulse = '1' then pulses := pulses + 1; end if;
      previous_pulse := press_pulse;
    end procedure;

    procedure hold(value : std_logic; cycles : natural) is
    begin
      for i in 1 to cycles loop tick(value); end loop;
    end procedure;

    procedure press is
    begin
      -- Two synchronizer edges, then exactly N qualifying samples.
      hold('1', STABLE_CYCLES+1);
      tick('1', '1');
    end procedure;
  begin
    tick('0', reset_now => true);
    hold('0', 3);

    if STABLE_CYCLES > 1 then
      -- Just below the threshold: do not accept a press.
      hold('1', STABLE_CYCLES-1);
      hold('0', STABLE_CYCLES+2);
      -- Several bounces must not accumulate towards the threshold.
      for bounce in 1 to 3 loop
        hold('1', STABLE_CYCLES-1);
        hold('0', 1);
      end loop;
      hold('0', STABLE_CYCLES+2);
    end if;

    press;
    hold('1', 3*STABLE_CYCLES+4); -- Long press: no repeated pulses.
    if STABLE_CYCLES > 1 then
      for bounce in 1 to 3 loop
        hold('0', STABLE_CYCLES-1); -- Release bounce must not rearm.
        hold('1', 1);
      end loop;
      hold('1', STABLE_CYCLES+2);
    end if;
    hold('0', STABLE_CYCLES+2); -- A stable release rearms the button.
    press;

    -- Reset while the pulse is asserted. A button still held after reset is
    -- treated as a fresh press, after synchronization and qualification again.
    tick('1', reset_now => true);
    press;
    hold('1', 3);
    hold('0', STABLE_CYCLES+2);

    -- Cancel a partially qualified press with reset.
    hold('1', STABLE_CYCLES+1);
    tick('0', reset_now => true);
    hold('0', STABLE_CYCLES+3);

    -- An exact-threshold high interval must produce one pulse even though
    -- the raw button has already fallen when that interval finishes filtering.
    hold('1', STABLE_CYCLES);
    tick('0');
    tick('0', '1');
    hold('0', STABLE_CYCLES+2);
    press;
    hold('1', 3);

    assert pulses = 5 report "Unexpected total number of button pulses" severity failure;
    report "PASS tb_button_debounce: stable cycles=" & integer'image(STABLE_CYCLES) &
           " checked pulses=" & integer'image(pulses);
    finish;
  end process;

  process
  begin
    wait for 100 us;
    assert false report "Button test watchdog expired" severity failure;
  end process;
end architecture;
