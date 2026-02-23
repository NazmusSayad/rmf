#!/bin/bash

SCRIPTS_DIR="/scripts"

echo "=============================================="
echo "       rmf vs rm -rf Benchmark Suite"
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

	echo "--- rmf ---"
	$SCRIPTS_DIR/generate-test-data.sh $files 100 /test/bench_rmf
	/usr/bin/time -v rmf --quiet /test/bench_rmf 2>&1 | grep -E "(Elapsed|Maximum resident)"

	echo ""
	echo "--- rm -rf ---"
	$SCRIPTS_DIR/generate-test-data.sh $files 100 /test/bench_rm
	/usr/bin/time -v rm -rf /test/bench_rm 2>&1 | grep -E "(Elapsed|Maximum resident)"
	echo ""
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
