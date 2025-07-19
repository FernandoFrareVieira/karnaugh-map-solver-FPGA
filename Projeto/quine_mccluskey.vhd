library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity quine_mccluskey is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;
        start            : in  std_logic;
        truth_table      : in  std_logic_vector(15 downto 0);
        done             : out std_logic;
        result_terms     : out std_logic_vector(63 downto 0);
        num_result_terms : out std_logic_vector(3 downto 0)
    );
end entity;

architecture behavioral_sequential of quine_mccluskey is

    type b_number_type is record
        number : std_logic_vector(3 downto 0);
        dashes : std_logic_vector(3 downto 0);
    end record;
    
    type prime_implicants_array is array (0 to 31) of b_number_type;
    type minterms_array is array (0 to 15) of integer range 0 to 15;
    type coverage_table_type is array (0 to 31, 0 to 15) of std_logic;

    type state_type is (
        IDLE,
        
        IE_INIT, IE_LOOP, 
        
        C_PASS_INIT, C_LOOP_I, C_LOOP_J, C_CHECK_COMBINE, C_ADD_NEW_PI, C_PASS_FINISH,
        COLLECT_AND_DECIDE,
        
        BCT_INIT, BCT_LOOP, 
        
        SEP_INIT, SEP_FIND_OUTER_LOOP, SEP_FIND_INNER_LOOP, SEP_FIND_EVALUATE,
        SEP_MARK_INIT, SEP_MARK_OUTER_LOOP, SEP_MARK_INNER_LOOP,
        
        CFC_CHECK_INIT, CFC_CHECK_LOOP,
        CFC_FIND_BEST_OUTER_INIT, CFC_FIND_BEST_OUTER_LOOP, CFC_FIND_BEST_INNER_LOOP, CFC_FIND_BEST_EVALUATE,
        CFC_UPDATE_INIT, CFC_UPDATE_LOOP,

        FINALIZE_INIT, FINALIZE_LOOP, FINALIZE_WRITE,
        DONE_STATE
    );

    signal current_state    : state_type := IDLE;
    signal pi_table         : prime_implicants_array;
    signal next_pi_table    : prime_implicants_array;
    signal final_pi_list    : prime_implicants_array;
    signal pi_used_flags    : std_logic_vector(31 downto 0);
    signal num_pi           : integer range 0 to 32 := 0;
    signal num_next_pi      : integer range 0 to 32 := 0;
    signal num_final_pi     : integer range 0 to 32 := 0;
    
    signal minterms_list    : minterms_array;
    signal num_minterms     : integer range 0 to 16 := 0;
    
    signal coverage_table   : coverage_table_type;
    signal minterms_covered : std_logic_vector(15 downto 0);
    signal pi_is_in_solution: std_logic_vector(31 downto 0);
    
    signal i, j, k          : integer range 0 to 32;
    signal combination_made : std_logic;
    signal temp_pi          : b_number_type;
    
    signal best_pi_idx      : integer range -1 to 31;
    signal max_coverage     : integer range 0 to 16;

    signal s_temp_count         : integer range 0 to 32;
    signal s_temp_essential_idx : integer range -1 to 31;
    signal s_current_coverage   : integer range 0 to 16;
    signal s_all_covered        : std_logic;
    signal s_result             : std_logic_vector(63 downto 0);
    signal s_count_terms        : integer range 0 to 8;

    constant NULL_B_NUMBER  : b_number_type := (number => (others=>'0'), dashes => (others=>'0'));

    function count_ones(number : std_logic_vector(3 downto 0)) return integer is
        variable count : integer := 0;
    begin
        for i in number'range loop
            if number(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
    
    function can_combine(term1, term2 : b_number_type) return boolean is
        variable diff_mask : std_logic_vector(3 downto 0);
    begin
        if term1.dashes /= term2.dashes then return false; end if;
        diff_mask := (term1.number xor term2.number) and (not term1.dashes);
        return (count_ones(diff_mask) = 1);
    end function;

    function covers_minterm(prime_impl : b_number_type; minterm : integer) return boolean is
        variable minterm_vector : std_logic_vector(3 downto 0);
    begin
        minterm_vector := std_logic_vector(to_unsigned(minterm, 4));
        return ((prime_impl.number and not prime_impl.dashes) = (minterm_vector and not prime_impl.dashes));
    end function;

begin

    done <= '1' when current_state = DONE_STATE else '0';

    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            num_result_terms <= (others => '0');
            result_terms <= (others => '0');
            i <= 0; j <= 0; k <= 0;
            
        elsif rising_edge(clk) then
            case current_state is

                when IDLE =>
                    if start = '1' then
                        current_state <= IE_INIT;
                    end if;

                when IE_INIT =>
                    i <= 0; 
                    num_pi <= 0;
                    num_minterms <= 0;
                    pi_table <= (others => NULL_B_NUMBER);
                    minterms_list <= (others => 0);
                    num_final_pi <= 0;
                    final_pi_list <= (others => NULL_B_NUMBER);
                    current_state <= IE_LOOP;

                when IE_LOOP =>
                    if i < 16 then
                        if truth_table(i) = '1' then
                            pi_table(num_pi).number <= std_logic_vector(to_unsigned(i, 4));
                            pi_table(num_pi).dashes <= "0000";
                            minterms_list(num_minterms) <= i;
                            num_pi <= num_pi + 1;
                            num_minterms <= num_minterms + 1;
                        end if;
                        i <= i + 1;
                    else
                        if num_pi = 0 or num_pi = 16 then
                            current_state <= FINALIZE_INIT;
                        else
                            current_state <= C_PASS_INIT;
                        end if;
                    end if;


                when C_PASS_INIT =>
                    i <= 0; j <= 1; k <= 0;
                    num_next_pi <= 0;
                    next_pi_table <= (others => NULL_B_NUMBER);
                    pi_used_flags <= (others => '0');
                    combination_made <= '0';
                    current_state <= C_LOOP_I;

                when C_LOOP_I =>
                    if i < num_pi - 1 then
                        j <= i + 1;
                        current_state <= C_LOOP_J;
                    else
                        current_state <= C_PASS_FINISH;
                    end if;

                when C_LOOP_J =>
                    if j < num_pi then
                        current_state <= C_CHECK_COMBINE;
                    else
                        i <= i + 1;
                        current_state <= C_LOOP_I;
                    end if;
                
                when C_CHECK_COMBINE =>
                    if can_combine(pi_table(i), pi_table(j)) then
                        pi_used_flags(i) <= '1';
                        pi_used_flags(j) <= '1';
                        combination_made <= '1';
                        temp_pi.number <= pi_table(i).number and pi_table(j).number;
                        temp_pi.dashes <= pi_table(i).dashes or (pi_table(i).number xor pi_table(j).number);
                        k <= 0; 
                        current_state <= C_ADD_NEW_PI;
                    else
                        j <= j + 1;
                        current_state <= C_LOOP_J;
                    end if;

                when C_ADD_NEW_PI =>
                    if k < num_next_pi then
                        if next_pi_table(k).number = temp_pi.number and next_pi_table(k).dashes = temp_pi.dashes then
                            j <= j + 1;
                            current_state <= C_LOOP_J;
                        else
                            k <= k + 1; 
                        end if;
                    else
                        next_pi_table(num_next_pi) <= temp_pi;
                        num_next_pi <= num_next_pi + 1;
                        j <= j + 1;
                        current_state <= C_LOOP_J;
                    end if;

                when C_PASS_FINISH =>
                    k <= 0;
                    current_state <= COLLECT_AND_DECIDE;

                when COLLECT_AND_DECIDE =>
                    if combination_made = '1' then
                        if k < num_pi then
                            if pi_used_flags(k) = '0' then
                                final_pi_list(num_final_pi) <= pi_table(k);
                                num_final_pi <= num_final_pi + 1;
                            end if;
                            k <= k + 1;
                        else
                            pi_table <= next_pi_table;
                            num_pi <= num_next_pi;
                            current_state <= C_PASS_INIT;
                        end if;
                    else
                        if k < num_pi then
                            final_pi_list(num_final_pi) <= pi_table(k);
                            num_final_pi <= num_final_pi + 1;
                            k <= k + 1;
                        else
                            current_state <= BCT_INIT;
                        end if;
                    end if;

   
                when BCT_INIT =>
                    i <= 0; 
                    j <= 0; 
                    coverage_table <= (others => (others => '0'));
                    current_state <= BCT_LOOP;

                when BCT_LOOP =>
                    if i < num_final_pi then
                        if j < num_minterms then
                            if covers_minterm(final_pi_list(i), minterms_list(j)) then
                                coverage_table(i,j) <= '1';
                            end if;
                            j <= j + 1;
                        else
                            j <= 0;
                            i <= i + 1;
                        end if;
                    else
                        pi_is_in_solution <= (others => '0');
                        minterms_covered <= (others => '0');
                        current_state <= SEP_INIT;
                    end if;

     
                when SEP_INIT =>
                    i <= 0; 
                    current_state <= SEP_FIND_OUTER_LOOP;
                
                when SEP_FIND_OUTER_LOOP =>
                    if i < num_minterms then
                        j <= 0; 
                        s_temp_count <= 0;
                        s_temp_essential_idx <= -1;
                        current_state <= SEP_FIND_INNER_LOOP;
                    else
                        current_state <= SEP_MARK_INIT; 
                    end if;

                when SEP_FIND_INNER_LOOP =>
                    if j < num_final_pi then
                        if coverage_table(j, i) = '1' then
                            s_temp_count <= s_temp_count + 1;
                            s_temp_essential_idx <= j;
                        end if;
                        j <= j + 1;
                    else
                        current_state <= SEP_FIND_EVALUATE;
                    end if;
                
                when SEP_FIND_EVALUATE =>
                    if s_temp_count = 1 then
                        pi_is_in_solution(s_temp_essential_idx) <= '1';
                    end if;
                    i <= i + 1; 
                    current_state <= SEP_FIND_OUTER_LOOP;
                
                when SEP_MARK_INIT =>
                    i <= 0;
                    current_state <= SEP_MARK_OUTER_LOOP;

                when SEP_MARK_OUTER_LOOP =>
                    if i < num_final_pi then
                        if pi_is_in_solution(i) = '1' then
                            j <= 0; 
                            current_state <= SEP_MARK_INNER_LOOP;
                        else
                            i <= i + 1; 
                        end if;
                    else
                        current_state <= CFC_CHECK_INIT;
                    end if;

                when SEP_MARK_INNER_LOOP =>
                    if j < num_minterms then
                        if coverage_table(i, minterms_list(j)) = '1' then
                            minterms_covered(minterms_list(j)) <= '1';
                        end if;
                        j <= j + 1;
                    else
                        i <= i + 1;
                        current_state <= SEP_MARK_OUTER_LOOP;
                    end if;

                when CFC_CHECK_INIT =>
                    i <= 0;
                    s_all_covered <= '1';
                    current_state <= CFC_CHECK_LOOP;

                when CFC_CHECK_LOOP =>
                    if i < num_minterms then
                        if minterms_covered(minterms_list(i)) = '0' then
                            s_all_covered <= '0';
                        end if;
                        i <= i + 1;
                    else
                        if s_all_covered = '1' then
                            current_state <= FINALIZE_INIT;
                        else
                            current_state <= CFC_FIND_BEST_OUTER_INIT;
                        end if;
                    end if;

                when CFC_FIND_BEST_OUTER_INIT =>
                    i <= 0; 
                    max_coverage <= 0;
                    best_pi_idx <= -1;
                    current_state <= CFC_FIND_BEST_OUTER_LOOP;

                when CFC_FIND_BEST_OUTER_LOOP =>
                    if i < num_final_pi then
                        if pi_is_in_solution(i) = '0' then
                           j <= 0; 
                           s_current_coverage <= 0;
                           current_state <= CFC_FIND_BEST_INNER_LOOP;
                        else
                           i <= i + 1;
                        end if;
                    else
                        current_state <= CFC_FIND_BEST_EVALUATE;
                    end if;

                when CFC_FIND_BEST_INNER_LOOP =>
                    if j < num_minterms then
                        if minterms_covered(minterms_list(j)) = '0' and coverage_table(i, j) = '1' then
                           s_current_coverage <= s_current_coverage + 1;
                        end if;
                        j <= j + 1;
                    else
                        if s_current_coverage > max_coverage then
                            max_coverage <= s_current_coverage;
                            best_pi_idx <= i;
                        end if;
                        i <= i + 1;
                        current_state <= CFC_FIND_BEST_OUTER_LOOP;
                    end if;

                when CFC_FIND_BEST_EVALUATE =>
                     if best_pi_idx = -1 then
                        current_state <= FINALIZE_INIT;
                     else
                        pi_is_in_solution(best_pi_idx) <= '1';
                        current_state <= CFC_UPDATE_INIT;
                     end if;

                when CFC_UPDATE_INIT =>
                    i <= 0; 
                    current_state <= CFC_UPDATE_LOOP;
                
                when CFC_UPDATE_LOOP =>
                    if best_pi_idx /= -1 and i < num_minterms then
                        if coverage_table(best_pi_idx, i) = '1' then
                           minterms_covered(minterms_list(i)) <= '1';
                        end if;
                        i <= i + 1;
                    else
                        current_state <= CFC_CHECK_INIT; 
                    end if;
                    

                when FINALIZE_INIT =>
                    s_result <= (others => '0');
                    s_count_terms <= 0;
                    i <= 0; 
                    if truth_table = "1111111111111111" then
                         s_result(7 downto 0) <= "00001111"; 
                         s_count_terms <= 1;
                         current_state <= FINALIZE_WRITE;
                    elsif truth_table = "0000000000000000" then
                         current_state <= FINALIZE_WRITE;
                    else
                         current_state <= FINALIZE_LOOP;
                    end if;

                when FINALIZE_LOOP =>
                    if i < num_final_pi then
                        if pi_is_in_solution(i) = '1' and s_count_terms < 8 then
                           s_result(s_count_terms*8 + 7 downto s_count_terms*8 + 4) <= final_pi_list(i).number;
                           s_result(s_count_terms*8 + 3 downto s_count_terms*8)     <= final_pi_list(i).dashes;
                           s_count_terms <= s_count_terms + 1;
                        end if;
                        i <= i + 1;
                    else
                        current_state <= FINALIZE_WRITE;
                    end if;

                when FINALIZE_WRITE =>
                    result_terms <= s_result;
                    num_result_terms <= std_logic_vector(to_unsigned(s_count_terms, 4));
                    current_state <= DONE_STATE;

                when DONE_STATE =>
                    if start = '0' then
                        current_state <= IDLE;
                    end if;
                
                when others =>
                    current_state <= IDLE;
                    
            end case;
        end if;
    end process;

end architecture;