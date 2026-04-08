-- =============================================================
-- keccak_buffer (FIXED VERSION)
-- rate_type => "00": SHA3-256   (rate = 1088 bits = 17 words)
-- rate_type => "01": SHA3-512   (rate =  576 bits =  9 words)
-- rate_type => "10": SHAKE128   (rate = 1344 bits = 21 words)
-- rate_type => "11": SHAKE256   (rate = 1088 bits = 17 words)
-- =============================================================

library work;
use work.keccak_globals.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity keccak_buffer is
  port (
    clk                     : in  std_logic;
    rst_n                   : in  std_logic;
    rate_type               : in  std_logic_vector(1 downto 0);
    din_buffer_in           : in  std_logic_vector(63 downto 0);
    din_buffer_in_valid     : in  std_logic;
    last_block              : in  std_logic;
    din_buffer_full_temp    : out std_logic;
    din_buffer_out          : out std_logic_vector(1343 downto 0);
    dout_buffer_in          : in  std_logic_vector(1343 downto 0);
    dout_buffer_out         : out std_logic_vector(63 downto 0);
    dout_buffer_out_valid   : out std_logic;
    ready                   : in  std_logic
  );
end keccak_buffer;

architecture rtl of keccak_buffer is

  -- mode=0: absorb (input); mode=1: squeeze (output)
  signal mode, buffer_full : std_logic;
  signal count_in_words    : unsigned(5 downto 0);  -- enough for up to 21
  signal buffer_data       : std_logic_vector(1343 downto 0);

  -- Helper signals for different modes
  signal is_sha3_256   : std_logic;
  signal is_sha3_512   : std_logic;
  signal is_shake128   : std_logic;
  signal is_shake256   : std_logic;

begin

  -- *** FIXED: Proper mode detection ***
  is_sha3_256  <= '1' when (rate_type = "00") else '0';
  is_sha3_512  <= '1' when (rate_type = "01") else '0';
  is_shake128  <= '1' when (rate_type = "10") else '0';
  is_shake256  <= '1' when (rate_type = "11") else '0';

  p_main : process (clk, rst_n)
    variable count_out_words : integer range 0 to 31;
  begin
    if rst_n = '0' then
      buffer_data           <= (others => '0');
      count_in_words        <= (others => '0');
      count_out_words       := 0;
      buffer_full           <= '0';
      mode                  <= '0';
      dout_buffer_out_valid <= '0';

    elsif rising_edge(clk) then

      -- Switch to output mode when last block signaled and core is ready
      if (last_block = '1') and (ready = '1') then
        mode <= '1';
      end if;

      -- =========================================================
      -- Absorb mode
      -- =========================================================
      if (mode = '0') then

        -- Once downstream is ready, clear full and restart word count
        if (buffer_full = '1') and (ready = '1') then
          buffer_full    <= '0';
          count_in_words <= (others => '0');

        else
          -- Absorb one 64-bit word per valid cycle
          if (din_buffer_in_valid = '1') and (buffer_full = '0') then

            -- *** FIXED: Unified shifting logic for all modes ***
            if (is_shake128 = '1') then
              -- SHAKE128: 21-word window (0..20)
              -- Shift words down, insert new at top
              for i in 0 to 19 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
              buffer_data(1343 downto 1280) <= din_buffer_in; -- word20

              -- Full after 21 words (count 0..20)
              if (count_in_words = 20) then
                buffer_full    <= '1';
                count_in_words <= (others => '0');
              else
                count_in_words <= count_in_words + 1;
              end if;

            elsif (is_sha3_256 = '1') or (is_shake256 = '1') then
              -- SHA3-256 and SHAKE256: Both use 17-word rate
              -- Shift words 0..15 down, insert new at word16
              for i in 0 to 15 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
              buffer_data(1087 downto 1024) <= din_buffer_in; -- word16

              -- Full after 17 words (count 0..16)
              if (count_in_words = 16) then
                buffer_full    <= '1';
                count_in_words <= (others => '0');
              else
                count_in_words <= count_in_words + 1;
              end if;

            elsif (is_sha3_512 = '1') then
              -- SHA3-512: 9-word rate
              -- Shift words 0..7 down, insert new at word8
              for i in 0 to 7 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
              buffer_data(575 downto 512) <= din_buffer_in; -- word8

              -- Full after 9 words (count 0..8)
              if (count_in_words = 8) then
                buffer_full    <= '1';
                count_in_words <= (others => '0');
              else
                count_in_words <= count_in_words + 1;
              end if;

            else
              -- Default case (shouldn't happen, but default to 17-word mode)
              for i in 0 to 15 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
              buffer_data(1087 downto 1024) <= din_buffer_in;
              
              if (count_in_words = 16) then
                buffer_full    <= '1';
                count_in_words <= (others => '0');
              else
                count_in_words <= count_in_words + 1;
              end if;
            end if;

          end if; -- din_valid
        end if;   -- full & ready

      -- =========================================================
      -- Squeeze mode
      -- =========================================================
      else
        dout_buffer_out_valid <= '1';

        if (count_out_words = 0) then
          -- Load the state output into buffer on first squeeze cycle
          buffer_data     <= dout_buffer_in;
          count_out_words := 1;

        else
          -- *** FIXED: Rate-aware output with proper word counts ***
          if (is_shake128 = '1') then
            -- SHAKE128: output 21 words
            if (count_out_words < 21) then
              count_out_words := count_out_words + 1;
              for i in 0 to 19 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
            else
              dout_buffer_out_valid <= '0';
              count_out_words       := 0;
              mode                  <= '0';
            end if;

          elsif (is_sha3_256 = '1') or (is_shake256 = '1') then
            -- SHA3-256 and SHAKE256: output 17 words
            if (count_out_words < 17) then
              count_out_words := count_out_words + 1;
              for i in 0 to 15 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
            else
              dout_buffer_out_valid <= '0';
              count_out_words       := 0;
              mode                  <= '0';
            end if;

          elsif (is_sha3_512 = '1') then
            -- SHA3-512: output 9 words
            if (count_out_words < 9) then
              count_out_words := count_out_words + 1;
              for i in 0 to 7 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
            else
              dout_buffer_out_valid <= '0';
              count_out_words       := 0;
              mode                  <= '0';
            end if;

          else
            -- Default case (shouldn't happen, default to 17-word mode)
            if (count_out_words < 17) then
              count_out_words := count_out_words + 1;
              for i in 0 to 15 loop
                buffer_data(63+(i*64) downto 0+(i*64)) <=
                  buffer_data(127+(i*64) downto 64+(i*64));
              end loop;
            else
              dout_buffer_out_valid <= '0';
              count_out_words       := 0;
              mode                  <= '0';
            end if;
          end if;
        end if;
      end if;

    end if; -- rising edge
  end process;

  -- Outputs
  din_buffer_out       <= buffer_data;
  dout_buffer_out      <= buffer_data(63 downto 0);
  din_buffer_full_temp <= buffer_full;

end rtl;