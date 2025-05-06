# Matrix Multiplier

## Objectives
The multiplication of matrices is a very common operation in engineering and scientific problems. The sequential implementation of this operation is very time consuming for large matrices; the brute-force solution results in computation time O(n3), for n x n matrices. For this reason, several parallel algorithms have been developed to solve this problem more efficiently. In this project, we introduce a new parallel and scalable approach.

## New Parallel Model
<figure>
    <img src="/images/new-parallel-model.png"
         alt="PE Architecture">
    <figcaption>Figure: Parallel Matrix Multiplication Sequence</figcaption>
</figure>

Optimal data re-use by:
- Simultaneously reading one column of matrix A and one row of matrix B. 
- Performing all multiply operations based on those values before another memory read.
<br>
Partial product of every elements in output matrix C is produced per clock cycle.
	
## Multiplier Array Architecture

<figure>
    <img src="/images/multiplier-array-architecture.png"
         alt="PE Architecture">
    <figcaption>Figure: Multiplier Array Architecture</figcaption>
</figure>
L: number of columns of matrix A. 
M: number of rows of matrix B. 
No interconnections between the PEs.

## PE Architecture 

<figure>
    <img src="/images/pe.png"
         alt="PE Architecture">
    <figcaption>Figure: PE Architecture</figcaption>
</figure>

## Top module Architecture and Symbol

## Multiplication Algorithm
<figure>
    <img src="/images/carry-save-multiplier-example.png"
         alt="Systolic-array block diagram">
    <figcaption>Figure: 4-bit Multiplication Example</figcaption>
</figure>

The multiplication consists of:
- n-bit multiplicand -> n columns of multiplier adder(MA).
- n-bit multiplier -> n rows of MAs.
- 2xn-bit product.
- 1 extra row with n ripple adders at last.
<br>
Process: Each partial product is a stage 
- stage: 0 -> n-1 (multiplier adder)
	- sum = previous sum(sum_in) + partial product + previous c_out(c_in).
	- sum_in and c_in at initial stage are 0.
- last stage: n (ripple adder) 
	- sum = sum_in + c_in + c_ripple
<br>
Product: 
``` Product 
i = 0
j = 0
sum[n][n]

for: i < n
	product[i] = sum[i][0]
	i++
if i = n
	product[i] = sum[i][j] // sum from ripple adder
	i++
	j++
```

## Carry-save Multiplier Architecture
<figure>
    <img src="/images/carry-save-multiplier.png"
         alt="Systolic-array block diagram">
    <figcaption>Figure: 4-bit Carry-save Multiplier</figcaption>
</figure>

This is a 4-bit carry-save multiplier, which can be easily scale to n-bit carry-save multiplier, includes:
- Extra row of n-bit ripple adder at the end.
- n rows and columns of 1-bit multiplier cell.
<br>
Multiplier Adder:
- calculates the partial product. 
- implements the sum: partial product + previous. sum(sum_in) + previous c_out(c_in).
- produces new sum and c_out for the next stage.
### Multiplier Cell
<figure>
    <img src="/images/multiplier-cell.png"
         alt="Systolic-array block diagram">
    <figcaption>Figure: 1-bit Multiplier Cell</figcaption>
</figure>

### Floating-point Multiplier Architecture
<figure>
    <img src="/images/floating-point-multiplier.png"
         alt="Floating-point Multiplier Hardware Architecture">
    <figcaption>Figure: Floating-point Multiplier Hardware Architecture</figcaption>
</figure>

## 32-bit Floating-point Representation

| Bits    | Field               | Purpose                         |
| ------- | ------------------- | ------------------------------- |
| 1 bit   | Sign                | Determines positive or negative |
| 8 bits  | Exponent            | Scaled with a bias (127)        |
| 23 bits | Mantissa (Fraction) | Holds the fraction              |

### Special Cases
| Pattern                  | Value             |     |
| ------------------------ | ----------------- | --- |
| Exponent = 255, Mant ≠ 0 | NaN               |     |
| Exponent = 255, Mant = 0 | ±Infinity         |     |
| Exponent = 0, Mant = 0   | ±Zero             |     |
| Exponent = 0, Mant ≠ 0   | Subnormal numbers |     |

### Formula
Value = (−1)^sign × 1.mantissa × 2^(exponent−127)

#### Example
0 10000001 01000000000000000000000 <br>
Sign = 0 => positive <br>
Exponent = 10000001(bin) = 129(dec) <br>
Mantissa = 01000000000000000000000 <br> 

Value = (-1)^0 × (1.01) × 2^(129−127) = 1.25 × 22= 5.0

## Floating-point Multiplication


The IEEE-754 32-bit floating point number format consists of:

- **1 bit** sign
- **8 bits** exponent (biased by 127)
- **23 bits** mantissa (with an implicit leading 1)

### 📐 Multiplication Process

1. **Extract Fields**: Break each operand into sign, exponent, and mantissa.
2. **Sign Calculation**: Result sign = `sign_a XOR sign_b`
3. **Exponent Addition**: `exp_result = exp_a + exp_b - 127`
4. **Mantissa Multiplication**: Multiply the two 24-bit mantissas.
5. **Normalization**: Shift mantissa if needed and adjust exponent.
6. **Rounding**: Round mantissa to 23 bits (add guard, round, sticky bits if needed).
7. **Pack Result**: Combine the final sign, exponent, and mantissa into 32-bit result.

### ⚠️ Special Cases

| Operand A             | Operand B    | Result      | Explanation                                     |
| --------------------- | ------------ | ----------- | ----------------------------------------------- |
| 0                     | 0            | 0           | Zero times zero is zero                         |
| 0                     | Finite       | 0           | Zero times any finite number is zero            |
| 0                     | ±Infinity    | NaN         | Zero times infinity is undefined → NaN          |
| ±Infinity             | 0            | NaN         | Same as above                                   |
| ±Infinity             | Finite (≠ 0) | ±Infinity   | Infinity times non-zero finite is infinity      |
| Finite (≠ 0)          | ±Infinity    | ±Infinity   | Same as above                                   |
| ±Infinity             | ±Infinity    | ±Infinity   | Infinity times infinity is infinity             |
| NaN                   | Any          | NaN         | NaN propagates                                  |
| Any                   | NaN          | NaN         | NaN propagates                                  |
| Denormal              | Finite       | Denormal/0  | May underflow to denormal or zero               |
| Underflow (exp < min) | Any          | 0 or Denorm | Exponent underflows — result too small to store |
| Overflow (exp > max)  | Any          | ±Infinity   | Exponent overflows — result too large to store  |


### 🧪 Example: 3.0 × 2.5

- IEEE-754 of 3.0 = `0 10000000 10000000000000000000000`
- IEEE-754 of 2.5 = `0 10000000 01000000000000000000000`
- Result ≈ 7.0 = `0 10000001 11000000000000000000000`



