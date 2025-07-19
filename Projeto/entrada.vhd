library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity entrada is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        stop        : in  std_logic;  
        data        : in  std_logic;  
        next_bit    : in  std_logic;  

        truth_table : out std_logic_vector(15 downto 0); 
        counter     : out std_logic_vector(3 downto 0)   
    );
end entity entrada;

architecture behavioral of entrada is
    signal s_truth_table_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal s_bit_index_reg   : integer range 0 to 15 := 0;
    signal s_prev_next       : std_logic := '0'; 
    signal s_prev_load_start_btn : std_logic := '0';

begin
    truth_table <= s_truth_table_reg;
    counter <= std_logic_vector(to_unsigned(s_bit_index_reg, 4));

    process(clk, reset)
    begin
        if reset = '1' then
            s_truth_table_reg <= (others => '0');
            s_bit_index_reg   <= 0;
            s_prev_next       <= '0';
        elsif rising_edge(clk) then
            s_prev_next <= next_bit; 

            if stop = '0' then
                if next_bit = '1' and s_prev_next = '0' then 
                    s_truth_table_reg(s_bit_index_reg) <= data;
                    if s_bit_index_reg = 15 then
                        s_bit_index_reg <= 0;
                    else
                        s_bit_index_reg <= s_bit_index_reg + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;