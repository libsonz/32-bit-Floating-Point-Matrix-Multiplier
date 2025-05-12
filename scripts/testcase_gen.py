import random
import os

def generate_matrix(rows, cols, min_val=0, max_val=15):
    """Generate a random matrix with given dimensions"""
    return [[random.randint(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

def write_matrix(matrix, filename):
    """Write matrix to file"""
    with open(filename, 'w') as f:
        for row in matrix:
            f.write(' '.join(map(str, row)) + '\n')

def matrix_multiply(A, B):
    """Multiply two matrices (for verification)"""
    return [[sum(a*b for a,b in zip(A_row, B_col)) for B_col in zip(*B)] for A_row in A]

def generate_test_case(test_num, M=3, K=3, N=3):
    """Generate a complete test case"""
    # Create test case directory
    test_dir = f"testcases/test_{test_num:d}"
    os.makedirs(test_dir, exist_ok=True)
    
    # Generate matrices
    A = generate_matrix(M, K)
    B = generate_matrix(K, N)
    expected_C = matrix_multiply(A, B)
    
    # Write files
    write_matrix(A, f"{test_dir}/matrix_A.txt")
    write_matrix(B, f"{test_dir}/matrix_B.txt")
    write_matrix(expected_C, f"{test_dir}/expected_C.txt")
    
    # Generate Verilog testbench initialization code
    with open(f"{test_dir}/test_init.v", 'w') as f:
        f.write(f"// Test Case {test_num}\n")
        f.write("initial begin\n")
        f.write("    // Initialize matrix A\n")
        for i in range(M):
            for j in range(K):
                f.write(f"    A[{i}][{j}] = {A[i][j]};\n")
        f.write("\n    // Initialize matrix B\n")
        for i in range(K):
            for j in range(N):
                f.write(f"    B[{i}][{j}] = {B[i][j]};\n")
        f.write("end\n")

def main():
    # Configuration
    num_test_cases = 100
    matrix_size = 3  # M=K=N=3
    
    # Create testcases directory
    os.makedirs("testcases", exist_ok=True)
    
    # Generate test cases
    print(f"Generating {num_test_cases} test cases...")
    for i in range(0, num_test_cases):
        generate_test_case(i, matrix_size, matrix_size, matrix_size)
        print(f"Generated test case {i:0d}", end='\r')
    
    print("\nDone! Test cases generated in 'testcases/' directory")
    print("Each test case contains:")
    print("- matrix_A.txt    : Input matrix A")
    print("- matrix_B.txt    : Input matrix B")
    print("- expected_C.txt  : Expected output matrix")
    print("- test_init.v    : Verilog initialization code")

if __name__ == "__main__":
    main()