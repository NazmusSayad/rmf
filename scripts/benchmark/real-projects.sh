#!/bin/bash

echo "=============================================="
echo "       rmf Real-World Benchmark"
echo "=============================================="
echo "System: $(uname -a)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

PROJECTS=(
	"webpack/webpack"
	"facebook/react"
	"metabase/metabase"
	"babel/babel"
)

run_project_benchmark() {
	local project=$1
	local project_name=$(basename $project)
	local work_dir="/test/realworld/${project_name}"

	echo ""
	echo "=========================================="
	echo "Project: $project_name"
	echo "=========================================="
	echo ""

	mkdir -p /test/realworld
	rm -rf "$work_dir"

	echo "Cloning $project..."
	git clone --depth 1 "https://github.com/${project}.git" "$work_dir"
	cd "$work_dir"

	echo "Installing dependencies..."
	npm install --silent --force 2>/dev/null || npm install --silent 2>/dev/null || npm install 2>/dev/null

	local file_count=$(find node_modules -type f 2>/dev/null | wc -l)
	local dir_count=$(find node_modules -type d 2>/dev/null | wc -l)
	echo "Installed: $file_count files in $dir_count directories"
	echo ""

	echo "--- rmf ---"
	/usr/bin/time -v rmf --quiet "$work_dir/node_modules" 2>&1 | grep -E "(Elapsed|Maximum resident)"

	echo "Reinstalling dependencies..."
	npm install --silent --force 2>/dev/null || npm install --silent 2>/dev/null || npm install 2>/dev/null

	echo ""
	echo "--- rm -rf ---"
	/usr/bin/time -v rm -rf "$work_dir/node_modules" 2>&1 | grep -E "(Elapsed|Maximum resident)"

	rm -rf "$work_dir"
	echo ""
}

for project in "${PROJECTS[@]}"; do
	run_project_benchmark "$project"
done

rm -rf /test/realworld

echo "=============================================="
echo "         Real-World Benchmark Complete"
echo "=============================================="
