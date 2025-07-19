library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Top is
     port (
          CLOCK_50 : in  std_logic;
          SW       : in  std_logic_vector(9 downto 0);
          KEY      : in  std_logic_vector(1 downto 0);
          LEDR     : out std_logic_vector(9 downto 0);
          HEX0     : out std_logic_vector(0 to 7);
          HEX1     : out std_logic_vector(0 to 7);
          HEX2     : out std_logic_vector(0 to 7);
          HEX3     : out std_logic_vector(0 to 7);
          HEX4     : out std_logic_vector(0 to 7);
          HEX5     : out std_logic_vector(0 to 7)
     );
end entity Top;

architecture structural of Top is

    component entrada is
         port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            stop        : in  std_logic;
            data        : in  std_logic;
            next_bit    : in  std_logic;
            truth_table : out std_logic_vector(15 downto 0);
            counter     : out std_logic_vector(3 downto 0)
        );
    end component entrada;

    component quine_mccluskey is
         port (
            clk              : in  std_logic;
            reset            : in  std_logic;
            start            : in  std_logic;
            truth_table      : in  std_logic_vector(15 downto 0);
            done             : out std_logic;
            result_terms     : out std_logic_vector(63 downto 0);
            num_result_terms : out std_logic_vector(3 downto 0)
        );
    end component quine_mccluskey;
    
    component display is
         port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            start     : in  std_logic;
            next_char : in  std_logic;
            terms     : in  std_logic_vector(63 downto 0);
            num_terms : in  std_logic_vector(3 downto 0);
            HEX0      : out std_logic_vector(0 to 7)
        );
    end component;
    
    signal s_reset             : std_logic;
    signal s_start             : std_logic;
    signal s_done              : std_logic;
    signal s_truth_table       : std_logic_vector(15 downto 0);
    signal s_result_terms      : std_logic_vector(63 downto 0);
    signal s_qm_num_terms      : std_logic_vector(3 downto 0);
    signal s_current_bit_index : std_logic_vector(3 downto 0);
    signal s_real_busy         : std_logic;

begin
    
    s_reset <= SW(9);
    s_start <= SW(7);
    
    LEDR(9)            <= s_done;
    LEDR(8)            <= s_real_busy;
    LEDR(7 downto 4)   <= (others => '0');
    LEDR(3 downto 0)   <= s_current_bit_index;

    process(CLOCK_50, s_reset)
    begin
        if s_reset = '1' then
            s_real_busy <= '0';
        elsif rising_edge(CLOCK_50) then
            if s_start = '1' then
                s_real_busy <= '1';
            elsif s_done = '1' then
                s_real_busy <= '0';
            end if;
        end if;
    end process;
    
    input_ctrl : entrada
        port map (
            clk         => CLOCK_50,
            reset       => s_reset,
            stop        => s_real_busy,         
            data        => SW(0),              
            next_bit    => not KEY(0),          
            truth_table => s_truth_table,       
            counter     => s_current_bit_index  
        );

    qm_inst : quine_mccluskey
        port map (
            clk              => CLOCK_50,
            reset            => s_reset,
            start            => s_start,
            truth_table      => s_truth_table,
            done             => s_done,
            result_terms     => s_result_terms,
            num_result_terms => s_qm_num_terms
        );

    display_inst : display
        port map (
            clk       => CLOCK_50,
            reset     => s_reset,
            start     => s_done,              
            next_char => not KEY(1),        
            terms     => s_result_terms,      
            num_terms => s_qm_num_terms,      
            HEX0      => HEX0
        );
        
    HEX1 <= (others => '1'); HEX2 <= (others => '1'); HEX3 <= (others => '1');
    HEX4 <= (others => '1'); HEX5 <= (others => '1');
        
end architecture structural;