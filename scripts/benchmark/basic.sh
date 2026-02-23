#!/bin/bash

SCRIPTS_DIR="/scripts"

echo "=============================================="
echo "       rmf Basic Benchmark Suite"
echo "=============================================="
echo "System: $(uname -a)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

run_benchmark() {
	local name=$1
	local files=$2
	local dir_count=$3

	echo ""
	echo "=========================================="
	echo "Benchmark: $name ($files files)"
	echo "=========================================="
	echo ""

	echo "--- rmf ---"
	$SCRIPTS_DIR/generate-test-data.sh $files $dir_count /test/bench_basic
	/usr/bin/time -v rmf --quiet /test/bench_basic 2>&1 | grep -E "(Elapsed|Maximum resident)"
	echo ""
}

run_benchmark "Tiny (100 files)" 100 10
run_benchmark "Small (1k files)" 1000 100
run_benchmark "Medium (10k files)" 10000 100
run_benchmark "Large (50k files)" 50000 100
run_benchmark "Very Large (100k files)" 100000 100
run_benchmark "Extremely Large (1M files)" 1000000 1000

echo "=============================================="
echo "              Benchmark Complete"
echo "=============================================="
