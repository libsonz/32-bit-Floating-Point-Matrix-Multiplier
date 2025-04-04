# Matrix Multiplier

## Objectives
The multiplication of matrices is a very common operation in engineering and scientific problems. The sequential implementation of this operation is very time consuming for large matrices; the brute-force solution results in computation time O(n3), for n x n matrices. For this reason, several parallel algorithms have been developed to solve this problem more efficiently. Here, a simple parallel algorithm is presented for this problem and a "hardwired" (actually, systolic-array) implementation of the algorithm becomes our objective.

## 32-bit Floating Point Representation


## Algorithm
In this illustraion, we are gonna take two 3x3 matrices as example.
[Systolic-array visulization](https://www.youtube.com/watch?v=cmy7LBaWuZ8)

<figure>
    <img src="/images/systolic-array.png"
         alt="Systolic-array block diagram">
    <figcaption>Figure: Systolic-array block diagram</figcaption>
</figure>

Each PE in the systolic array computes each element of the final result matrix.

### How does it work?
For each Pij/cycle:<br>
&ensp; Pij = accumualtion of product of Aij x Bji<br>
&ensp; Aij is transfered to the next right P, Pij+1 (j < 3, i > 0)<br>
&ensp; Bji is transfered to the next below P, Pi+1j (i < 3, j > 0)<br>

Those 0 values are added to synchronise the clock cycle for inputs because each PE computes one partial of final result element per one cycle. Therefor, on the first cycle, a11 and b11 are inserted to calculate, the two 0 values of second row(P21) and second column(P12) are inserted too to reserve(wait for a11 and b11 coming on the next cycle). On the second cycle, a12 and b21 are inserted to calculate, the two 0 values of third row and column are inserted too to reserve(wait for a12 and b21 coming on the next cycle), a11 is transfered to P12 and b11 is transfered to P21. The same manner for next following cycles.

## PE Architecture and Symbol

<figure>
    <img src="/images/pe.png"
         alt="PE Architecture">
    <figcaption>Figure: PE Architecture</figcaption>
</figure>


## Top module Architecture and Symbol
<figure>
    <img src="/images/top.png"
         alt="Top module Architecture">
    <figcaption>Figure: Top module Architecture</figcaption>
</figure>


## Multiplier Hardware Architeture

<figure>
    <img src="/images/multiplier.png"
         alt="Multiplier Hardware Architecture">
    <figcaption>Figure: Multiplier Hardware Architecture</figcaption>
</figure>

## Floating-point Multiplier

<figure>
    <img src="/images/floating-point-multiplier.png"
         alt="Floating-point Multiplier Hardware Architecture">
    <figcaption>Figure: Floating-point Multiplier Hardware Architecture</figcaption>
</figure>