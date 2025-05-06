import random
import os

def generate_matrix(rows, cols, min_val=0, max_val=15):
    """Generate a random matrix with given dimensions and value range."""
    # Ensure max_val is within a reasonable range for the specified DATA_WIDTH in Verilog
    # For DATA_WIDTH = 16, max_val should be less than 2**16
    # For DATA_WIDTH = 32, max_val should be less than 2**32
    # Let's keep it simple and assume max_val is appropriate for your Verilog DATA_WIDTH
    return [[random.randint(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

def write_matrix(matrix, filename):
    """Write matrix to file with values formatted as hexadecimal."""
    with open(filename, 'w') as f:
        for row in matrix:
            # Format each number as a hexadecimal string without the '0x' prefix
            # Use f'{value:x}' for lowercase hex, f'{value:X}' for uppercase hex
            # Let's use lowercase hex for consistency with Verilog
            hex_row = [f'{val:x}' for val in row]
            f.write(' '.join(hex_row) + '\n')

def matrix_multiply(A, B):
    """Multiply two matrices (for verification). Returns integer results."""
    # Standard matrix multiplication logic, works with integers
    # The result can be larger than the input data width, so the ACC_WIDTH in Verilog
    # must be large enough to hold the maximum possible result.
    # Max possible result for one element C[i][j] is sum of K products.
    # Max product is max_val * max_val. Max sum is K * max_val * max_val.
    # Ensure your Verilog ACC_WIDTH is sufficient.
    # Example for DATA_WIDTH=16, K=3, max_val=15: Max product = 15*15 = 225. Max sum = 3 * 225 = 675.
    # Need enough bits to represent 675. $clog2(675) is about 10 bits.
    # Your Verilog ACC_WIDTH = DATA_WIDTH * 2 + $clog2(K) might be overly generous or not enough depending on max_val.
    # Let's assume the Python calculation is correct for verification.
    return [[sum(a*b for a,b in zip(A_row, B_col)) for B_col in zip(*B)] for A_row in A]

def generate_test_case(test_num, M=3, K=3, N=3, min_val=0, max_val=15):
    """Generate a complete test case."""
    # Create test case directory
    test_dir = f"testcases/test_{test_num:0d}" # Use 03d for zero-padding test numbers
    os.makedirs(test_dir, exist_ok=True)

    # Generate matrices with specified value range
    A = generate_matrix(M, K, min_val, max_val)
    B = generate_matrix(K, N, min_val, max_val)
    expected_C = matrix_multiply(A, B)

    # Write files with hexadecimal values
    write_matrix(A, f"{test_dir}/matrix_A.txt")
    write_matrix(B, f"{test_dir}/matrix_B.txt")
    write_matrix(expected_C, f"{test_dir}/expected_C.txt") # Expected C can also be written as hex

def main():
    # Configuration
    num_test_cases = 100
    matrix_size = 3  # M=K=N=3
    # Define the range for random values (0 to 15 for 4-bit DATA_WIDTH example)
    min_val = 0
    max_val = 15 # Corresponds to 4 bits (0xF)

    # Ensure the testcases directory exists
    os.makedirs("testcases", exist_ok=True)

    # Generate test cases
    print(f"Generating {num_test_cases} test cases with hexadecimal values...")
    # Loop from 0 to num_test_cases-1 for directory naming consistency
    for i in range(num_test_cases):
        generate_test_case(i, matrix_size, matrix_size, matrix_size, min_val, max_val)
        print(f"Generated test case {i:03d}", end='\r')

    print("\nDone! Test cases generated in 'testcases/' directory")
    print("Each test case contains:")
    print("- matrix_A.txt    : Input matrix A (hexadecimal)")
    print("- matrix_B.txt    : Input matrix B (hexadecimal)")
    print("- expected_C.txt  : Expected output matrix (hexadecimal)")
    print("- test_init.v    : Verilog initialization code (hexadecimal literals)")

if __name__ == "__main__":
    main()
