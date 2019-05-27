#!/bin/bash


for i in {1..1000}
do
    ./kernels 3 2097152 4096 >> secuencial.time
done
