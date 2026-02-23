#!/bin/bash

SCRIPTS_DIR="/scripts"

echo "=============================================="
echo "       rmf --force Benchmark Suite"
echo "=============================================="
echo "System: $(uname -a)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

run_benchmark() {
	local name=$1
	local files=$2

	echo ""
	echo "=========================================="
	echo "Benchmark: $name ($files files)"
	echo "=========================================="
	echo ""

	echo "--- rmf --force ---"
	$SCRIPTS_DIR/generate-test-data.sh $files /test/bench_rmf_force
	/usr/bin/time -v rmf --force --quiet /test/bench_rmf_force 2>&1 | grep -E "(Elapsed|Maximum resident)"

}

run_benchmark "Tiny" 100
run_benchmark "Small" 1000
run_benchmark "Medium" 10000
run_benchmark "Large" 50000
run_benchmark "Very Large" 100000
run_benchmark "Extremely Large" 1000000

echo "=============================================="
echo "              Benchmark Complete"
echo "=============================================="
