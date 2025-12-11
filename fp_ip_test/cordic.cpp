#include <iostream>
#include <vector>
#include <cmath>
#include <iomanip>
#include <cstdint>

#define MAX_EPISILON (.000000001) //35 iterations
#define EPISILON     (.000000001) //35 iterations
//#define EPISILON    (.00000001) //32 iterations
//#define EPISILON     (.0000001) //29 iterations

std::vector<double> tan_theta_values;
std::vector<double> degrees;
std::vector<double> k; // Vector to store Ki values
#define PI (3.141592653589793238463)

void create_table() {
   // double delta_degrees = 360.0; // This variable was unused in the original code
   
   int i =0;
   // The loop condition implicitly manages when to stop based on EPISILON
   while(true){ 
    double tan_theta = 1.0 / std::pow(2.0, i);
    double corresponding_angle;
    tan_theta_values.push_back(tan_theta);
    corresponding_angle = std::atan(tan_theta) * (180.0/PI);
    degrees.push_back(corresponding_angle);
    double Ki = std::cos(corresponding_angle * (PI/180.0));
    k.push_back(Ki); // Store the K value
   
    if(corresponding_angle < EPISILON ){
        break;
    }
    i++;
   }
}

void print_table_hex() {
    // Increased table width to accommodate the new columns
    std::cout << "\n--------------------------------------------------------------------------------------------------------------------------------------------------" << std::endl;
    std::cout << "| Iter | tan(theta) (Decimal)   | tan(theta) (Hexadecimal uint64_t) | Degree (Decimal)         | k (Decimal)            | k (Hexadecimal uint64_t) |" << std::endl;
    std::cout << "--------------------------------------------------------------------------------------------------------------------------------------------------" << std::endl;

    for (size_t i = 0; i < tan_theta_values.size(); ++i) {
        // Union for type punning (safe in C++ for this purpose)
        union {
            double d;
            uint64_t u;
        } val_tan, val_k;
        
        val_tan.d = tan_theta_values[i];
        val_k.d = k[i];

        uint64_t hex_tan_val = val_tan.u;
        uint64_t hex_k_val = val_k.u;

        // Set manipulators for output formatting
        std::cout << std::fixed << std::setprecision(15);
        std::cout << "| " << std::setw(4) << i 
                  << " | " << std::setw(22) << tan_theta_values[i] 
                  << " | 0x" << std::hex << std::uppercase << std::setfill('0') << std::setw(16) << hex_tan_val << std::dec << std::setfill(' ') // Switch back to decimal formatting
                  << " | " << std::setw(24) << degrees[i]
                  << " | " << std::setw(22) << k[i] // Print the decimal K value
                  << " | 0x" << std::hex << std::uppercase << std::setfill('0') << std::setw(16) << hex_k_val << std::dec << std::setfill(' ') // Print the hex K value
                  << " |" << std::endl;
    }
    std::cout << "--------------------------------------------------------------------------------------------------------------------------------------------------" << std::endl;
}

void cordic_calculate_sine_cosine(double angle, double& sine_val, double& cosine_val)
{
    // ... (rest of the local variables as before) ...
    double current_angle = 0.0;
    double current_x = 1.0; // Initial vector magnitude is 1.0 (before scaling correction)
    double current_y = 0.0;
    int iter = 0;
    double K_factor = 1.0;
    // Original loop logic
    while ((std::abs(angle - current_angle) > EPISILON) && iter < degrees.size()){
       
       if ( angle > current_angle){
        //add
        double next_x = current_x - current_y*tan_theta_values[iter]; // Use temporary variables for correct parallel updates
        double next_y = current_y + current_x*tan_theta_values[iter];
        current_x = next_x;
        current_y = next_y;
        current_angle += degrees[iter];
       }else{
        //subtract
        double next_x = current_x + current_y*tan_theta_values[iter]; // Sign flipped for subtraction
        double next_y = current_y - current_x*tan_theta_values[iter];
        current_x = next_x;
        current_y = next_y;
        current_angle -= degrees[iter];
       }
       K_factor *= k[iter];
       iter++;
       // Optional: std::cout << std::fixed <<  std::setprecision (15) << "current_angle" << current_angle << " x: " << current_x << std::endl;
    }
    
    // Apply the scaling factor correction
    cosine_val = current_x * K_factor; // K_factor is the inverse of the accumulated magnitude gain (1/1.6468...)
    sine_val = current_y * K_factor;
}

int main ()
{
    create_table();
    print_table_hex();
    double sine_val =0.0;
    double cosine_val =0.0;
    double angle = 30.0;
    cordic_calculate_sine_cosine(angle , sine_val, cosine_val);
    std::cout << std::fixed <<  std::setprecision (15) << "sine:" << sine_val << " cosine: " << cosine_val << std::endl;
}
