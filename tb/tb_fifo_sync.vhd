library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_fifo_sync is
  generic (DEPTH : positive := 4);
end entity;

architecture test of tb_fifo_sync is
  signal clk : std_logic := '0';
  signal rst, write_en, read_en : std_logic := '0';
  signal write_data, read_data : std_logic_vector(7 downto 0) := (others => '0');
  signal read_valid, full, empty : std_logic;
  signal level : natural range 0 to DEPTH;
begin
  clk <= not clk after 5 ns;
  dut : entity work.fifo_sync
    generic map (DATA_WIDTH => 8, DEPTH => DEPTH)
    port map (clk => clk, rst => rst, write_en => write_en,
              write_data => write_data, read_en => read_en, read_data => read_data,
              read_valid => read_valid, full => full, empty => empty, level => level);

  process
    -- Shift queue reference deliberately has no wrapping pointers.
    type queue_t is array (0 to DEPTH-1) of natural;
    variable queue : queue_t := (others => 0);
    variable count, reads, writes, simultaneous : natural := 0;
    variable rejected_reads, rejected_writes : natural := 0;
    variable held_data : natural := 0;
    variable prng : unsigned(31 downto 0) := x"8A53C19F";

    procedure step(w, r : std_logic; data : natural; reset_now : boolean := false) is
      variable accept_w, accept_r : boolean;
      variable expected_valid : std_logic := '0';
    begin
      wait until falling_edge(clk);
      write_en <= w;
      read_en <= r;
      write_data <= std_logic_vector(to_unsigned(data mod 256, 8));
      if reset_now then rst <= '1'; else rst <= '0'; end if;
      wait until rising_edge(clk);
      if reset_now then
        count := 0;
        held_data := 0;
      else
        accept_w := w = '1' and count < DEPTH;
        accept_r := r = '1' and count > 0;
        if w = '1' and not accept_w then rejected_writes := rejected_writes + 1; end if;
        if r = '1' and not accept_r then rejected_reads := rejected_reads + 1; end if;
        if accept_w and accept_r then simultaneous := simultaneous + 1; end if;
        if accept_r then
          held_data := queue(0);
          for i in 0 to DEPTH-2 loop
            queue(i) := queue(i+1);
          end loop;
          count := count - 1;
          expected_valid := '1';
          reads := reads + 1;
        end if;
        if accept_w then
          queue(count) := data mod 256;
          count := count + 1;
          writes := writes + 1;
        end if;
      end if;
      wait for 1 ns;
      assert level = count report "FIFO level mismatch" severity failure;
      assert (full = '1') = (count = DEPTH) report "FIFO full mismatch" severity failure;
      assert (empty = '1') = (count = 0) report "FIFO empty mismatch" severity failure;
      assert read_valid = expected_valid report "FIFO read_valid mismatch" severity failure;
      assert read_data = std_logic_vector(to_unsigned(held_data, 8))
        report "FIFO ordering/held-data mismatch: expected=" & integer'image(held_data) &
               " got=" & to_hstring(read_data) severity failure;
    end procedure;
  begin
    step('1', '1', 99, true);
    step('0', '1', 0); -- Underflow must not produce a response.
    step('1', '1', 17); -- Empty: write only, no bypass.
    for i in 1 to DEPTH-1 loop step('1', '0', i+17); end loop;
    step('1', '0', 250); -- Overflow rejected.
    step('1', '1', 251); -- Full: only the read succeeds.
    for i in 1 to DEPTH loop step('0', '1', 0); end loop;
    for i in 0 to 12*DEPTH loop
      step('1', '0', i);
      step('1', '1', i+61);
      step('0', '1', 0);
    end loop;
    -- Reset with pending data and requests; old memory must remain inaccessible.
    step('1', '0', 123);
    step('1', '1', 222, true);
    step('0', '1', 0);
    for i in 0 to 1999 loop
      prng := prng(30 downto 0) & (prng(31) xor prng(21) xor prng(1) xor prng(0));
      step(prng(0), prng(3), to_integer(prng(15 downto 8)));
    end loop;
    for i in 1 to DEPTH+1 loop step('0', '1', 0); end loop;
    assert reads > 10*DEPTH and writes > 10*DEPTH
      report "Insufficient wraparound exercise" severity failure;
    assert rejected_reads > 0 and rejected_writes > 0
      report "Missing boundary rejection tests" severity failure;
    assert DEPTH = 1 or simultaneous > 0
      report "Missing accepted simultaneous read/write" severity failure;
    report "PASS tb_fifo_sync: depth=" & integer'image(DEPTH) &
           " reads=" & integer'image(reads) & " writes=" & integer'image(writes);
    finish;
  end process;
end architecture;
