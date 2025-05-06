import struct

def float_to_hex(f):
    """Convert a Python float to IEEE 754 hex (32-bit)"""
    return struct.unpack('>I', struct.pack('>f', f))[0]

def hex_to_float(h):
    """Convert IEEE 754 hex (32-bit) to Python float"""
    return struct.unpack('>f', struct.pack('>I', h))[0]

def generate_test_vector(fa, fb):
    ha = float_to_hex(fa)
    hb = float_to_hex(fb)
    fr = fa * fb
    hr = float_to_hex(fr)

    print(f"// {fa} * {fb} = {fr}")
    print(f"run_test(32'h{ha:08X}, 32'h{hb:08X}, 32'h{hr:08X});\n")

# Example test cases
generate_test_vector(2.0, 3.0)
generate_test_vector(-2.0, 3.0)
generate_test_vector(0.0, 123.456)
generate_test_vector(float('inf'), 2.0)
generate_test_vector(float('inf'), -2.0)
generate_test_vector(float('nan'), 2.0)
generate_test_vector(float('inf'), 0.0)
generate_test_vector(1.5, -4.25)
generate_test_vector(10.24, -4.25)
generate_test_vector(0.000000001, -10.88888888)
