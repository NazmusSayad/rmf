#!/bin/bash

echo "=============================================="
echo "       rmf Real-World Benchmark"
echo "=============================================="
echo "System: $(uname -a)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

run_npm_benchmark() {
	echo ""
	echo "=========================================="
	echo "Real-World: node_modules (20+ packages)"
	echo "=========================================="
	echo ""

	mkdir -p /test/realworld
	cd /test/realworld
	npm init -y --silent --force

	echo "Installing packages: express lodash typescript react webpack next vue axios prettier eslint jest mocha chai redux lodash-es ramda immutable moment date-fns underscore jquery aws-sdk firebase @tensorflow/tfjs monaco-editor antd react-icons"
	npm install express lodash typescript react webpack next vue axios prettier eslint jest mocha chai redux lodash-es ramda immutable moment date-fns underscore jquery aws-sdk firebase @tensorflow/tfjs monaco-editor antd react-icons --silent --force

	local file_count=$(find node_modules -type f | wc -l)
	local dir_count=$(find node_modules -type d | wc -l)
	echo "Installed: $file_count files in $dir_count directories"
	echo ""

	echo "--- rmf ---"
	/usr/bin/time -v rmf --quiet /test/realworld/node_modules 2>&1 | grep -E "(Elapsed|Maximum resident)"

	npm install express lodash typescript react webpack next vue axios prettier eslint jest mocha chai redux lodash-es ramda immutable moment date-fns underscore jquery aws-sdk firebase @tensorflow/tfjs monaco-editor antd react-icons --silent --force

	echo ""
	echo "--- rm -rf ---"
	/usr/bin/time -v rm -rf /test/realworld/node_modules 2>&1 | grep -E "(Elapsed|Maximum resident)"

	rm -rf /test/realworld
	echo ""
}

run_npm_benchmark

echo "=============================================="
echo "         Real-World Benchmark Complete"
echo "=============================================="
