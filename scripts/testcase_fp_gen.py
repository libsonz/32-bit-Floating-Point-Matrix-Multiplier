import random
import os
import struct

def float_to_hex(f):
    """Chuyển số float Python thành dạng hex 32-bit IEEE 754"""
    return '{:08X}'.format(struct.unpack('>I', struct.pack('>f', f))[0])

def generate_matrix(rows, cols, min_val=-10.0, max_val=10.0):
    """Sinh ma trận số thực, mỗi phần tử làm tròn tới phần thập phân thứ hai"""
    return [[round(random.uniform(min_val, max_val), 2) for _ in range(cols)] for _ in range(rows)]

def write_matrix_hex(matrix, filename):
    """Ghi ma trận ra file, mỗi phần tử là hex (float32 IEEE-754) cách nhau bởi dấu cách"""
    with open(filename, 'w') as f:
        for row in matrix:
            f.write(' '.join(float_to_hex(x) for x in row) + '\n')

def write_matrix_float(matrix, filename):
    """Ghi ma trận ra file, mỗi phần tử là số thực (để dễ đọc kiểm tra)"""
    with open(filename, 'w') as f:
        for row in matrix:
            f.write(' '.join(f"{x:.2f}" for x in row) + '\n')

def matrix_multiply(A, B):
    """Nhân 2 ma trận số thực (dùng cho kiểm tra kết quả)"""
    return [[round(sum(a*b for a, b in zip(A_row, B_col)), 2) for B_col in zip(*B)] for A_row in A]

def generate_test_case(test_num, M=3, K=3, N=3, min_val=-10.0, max_val=10.0):
    """Sinh 1 test case: A, B, expected_C ở dạng hex và dạng float"""
    test_dir = f"testcases_fp/test_{test_num:d}"
    os.makedirs(test_dir, exist_ok=True)

    A = generate_matrix(M, K, min_val, max_val)
    B = generate_matrix(K, N, min_val, max_val)
    expected_C = matrix_multiply(A, B)

    write_matrix_hex(A, f"{test_dir}/matrix_A.txt")
    write_matrix_hex(B, f"{test_dir}/matrix_B.txt")
    write_matrix_hex(expected_C, f"{test_dir}/expected_C.txt")

    write_matrix_float(A, f"{test_dir}/matrix_A_float.txt")
    write_matrix_float(B, f"{test_dir}/matrix_B_float.txt")
    write_matrix_float(expected_C, f"{test_dir}/expected_C_float.txt")

    with open(f"{test_dir}/test_init.v", 'w') as f:
        f.write(f"// Test Case {test_num}\n")
        f.write("initial begin\n")
        f.write("    // Initialize matrix A (float32 IEEE-754 hex)\n")
        for i in range(M):
            for j in range(K):
                f.write(f"    A[{i}][{j}] = 32'h{float_to_hex(A[i][j])};\n")
        f.write("\n    // Initialize matrix B (float32 IEEE-754 hex)\n")
        for i in range(K):
            for j in range(N):
                f.write(f"    B[{i}][{j}] = 32'h{float_to_hex(B[i][j])};\n")
        f.write("end\n")

def main():
    num_test_cases = 100
    matrix_size = 3
    min_val = -10.0
    max_val = 10.0

    os.makedirs("testcases_fp", exist_ok=True)

    print(f"Generating {num_test_cases} floating-point test cases...")
    for i in range(num_test_cases):
        generate_test_case(i, matrix_size, matrix_size, matrix_size, min_val, max_val)
        print(f"Generated test case {i:0d}", end='\r')

    print("\nDone! Test cases generated in 'testcases_fp/' directory")

if __name__ == "__main__":
    main()
