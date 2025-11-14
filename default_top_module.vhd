----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/08/2025 11:27:57 PM
-- Design Name: 
-- Module Name: top_module - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_module is
Port (
    CLK:     in  std_logic;  -- 100 MHz clock
    RST:     in  std_logic;  -- Reset button
    SW:      in  std_logic_vector(7 downto 0);
    BTN:     in std_logic_vector(4 downto 0);
    LED:     out std_logic_vector(7 downto 0);
    );
end top_module;

architecture Behavioral of top_module is
    -- Constants
   
begin
   
    
end Behavioral;
