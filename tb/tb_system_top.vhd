library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_system_top is
end entity;

architecture test of tb_system_top is
  constant DEPTH : positive := 4;
  constant BUTTON_CYCLES : positive := 4;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal read_en : std_logic := '0';
  signal read_button : std_logic := '0';
  signal button_read_pulse : std_logic;
  signal read_data, source_a, source_b, result_data : std_logic_vector(7 downto 0);
  signal source_op : std_logic_vector(1 downto 0);
  signal read_valid, fifo_full, fifo_empty : std_logic;
  signal source_valid, source_ready, result_pending : std_logic;
  signal fifo_level : natural range 0 to DEPTH;

  function reference(n : natural) return natural is
    variable a, b, op, value, bit_a, bit_b : natural := 0;
  begin
    a := n mod 256;
    b := (255 + 3*n) mod 256;
    op := n mod 4;
    case op is
      when 0 => return (a + b) mod 256;
      when 1 => return (integer(a) - integer(b)) mod 256;
      when others =>
        for i in 0 to 7 loop
          bit_a := (a / 2**i) mod 2;
          bit_b := (b / 2**i) mod 2;
          if (op = 2 and bit_a + bit_b = 2) or
             (op = 3 and bit_a + bit_b > 0) then
            value := value + 2**i;
          end if;
        end loop;
        return value;
    end case;
  end function;
begin
  clk <= not clk after 5 ns;
  dut : entity work.system_top
    generic map (FIFO_DEPTH => DEPTH, BUTTON_STABLE_CYCLES => BUTTON_CYCLES)
    port map (clk => clk, rst => rst, read_en => read_en,
              read_button => read_button, button_read_pulse => button_read_pulse,
              read_data => read_data, read_valid => read_valid,
              fifo_full => fifo_full, fifo_empty => fifo_empty, fifo_level => fifo_level,
              source_valid => source_valid, source_ready => source_ready,
              source_a => source_a, source_b => source_b, source_op => source_op,
              result_pending => result_pending, result_data => result_data);

  process
    type queue_t is array (0 to 4095) of natural;
    variable expected : queue_t;
    variable accepted, consumed, total_accepted, total_consumed : natural := 0;
    variable discarded, full_stalls : natural := 0;
    variable reads_before : natural;
    variable last_read : std_logic_vector(7 downto 0) := (others => '0');
    variable prng : unsigned(31 downto 0) := x"8A53C19F";

    procedure tick(consume : std_logic; reset_now : boolean := false;
                   button_value : std_logic := '0') is
      variable old_a, old_b, old_result : std_logic_vector(7 downto 0);
      variable old_op : std_logic_vector(1 downto 0);
      variable stalled_source, stalled_result, expect_read : boolean;
      variable expected_level : natural;
    begin
      wait until falling_edge(clk);
      read_en <= consume;
      read_button <= button_value;
      if reset_now then rst <= '1'; else rst <= '0'; end if;
      wait until rising_edge(clk);
      old_a := source_a;
      old_b := source_b;
      old_op := source_op;
      old_result := result_data;
      stalled_source := source_valid = '1' and source_ready = '0';
      stalled_result := result_pending = '1' and fifo_full = '1';
      expected_level := fifo_level;
      expect_read := (consume = '1' or button_read_pulse = '1') and fifo_empty = '0';
      if reset_now then
        discarded := discarded + accepted - consumed;
        accepted := 0;
        consumed := 0;
        last_read := (others => '0');
        expected_level := 0;
        expect_read := false;
      else
        if source_valid = '1' and source_ready = '1' then
          assert source_a = std_logic_vector(to_unsigned(accepted mod 256, 8)) and
                 source_b = std_logic_vector(to_unsigned((255+3*accepted) mod 256, 8)) and
                 source_op = std_logic_vector(to_unsigned(accepted mod 4, 2))
            report "Generator sequence mismatch at transaction " & integer'image(accepted)
            severity failure;
          expected(accepted) := reference(accepted);
          accepted := accepted + 1;
          total_accepted := total_accepted + 1;
        end if;
        if result_pending = '1' and fifo_full = '0' then
          expected_level := expected_level + 1;
        end if;
        if expect_read then expected_level := expected_level - 1; end if;
        if stalled_result then full_stalls := full_stalls + 1; end if;
      end if;
      -- Observe registered outputs after delta cycles have settled.
      wait for 1 ns;
      assert fifo_level = expected_level report "System FIFO transfer/level mismatch" severity failure;
      assert (fifo_full = '1') = (fifo_level = DEPTH) and
             (fifo_empty = '1') = (fifo_level = 0)
        report "System FIFO status mismatch" severity failure;
      assert (read_valid = '1') = expect_read report "Unexpected/missing read response" severity failure;
      if expect_read then
        assert consumed < accepted report "Duplicated or unsolicited result" severity failure;
        assert to_integer(unsigned(read_data)) = expected(consumed)
          report "Result mismatch at transaction " & integer'image(consumed) &
                 " expected=" & integer'image(expected(consumed)) &
                 " got=" & to_hstring(read_data) severity failure;
        last_read := read_data;
        consumed := consumed + 1;
        total_consumed := total_consumed + 1;
      end if;
      assert read_data = last_read report "Read data changed without a response" severity failure;
      if reset_now then
        assert fifo_empty = '1' and button_read_pulse = '0' and
               result_pending = '0' and result_data = x"00" and
               source_a = x"00" and source_b = x"FF" and source_op = "00"
          report "Reset did not clear pending state/restart generator" severity failure;
      else
        assert accepted - consumed >= fifo_level and accepted - consumed <= fifo_level+1
          report "Lost/duplicated transaction or more than one transaction in flight" severity failure;
        if result_pending = '1' then
          assert accepted-consumed = fifo_level+1
            report "Pending result has no corresponding accepted transaction" severity failure;
          assert to_integer(unsigned(result_data)) = expected(consumed+fifo_level)
            report "Output register contains the wrong pending result" severity failure;
        end if;
        if stalled_source then
          assert source_valid = '1' and source_a = old_a and source_b = old_b and source_op = old_op
            report "Source changed while stalled" severity failure;
        end if;
        if stalled_result then
          assert result_pending = '1' and result_data = old_result
            report "Pending result changed while FIFO was full" severity failure;
        end if;
      end if;
    end procedure;

    procedure hold_button(value : std_logic; cycles : positive) is
    begin
      for i in 1 to cycles loop tick('0', button_value => value); end loop;
    end procedure;
  begin
    tick('0', true);
    tick('1', true); -- Reset wins over read requests.
    for epoch in 0 to 1 loop
      for i in 1 to 45 loop tick('0'); end loop;
      assert fifo_full = '1' and result_pending = '1' and accepted-consumed = DEPTH+1
        report "Consumer pause did not fill FIFO and stall pending result" severity failure;
      for i in 0 to 1699 loop
        prng := prng(30 downto 0) & (prng(31) xor prng(21) xor prng(1) xor prng(0));
        -- Repeated long pauses plus irregular and continuous reads.
        if i mod 160 < 35 then tick('0');
        elsif i mod 160 > 115 then tick('1');
        else tick(prng(0)); end if;
      end loop;
      for i in 1 to 100 loop tick('1'); end loop;
      assert accepted > 256 and consumed > 256
        report "Insufficient transactions for generator and FIFO wraparound" severity failure;
      assert accepted-consumed <= 2 report "Consumer did not catch up after resuming" severity failure;
      for i in 1 to 45 loop tick('0'); end loop;
      assert fifo_full = '1' and result_pending = '1'
        report "Reset scenario has no pending result" severity failure;
      tick('1', true); -- Discard full FIFO plus one pending result, then restart.
      tick('0', true);
    end loop;
    assert full_stalls > 100 report "Insufficient backpressure exercise" severity failure;
    assert discarded = 2*(DEPTH+1) report "Unexpected reset discard count" severity failure;
    assert total_accepted = total_consumed + discarded
      report "Final transaction accounting mismatch" severity failure;
    report "PASS tb_system_top: accepted=" & integer'image(total_accepted) &
           " checked results=" & integer'image(total_consumed) &
           " intentionally discarded by reset=" & integer'image(discarded) &
           " full stall cycles=" & integer'image(full_stalls);

    -- Start with a full FIFO. Each bounced/held press must read exactly one
    -- result; the existing scoreboard still checks every value and transfer.
    hold_button('0', 45);
    for press_index in 1 to 4 loop
      reads_before := consumed;
      for bounce in 1 to 3 loop
        hold_button('1', 1);
        hold_button('0', 1);
      end loop;
      hold_button('0', BUTTON_CYCLES+2);
      assert consumed = reads_before report "Press bounce caused a read" severity failure;
      hold_button('1', BUTTON_CYCLES+3);
      assert consumed = reads_before+1 report "Button did not read exactly one result" severity failure;
      hold_button('1', 20);
      for bounce in 1 to 3 loop
        hold_button('0', 1);
        hold_button('1', 1);
      end loop;
      hold_button('1', BUTTON_CYCLES+3);
      assert consumed = reads_before+1 report "Held button/release bounce repeated a read" severity failure;
      hold_button('0', BUTTON_CYCLES+3);
    end loop;
    assert consumed = 4 report "Four presses did not read four results" severity failure;

    -- If both interfaces request on the same edge, perform only one read.
    hold_button('1', BUTTON_CYCLES+2);
    assert button_read_pulse = '1' report "Missing button pulse for coincident request" severity failure;
    reads_before := consumed;
    tick('1', button_value => '1');
    hold_button('1', 10);
    assert consumed = reads_before+1 report "Coincident requests duplicated a read" severity failure;
    hold_button('0', BUTTON_CYCLES+3);

    -- Reset cancels a button pulse that has not yet reached the FIFO.
    hold_button('1', BUTTON_CYCLES+2);
    assert button_read_pulse = '1' report "Missing pulse before reset" severity failure;
    tick('0', reset_now => true);

    -- Drain automatically while qualifying the button. With this stimulus
    -- the button pulse reaches an empty FIFO; it must not be saved for later.
    tick('1');
    for i in 1 to BUTTON_CYCLES+2 loop tick('1', button_value => '1'); end loop;
    assert button_read_pulse = '1' and fifo_empty = '1'
      report "Empty-FIFO button scenario was not reached" severity failure;
    reads_before := consumed;
    hold_button('1', 30);
    assert consumed = reads_before and fifo_full = '1'
      report "Empty-FIFO press was repeated when new results arrived" severity failure;
    hold_button('0', BUTTON_CYCLES+3);
    hold_button('1', BUTTON_CYCLES+3);
    assert consumed = reads_before+1 report "Button failed after empty-FIFO press" severity failure;
    tick('0', reset_now => true);
    assert total_accepted = total_consumed + discarded
      report "Final button test transaction accounting mismatch" severity failure;
    report "PASS tb_system_top button: bounce, hold, rearm, FIFO ordering, coincident requests, empty FIFO and reset";
    finish;
  end process;

  process
  begin
    wait for 100 us;
    assert false report "System test watchdog expired" severity failure;
  end process;
end architecture;
