library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_sync is
  generic (
    DATA_WIDTH : positive := 8;
    DEPTH : positive := 4
  );
  port (
    clk, rst : in std_logic;
    write_en : in std_logic;
    write_data : in std_logic_vector(DATA_WIDTH-1 downto 0);
    read_en : in std_logic;
    read_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
    read_valid, full, empty : out std_logic;
    level : out natural range 0 to DEPTH
  );
end entity;

architecture rtl of fifo_sync is
  type memory_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal memory : memory_t;
  signal write_ptr, read_ptr : natural range 0 to DEPTH-1 := 0;
  signal count : natural range 0 to DEPTH := 0;

  function next_ptr(ptr : natural) return natural is
  begin
    if ptr = DEPTH-1 then
      return 0;
    end if;
    return ptr + 1;
  end function;
begin
  full <= '1' when count = DEPTH else '0';
  empty <= '1' when count = 0 else '0';
  level <= count;

  process(clk)
    variable do_write, do_read : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        write_ptr <= 0;
        read_ptr <= 0;
        count <= 0;
        read_data <= (others => '0');
        read_valid <= '0';
      else
        -- Both decisions use the old count: no empty bypass or full replacement.
        do_write := write_en = '1' and count < DEPTH;
        do_read := read_en = '1' and count > 0;
        read_valid <= '0';
        if do_write then
          memory(write_ptr) <= write_data;
          write_ptr <= next_ptr(write_ptr);
        end if;
        if do_read then
          read_data <= memory(read_ptr);
          read_valid <= '1';
          read_ptr <= next_ptr(read_ptr);
        end if;
        if do_write and not do_read then
          count <= count + 1;
        elsif do_read and not do_write then
          count <= count - 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
