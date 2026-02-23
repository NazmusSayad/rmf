#!/bin/bash
set -e

TOTAL_FILES=${1:-100000}
DIR_COUNT=${2:-100}
BASE_DIR=${3:-"/test/data"}

echo "Generating $TOTAL_FILES files across $DIR_COUNT directories..."

FILES_PER_DIR=$((TOTAL_FILES / DIR_COUNT))

for i in $(seq 1 $DIR_COUNT); do
	dir="$BASE_DIR/dir_$(printf '%04d' $i)"
	mkdir -p "$dir"

	for j in $(seq 1 $FILES_PER_DIR); do
		touch "$dir/file_$(printf '%08d' $j).txt"
	done &
done

wait
echo "Done. Created approximately $TOTAL_FILES files in $BASE_DIR"
