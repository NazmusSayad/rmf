#!/bin/bash

SCRIPTS_DIR="/scripts"

echo "=============================================="
echo "       rmf vs rm -rf Benchmark Suite"
echo "       Powered by hyperfine"
echo "=============================================="
echo "System: $(uname -a)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

run_hyperfine_benchmark() {
	local name=$1
	local files=$2

	echo ""
	echo "=========================================="
	echo "Benchmark: $name ($files files)"
	echo "=========================================="
	echo ""

	hyperfine \
		--warmup 1 \
		--runs 5 \
		--prepare "$SCRIPTS_DIR/generate-test-data.sh $files /test/bench" \
		--show-output \
		"rmf --force --quiet /test/bench" \
		"rm -rf /test/bench"

	echo ""
}

run_single_benchmark() {
	local name=$1
	local files=$2

	echo ""
	echo "=========================================="
	echo "Benchmark: $name ($files files)"
	echo "=========================================="
	echo ""

	echo "--- rmf ---"
	$SCRIPTS_DIR/generate-test-data.sh $files /test/bench_rmf
	/usr/bin/time -v rmf --force --quiet /test/bench_rmf 2>&1 | grep -E "(Elapsed|Maximum resident)"

	echo ""
	echo "--- rm -rf ---"
	$SCRIPTS_DIR/generate-test-data.sh $files /test/bench_rm
	/usr/bin/time -v rm -rf /test/bench_rm 2>&1 | grep -E "(Elapsed|Maximum resident)"
	echo ""
}

if [ "$1" = "--hyperfine" ]; then
	echo "Using hyperfine for statistical benchmarking..."
	run_hyperfine_benchmark "Small" 1000
	run_hyperfine_benchmark "Medium" 10000
	run_hyperfine_benchmark "Large" 50000
	run_hyperfine_benchmark "Very_Large" 100000
else
	run_single_benchmark "Tiny" 100
	run_single_benchmark "Small" 1000
	run_single_benchmark "Medium" 10000
	run_single_benchmark "Large" 50000
	run_single_benchmark "Very Large" 100000
fi

echo "=============================================="
echo "              Benchmark Complete"
echo "=============================================="
