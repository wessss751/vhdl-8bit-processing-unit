library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system_top is
  generic (
    FIFO_DEPTH : positive := 4;
    BUTTON_STABLE_CYCLES : positive := 500_000
  );
  port (
    clk, rst : in std_logic;
    read_en : in std_logic := '0';
    read_button : in std_logic := '0';
    button_read_pulse : out std_logic;
    read_data : out std_logic_vector(7 downto 0);
    read_valid, fifo_full, fifo_empty : out std_logic;
    fifo_level : out natural range 0 to FIFO_DEPTH;
    source_valid, source_ready : out std_logic;
    source_a, source_b : out std_logic_vector(7 downto 0);
    source_op : out std_logic_vector(1 downto 0);
    result_pending : out std_logic;
    result_data : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of system_top is
  signal a_reg, b_reg, alu_result : std_logic_vector(7 downto 0);
  signal op_reg : std_logic_vector(1 downto 0);
  signal input_enable, output_enable, fifo_write : std_logic;
  signal fifo_read : std_logic;
begin
  button : entity work.button_debounce
    generic map (STABLE_CYCLES => BUTTON_STABLE_CYCLES)
    port map (clk => clk, rst => rst, button_in => read_button,
              press_pulse => button_read_pulse);

  -- Coincident automatic and button requests produce one read, not two.
  fifo_read <= read_en or button_read_pulse;

  generator : entity work.data_generator
    port map (clk => clk, rst => rst, ready => source_ready,
              valid => source_valid, a => source_a, b => source_b, op => source_op);

  inputs : entity work.input_register
    port map (clk => clk, rst => rst, enable => input_enable,
              a_in => source_a, b_in => source_b, op_in => source_op,
              a_out => a_reg, b_out => b_reg, op_out => op_reg);

  alu : entity work.alu8
    port map (a => a_reg, b => b_reg, op => op_reg, result => alu_result);

  output_reg : entity work.output_register
    port map (clk => clk, rst => rst, enable => output_enable,
              data_in => alu_result, data_out => result_data);

  fifo : entity work.fifo_sync
    generic map (DATA_WIDTH => 8, DEPTH => FIFO_DEPTH)
    port map (clk => clk, rst => rst, write_en => fifo_write,
              write_data => result_data, read_en => fifo_read,
              read_data => read_data, read_valid => read_valid,
              full => fifo_full, empty => fifo_empty, level => fifo_level);

  controller : entity work.control_fsm
    port map (clk => clk, rst => rst, source_valid => source_valid,
              fifo_full => fifo_full, source_ready => source_ready,
              input_enable => input_enable, output_enable => output_enable,
              fifo_write => fifo_write, result_pending => result_pending);
end architecture;
