# Matrix Multiplier

## Objectives
The multiplication of matrices is a very common operation in engineering and scientific problems. The sequential implementation of this operation is very time consuming for large matrices; the brute-force solution results in computation time O(n3), for n x n matrices. For this reason, several parallel algorithms have been developed to solve this problem more efficiently. Here, a simple parallel algorithm is presented for this problem and a "hardwired" (actually, systolic-array) implementation of the algorithm becomes our objective.

## Algorithm
In this illustraion, we are gonna take two 4x4 matrices as example.
[Systolic-array visulization](https://www.youtube.com/watch?v=cmy7LBaWuZ8)

<figure>
    <img src="/images/systolic array.png"
         alt="Systolic-array block diagram">
    <figcaption>Figure: Systolic-array block diagram</figcaption>
</figure>

Each PE in the systolic array computes each element of the final result matrix.

### How does it work?
For each Pij/cycle:
&ensp; Pij = accumualtion of product of Aij x Bji
&ensp; Aij is transfered to the next right P, Pij+1 (j < 4, i > 0)
&ensp; Bji is transfered to the next below P, Pi+1j (i < 4, j > 0)

Those 0 values are added to synchronise the clock cycle for inputs because each PE computes one partial of final result element per one cycle. Therefor, on the first cycle, a14 and b41 are inserted to calculate, the two 0 values of second row and second column are inserted too to reserve(wait for a14 and b41 coming on the next cycle). On the second cycle, a24 and b42 are inserted to calculate, the two 0 values of third row and column are inserted too to reserve(wait for a24 and b42 coming on the next cycle), a14 is transfered to P12 and b41 is transfered to P21. The same manner for next following cycles.

## PE Architecture

<figure>
    <img src="/images/pe.png"
         alt="PE Architecture">
    <figcaption>Figure: PE architecture</figcaption>
</figure>

