library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_fsm is
  port (
    clk, rst : in std_logic;
    source_valid, fifo_full : in std_logic;
    source_ready, input_enable, output_enable : out std_logic;
    fifo_write, result_pending : out std_logic
  );
end entity;

architecture rtl of control_fsm is
  type state_t is (CAPTURE, EXECUTE, STORE);
  signal state : state_t := CAPTURE;
begin
  process(all)
  begin
    source_ready <= '0';
    input_enable <= '0';
    output_enable <= '0';
    fifo_write <= '0';
    result_pending <= '0';
    if rst = '0' then
      case state is
        when CAPTURE =>
          source_ready <= '1';
          input_enable <= source_valid;
        when EXECUTE =>
          output_enable <= '1';
        when STORE =>
          result_pending <= '1';
          fifo_write <= not fifo_full;
      end case;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= CAPTURE;
      else
        case state is
          when CAPTURE =>
            if source_valid = '1' then
              state <= EXECUTE;
            end if;
          when EXECUTE => state <= STORE;
          when STORE =>
            -- The output register holds the result for every stalled cycle.
            if fifo_full = '0' then
              state <= CAPTURE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
