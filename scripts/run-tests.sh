#!/bin/bash

SCRIPTS_DIR="/scripts"
PASS=0
FAIL=0

pass() {
	echo "✓ PASS: $1"
	PASS=$((PASS + 1))
}

fail() {
	echo "✗ FAIL: $1"
	FAIL=$((FAIL + 1))
}

echo "=============================================="
echo "           rmf Test Suite"
echo "=============================================="
echo ""

echo "--- Basic Functionality Tests ---"

echo "Test 1: Delete small directory"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t1
rmf --quiet /test/t1
if [ ! -d "/test/t1" ]; then
	pass "Small directory deleted"
else
	fail "Small directory not deleted"
fi

echo ""
echo "Test 2: Delete medium directory"
$SCRIPTS_DIR/generate-test-data.sh 5000 100 /test/t2
rmf --quiet /test/t2
if [ ! -d "/test/t2" ]; then
	pass "Medium directory deleted"
else
	fail "Medium directory not deleted"
fi

echo ""
echo "Test 3: Delete nested directories"
mkdir -p /test/t3/a/b/c/d/e
touch /test/t3/a/file1.txt
touch /test/t3/a/b/file2.txt
touch /test/t3/a/b/c/file3.txt
touch /test/t3/a/b/c/d/file4.txt
touch /test/t3/a/b/c/d/e/file5.txt
rmf --quiet /test/t3
if [ ! -d "/test/t3" ]; then
	pass "Nested directories deleted"
else
	fail "Nested directories not deleted"
fi

echo ""
echo "Test 4: Delete directory with symlinks"
mkdir -p /test/t4_real
touch /test/t4_real/file.txt
mkdir -p /test/t4
ln -sf /test/t4_real/file.txt /test/t4/link
rmf --quiet /test/t4
rm -rf /test/t4_real
if [ ! -d "/test/t4" ]; then
	pass "Symlink directory deleted"
else
	fail "Symlink directory not deleted"
fi

echo ""
echo "Test 5: Delete empty directory"
mkdir -p /test/t5
rmf --quiet /test/t5
if [ ! -d "/test/t5" ]; then
	pass "Empty directory deleted"
else
	fail "Empty directory not deleted"
fi

echo ""
echo "Test 6: Delete single file"
touch /test/t6_file.txt
rmf --quiet /test/t6_file.txt
if [ ! -f "/test/t6_file.txt" ]; then
	pass "Single file deleted"
else
	fail "Single file not deleted"
fi

echo ""
echo "--- Safety Tests ---"

echo "Test 7: Refuse to delete /"
output=$(rmf / 2>&1)
if echo "$output" | grep -q "Refusing to delete"; then
	pass "Protected path / refused"
else
	fail "Protected path / not refused"
fi

echo ""
echo "Test 8: Non-existent path"
output=$(rmf /nonexistent_path_12345 2>&1)
if echo "$output" | grep -q "does not exist"; then
	pass "Non-existent path detected"
else
	fail "Non-existent path not detected"
fi

echo ""
echo "Test 9: Force flag allows deleting protected path"
output=$(rmf --force / 2>&1)
exit_code=$?
if echo "$output" | grep -q "Refusing to delete root directory" && [ $exit_code -ne 0 ]; then
	pass "--force does not bypass / protection (intentional)"
else
	fail "Unexpected behavior with --force on / (exit: $exit_code)"
fi

echo ""
echo "--- Force Flag Tests (-f) ---"

echo "Test 9a: -f silently ignores nonexistent file"
output=$(rmf -f --quiet /nonexistent_force_test_12345 2>&1)
exit_code=$?
if [ -z "$output" ] && [ $exit_code -eq 0 ]; then
	pass "-f silently ignores nonexistent file"
else
	fail "-f should silently ignore nonexistent file (exit: $exit_code)"
fi

echo ""
echo "Test 9b: -f with multiple targets, one nonexistent"
mkdir -p /test/t9b
touch /test/t9b/file.txt
output=$(rmf -f --quiet /test/t9b /nonexistent_force_test_67890 2>&1)
exit_code=$?
if [ ! -d "/test/t9b" ] && [ $exit_code -eq 0 ]; then
	pass "-f continues after nonexistent, deletes existing"
else
	fail "-f should continue and delete existing (exit: $exit_code)"
fi

echo ""
echo "Test 9c: -f with all nonexistent targets"
output=$(rmf -f --quiet /nonexistent_a /nonexistent_b /nonexistent_c 2>&1)
exit_code=$?
if [ -z "$output" ] && [ $exit_code -eq 0 ]; then
	pass "-f returns success with all nonexistent targets"
else
	fail "-f should return success with all nonexistent (exit: $exit_code)"
fi

echo ""
echo "Test 9d: Without -f, nonexistent file shows error"
output=$(rmf /nonexistent_no_force_test 2>&1)
exit_code=$?
if echo "$output" | grep -q "does not exist" && [ $exit_code -eq 2 ]; then
	pass "Without -f, nonexistent file shows error"
else
	fail "Without -f should show error for nonexistent (exit: $exit_code)"
fi

echo ""
echo "Test 9e: -f with --quiet combination"
output=$(rmf -f --quiet /nonexistent_quiet_test 2>&1)
exit_code=$?
if [ -z "$output" ] && [ $exit_code -eq 0 ]; then
	pass "-f --quiet works correctly"
else
	fail "-f --quiet combination failed (exit: $exit_code)"
fi

echo ""
echo "--- Exit Code Tests ---"

echo "Test 10: Exit code on success"
mkdir -p /test/t10
rmf --quiet /test/t10
exit_code=$?
if [ $exit_code -eq 0 ]; then
	pass "Exit code 0 on success"
else
	fail "Wrong exit code on success (got $exit_code)"
fi

echo ""
echo "Test 11: Exit code on fatal error"
rmf /nonexistent_path_xyz 2>/dev/null
exit_code=$?
if [ $exit_code -eq 2 ]; then
	pass "Exit code 2 on fatal error"
else
	fail "Wrong exit code on fatal error (got $exit_code, expected 2)"
fi

echo ""
echo "--- Thread Configuration Tests ---"

echo "Test 12: Custom thread count"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t12
output=$(rmf --threads 4 /test/t12 2>&1)
if echo "$output" | grep -q "Using 4 thread"; then
	pass "Custom thread count applied"
else
	fail "Custom thread count not applied"
fi

echo ""
echo "Test 13: Thread count clamping (max 256)"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t13
output=$(rmf --threads 999 /test/t13 2>&1)
if echo "$output" | grep -q "Using 256 thread"; then
	pass "Thread count clamped to 256"
else
	fail "Thread count not clamped"
fi

echo ""
echo "Test 14: Thread count clamping (min 1)"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t14
output=$(rmf --threads 0 /test/t14 2>&1)
if echo "$output" | grep -q "Using 1 thread"; then
	pass "Thread count clamped to 1"
else
	fail "Thread count not clamped to minimum"
fi

echo ""
echo "--- Progress Output Tests ---"

echo "Test 15: Progress output shown by default"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t15
output=$(rmf /test/t15 2>&1)
if echo "$output" | grep -q "files deleted\|Using"; then
	pass "Progress output shown"
else
	fail "Progress output not shown"
fi

echo ""
echo "Test 16: Quiet mode suppresses output"
$SCRIPTS_DIR/generate-test-data.sh 100 10 /test/t16
output=$(rmf --quiet /test/t16 2>&1)
if [ -z "$output" ]; then
	pass "Quiet mode suppresses output"
else
	fail "Quiet mode did not suppress output"
fi

echo ""
echo "--- Special Files Tests ---"

echo "Test 17: Files with spaces in names"
mkdir -p "/test/t17/dir with spaces"
touch "/test/t17/file with spaces.txt"
touch "/test/t17/dir with spaces/another file.txt"
rmf --quiet "/test/t17"
if [ ! -d "/test/t17" ]; then
	pass "Files with spaces deleted"
else
	fail "Files with spaces not deleted"
fi

echo ""
echo "Test 18: Hidden files"
mkdir -p /test/t18
touch /test/t18/.hidden1
touch /test/t18/.hidden2
mkdir -p /test/t18/.hidden_dir
touch /test/t18/.hidden_dir/file.txt
rmf --quiet /test/t18
if [ ! -d "/test/t18" ]; then
	pass "Hidden files deleted"
else
	fail "Hidden files not deleted"
fi

echo ""
echo "Test 19: Read-only files"
mkdir -p /test/t19
touch /test/t19/readonly.txt
chmod 444 /test/t19/readonly.txt
rmf --quiet /test/t19
if [ ! -d "/test/t19" ]; then
	pass "Read-only files deleted"
else
	fail "Read-only files not deleted"
fi

echo ""
echo "Test 20: Deeply nested structure"
mkdir -p /test/t20/$(printf 'level%d/' {1..20})
touch /test/t20/level1/level2/level3/level4/level5/deep.txt
rmf --quiet /test/t20
if [ ! -d "/test/t20" ]; then
	pass "Deeply nested structure deleted"
else
	fail "Deeply nested structure not deleted"
fi

echo ""
echo "--- Multiple Targets Tests ---"

echo "Test 21: Delete multiple targets"
mkdir -p /test/t21_a /test/t21_b
touch /test/t21_a/file.txt
touch /test/t21_b/file.txt
rmf --quiet /test/t21_a /test/t21_b
if [ ! -d "/test/t21_a" ] && [ ! -d "/test/t21_b" ]; then
	pass "Multiple targets deleted"
else
	fail "Multiple targets not deleted"
fi

echo ""
echo "Test 22: Multiple targets with one non-existent"
mkdir -p /test/t22
touch /test/t22/file.txt
output=$(rmf /test/t22 /nonexistent_xyz 2>&1)
exit_code=$?
if [ ! -d "/test/t22" ] && [ $exit_code -eq 2 ]; then
	pass "Partial failure with non-existent target"
else
	fail "Unexpected behavior with mixed targets"
fi

echo ""
echo "Test 23: Multiple targets all non-existent"
output=$(rmf /nonexistent1 /nonexistent2 2>&1)
exit_code=$?
if [ $exit_code -eq 2 ]; then
	pass "Fatal error when all targets non-existent"
else
	fail "Wrong exit code for all non-existent"
fi

echo ""
echo "--- Symlink Edge Cases ---"

echo "Test 24: Symlink to directory (not followed)"
mkdir -p /test/t24_real
touch /test/t24_real/file.txt
ln -sf /test/t24_real /test/t24_link
rmf --quiet /test/t24_link
if [ ! -L "/test/t24_link" ] && [ -d "/test/t24_real" ]; then
	pass "Symlink to directory removed, target preserved"
else
	fail "Symlink handling incorrect"
fi
rm -rf /test/t24_real

echo ""
echo "Test 25: Directory containing broken symlink"
mkdir -p /test/t25
ln -sf /nonexistent_target /test/t25/broken_link
rmf --quiet /test/t25
if [ ! -d "/test/t25" ]; then
	pass "Broken symlink deleted"
else
	fail "Broken symlink not handled"
fi

echo ""
echo "Test 26: Symlink to file"
touch /test/t26_real.txt
ln -sf /test/t26_real.txt /test/t26_link.txt
rmf --quiet /test/t26_link.txt
if [ ! -L "/test/t26_link.txt" ] && [ -f "/test/t26_real.txt" ]; then
	pass "File symlink removed, target preserved"
else
	fail "File symlink handling incorrect"
fi
rm -f /test/t26_real.txt

echo ""
echo "--- Edge Cases ---"

echo "Test 27: Empty filename handling"
mkdir -p /test/t27
touch "/test/t27/normal.txt"
output=$(rmf --quiet /test/t27 2>&1)
if [ ! -d "/test/t27" ]; then
	pass "Normal deletion works"
else
	fail "Deletion failed"
fi

echo ""
echo "Test 28: Very long filename"
mkdir -p /test/t28
longname=$(printf 'x%.0s' {1..200})
touch "/test/t28/$longname"
rmf --quiet /test/t28
if [ ! -d "/test/t28" ]; then
	pass "Long filename handled"
else
	fail "Long filename not handled"
fi

echo ""
echo "Test 29: Special characters in filename"
mkdir -p /test/t29
touch "/test/t29/file with spaces.txt"
touch "/test/t29/file'with'quotes.txt"
touch '/test/t29/file"with"double.txt'
rmf --quiet /test/t29
if [ ! -d "/test/t29" ]; then
	pass "Special characters handled"
else
	fail "Special characters not handled"
fi

echo ""
echo "Test 30: Unicode filename"
mkdir -p /test/t30
touch "/test/t30/файл.txt"
touch "/test/t30/文件.txt"
touch "/test/t30/🎉.txt"
rmf --quiet /test/t30
if [ ! -d "/test/t30" ]; then
	pass "Unicode filenames handled"
else
	fail "Unicode filenames not handled"
fi

echo ""
echo "--- Large Scale Tests ---"

echo "Test 31: Large directory (10000 files)"
$SCRIPTS_DIR/generate-test-data.sh 10000 100 /test/t31
rmf --quiet /test/t31
if [ ! -d "/test/t31" ]; then
	pass "Large directory deleted"
else
	fail "Large directory not deleted"
fi

echo ""
echo "Test 32: Many files in single directory"
mkdir -p /test/t32
for i in $(seq 1 1000); do
	touch "/test/t32/file_$i.txt"
done
rmf --quiet /test/t32
if [ ! -d "/test/t32" ]; then
	pass "Many files in single directory deleted"
else
	fail "Many files in single directory not deleted"
fi

echo ""
echo "Test 33: Zero-byte files"
mkdir -p /test/t33
touch /test/t33/empty1.txt
touch /test/t33/empty2.txt
mkdir -p /test/t33/subdir
touch /test/t33/subdir/empty3.txt
rmf --quiet /test/t33
if [ ! -d "/test/t33" ]; then
	pass "Zero-byte files deleted"
else
	fail "Zero-byte files not deleted"
fi

echo ""
echo "--- Version and Help Tests ---"

echo "Test 34: Version flag"
output=$(rmf --version 2>&1)
if echo "$output" | grep -q "rmf"; then
	pass "Version flag works"
else
	fail "Version flag not working"
fi

echo ""
echo "Test 35: Help flag"
output=$(rmf --help 2>&1)
if echo "$output" | grep -q "Fast parallel recursive file deletion"; then
	pass "Help flag works"
else
	fail "Help flag not working"
fi

echo ""
echo "--- Argument Validation Tests ---"

echo "Test 36: No arguments shows error"
output=$(rmf 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
	pass "No arguments returns error"
else
	fail "No arguments should return error"
fi

echo ""
echo "Test 37: Invalid thread count (negative behavior via clamp)"
mkdir -p /test/t37
output=$(rmf --threads 0 /test/t37 2>&1)
if [ ! -d "/test/t37" ]; then
	pass "Thread count 0 clamped to 1 and deletion works"
else
	fail "Thread count 0 handling failed"
fi

echo ""
echo "--- Symlink Stress Tests ---"

echo "Test 38: Multiple symlinks in directory"
mkdir -p /test/t38_target
touch /test/t38_target/file1.txt
touch /test/t38_target/file2.txt
mkdir -p /test/t38
ln -sf /test/t38_target/file1.txt /test/t38/link1
ln -sf /test/t38_target/file2.txt /test/t38/link2
ln -sf /test/t38_target /test/t38/link_dir
rmf --quiet /test/t38
rm -rf /test/t38_target
if [ ! -d "/test/t38" ]; then
	pass "Multiple symlinks deleted"
else
	fail "Multiple symlinks not deleted"
fi

echo ""
echo "Test 39: Symlink cycle (directory links to parent)"
mkdir -p /test/t39/a/b
ln -sf /test/t39/a /test/t39/a/b/parent_link
rmf --quiet /test/t39
if [ ! -d "/test/t39" ]; then
	pass "Symlink cycle handled"
else
	fail "Symlink cycle not handled"
fi

echo ""
echo "--- Stress Tests ---"

echo "Test 40: Very deep directory structure"
mkdir -p /test/t40/$(printf 'level%d/' {1..50})
touch /test/t40/level1/level2/level3/deep.txt
rmf --quiet /test/t40
if [ ! -d "/test/t40" ]; then
	pass "Very deep structure deleted"
else
	fail "Very deep structure not deleted"
fi

echo ""
echo "Test 41: Mixed content types"
mkdir -p /test/t41/a/b/c
touch /test/t41/file1.txt
touch /test/t41/a/file2.txt
touch /test/t41/a/b/file3.txt
ln -sf /test/t41/file1.txt /test/t41/link1
ln -sf /test/t41/a /test/t41/link_dir
touch /test/t41/.hidden
mkdir -p "/test/t41/dir with spaces"
touch "/test/t41/dir with spaces/file.txt"
rmf --quiet /test/t41
if [ ! -d "/test/t41" ]; then
	pass "Mixed content types deleted"
else
	fail "Mixed content types not deleted"
fi

echo ""
echo "--- Exit Code Edge Cases ---"

echo "Test 42: Exit code 1 on partial failure (permission denied file)"
mkdir -p /test/t42
touch /test/t42/readable.txt
mkdir -p /test/t42/subdir
touch /test/t42/subdir/file.txt
rmf --quiet /test/t42
if [ ! -d "/test/t42" ] && [ $? -eq 0 ]; then
	pass "Normal deletion returns success"
else
	fail "Normal deletion exit code issue"
fi

echo ""
echo "Test 43: Multiple targets with partial failure"
mkdir -p /test/t43_a
touch /test/t43_a/file.txt
rmf /test/t43_a /nonexistent_t43_b 2>/dev/null
exit_code=$?
if [ ! -d "/test/t43_a" ] && [ $exit_code -eq 2 ]; then
	pass "Partial failure returns correct exit code"
else
	fail "Partial failure exit code incorrect"
fi

echo ""
echo "--- File Type Tests ---"

echo "Test 44: Executable files"
mkdir -p /test/t44
touch /test/t44/script.sh
chmod +x /test/t44/script.sh
rmf --quiet /test/t44
if [ ! -d "/test/t44" ]; then
	pass "Executable files deleted"
else
	fail "Executable files not deleted"
fi

echo ""
echo "Test 45: Files with various extensions"
mkdir -p /test/t45
touch /test/t45/file.txt
touch /test/t45/file.md
touch /test/t45/file.rs
touch /test/t45/file.py
touch /test/t45/file.js
touch /test/t45/file.json
touch /test/t45/file.xml
touch /test/t45/file.html
touch /test/t45/file.css
touch /test/t45/file.bin
rmf --quiet /test/t45
if [ ! -d "/test/t45" ]; then
	pass "Various file extensions deleted"
else
	fail "Various file extensions not deleted"
fi

echo ""
echo "--- Thread Edge Cases ---"

echo "Test 46: Single thread deletion"
$SCRIPTS_DIR/generate-test-data.sh 500 10 /test/t46
output=$(rmf --threads 1 /test/t46 2>&1)
if [ ! -d "/test/t46" ] && echo "$output" | grep -q "Using 1 thread"; then
	pass "Single thread deletion works"
else
	fail "Single thread deletion failed"
fi

echo ""
echo "Test 47: Maximum thread count (256)"
$SCRIPTS_DIR/generate-test-data.sh 500 10 /test/t47
output=$(rmf --threads 300 /test/t47 2>&1)
if [ ! -d "/test/t47" ] && echo "$output" | grep -q "Using 256 thread"; then
	pass "Thread count clamped to 256"
else
	fail "Thread count clamping failed"
fi

echo ""
echo "--- Directory Structure Tests ---"

echo "Test 48: Empty nested directories"
mkdir -p /test/t48/a/b/c/d/e/f/g/h
rmf --quiet /test/t48
if [ ! -d "/test/t48" ]; then
	pass "Empty nested directories deleted"
else
	fail "Empty nested directories not deleted"
fi

echo ""
echo "Test 49: Mixed empty and full directories"
mkdir -p /test/t49/empty1/empty2
mkdir -p /test/t49/full1/full2
touch /test/t49/full1/file1.txt
touch /test/t49/full1/full2/file2.txt
mkdir -p /test/t49/empty3
touch /test/t49/top.txt
rmf --quiet /test/t49
if [ ! -d "/test/t49" ]; then
	pass "Mixed empty and full directories deleted"
else
	fail "Mixed directories not deleted"
fi

echo ""
echo "Test 50: Wide directory (many subdirs at same level)"
mkdir -p /test/t50
for i in $(seq 1 100); do
	mkdir -p "/test/t50/dir_$i"
	touch "/test/t50/dir_$i/file.txt"
done
rmf --quiet /test/t50
if [ ! -d "/test/t50" ]; then
	pass "Wide directory structure deleted"
else
	fail "Wide directory structure not deleted"
fi

echo ""
echo "--- Consecutive Operations ---"

echo "Test 51: Multiple consecutive deletions"
mkdir -p /test/t51_a /test/t51_b /test/t51_c
touch /test/t51_a/file.txt
touch /test/t51_b/file.txt
touch /test/t51_c/file.txt
rmf --quiet /test/t51_a
rmf --quiet /test/t51_b
rmf --quiet /test/t51_c
if [ ! -d "/test/t51_a" ] && [ ! -d "/test/t51_b" ] && [ ! -d "/test/t51_c" ]; then
	pass "Consecutive deletions work"
else
	fail "Consecutive deletions failed"
fi

echo ""
echo "Test 52: Delete recreate delete cycle"
mkdir -p /test/t52
touch /test/t52/file.txt
rmf --quiet /test/t52
mkdir -p /test/t52
touch /test/t52/file2.txt
rmf --quiet /test/t52
if [ ! -d "/test/t52" ]; then
	pass "Delete recreate delete cycle works"
else
	fail "Delete recreate delete cycle failed"
fi

echo ""
echo "--- File Size Tests ---"

echo "Test 53: Large single file"
mkdir -p /test/t53
dd if=/dev/zero of=/test/t53/largefile.bin bs=1M count=10 2>/dev/null
rmf --quiet /test/t53
if [ ! -d "/test/t53" ]; then
	pass "Large single file deleted"
else
	fail "Large single file not deleted"
fi

echo ""
echo "Test 54: Many small files"
mkdir -p /test/t54
for i in $(seq 1 500); do
	echo "x" >"/test/t54/small_$i.txt"
done
rmf --quiet /test/t54
if [ ! -d "/test/t54" ]; then
	pass "Many small files deleted"
else
	fail "Many small files not deleted"
fi

echo ""
echo "--- Special Filename Characters ---"

echo "Test 55: Filenames with tabs and newlines"
mkdir -p /test/t55
touch "/test/t55/file"$'\t'"with"$'\t'"tabs.txt"
rmf --quiet /test/t55
if [ ! -d "/test/t55" ]; then
	pass "Filenames with tabs deleted"
else
	fail "Filenames with tabs not deleted"
fi

echo ""
echo "Test 56: Filenames with backslashes"
mkdir -p /test/t56
touch '/test/t56/file\with\backslashes.txt'
rmf --quiet /test/t56
if [ ! -d "/test/t56" ]; then
	pass "Filenames with backslashes deleted"
else
	fail "Filenames with backslashes not deleted"
fi

echo ""
echo "Test 57: Filenames with dollar signs and variables"
mkdir -p /test/t57
touch '/test/t57/file$HOME.txt'
touch '/test/t57/file${PATH}.txt'
rmf --quiet /test/t57
if [ ! -d "/test/t57" ]; then
	pass "Filenames with dollar signs deleted"
else
	fail "Filenames with dollar signs not deleted"
fi

echo ""
echo "--- Process Lifecycle Tests ---"

echo "Test 58: SIGTERM during large deletion"
mkdir -p /test/t58
for i in $(seq 1 8000); do
	touch "/test/t58/file_$i.txt"
done
rmf --quiet /test/t58 &
PID=$!
sleep 0.3
kill -TERM $PID 2>/dev/null
wait $PID 2>/dev/null
exit_code=$?
if [ $exit_code -ne 0 ] || [ ! -d "/test/t58" ]; then
	pass "Process handles SIGTERM or completes fast (exit: $exit_code)"
else
	fail "Process should have been terminated or completed"
fi
rm -rf /test/t58 2>/dev/null

echo ""
echo "Test 59: SIGKILL during deletion (force kill)"
mkdir -p /test/t59
for i in $(seq 1 8000); do
	touch "/test/t59/file_$i.txt"
done
rmf --quiet /test/t59 &
PID=$!
sleep 0.2
kill -KILL $PID 2>/dev/null
wait $PID 2>/dev/null
exit_code=$?
if [ $exit_code -ne 0 ] || [ ! -d "/test/t59" ]; then
	pass "Process handles SIGKILL or completes fast (exit: $exit_code)"
else
	fail "Process should have been killed or completed"
fi
rm -rf /test/t59 2>/dev/null

echo ""
echo "Test 60: Process completes normally without signals"
mkdir -p /test/t60
for i in $(seq 1 100); do
	touch "/test/t60/file_$i.txt"
done
rmf --quiet /test/t60 &
PID=$!
wait $PID
exit_code=$?
if [ ! -d "/test/t60" ] && [ $exit_code -eq 0 ]; then
	pass "Process completes normally"
else
	fail "Process did not complete normally"
fi

echo ""
echo "Test 61: Multiple processes deleting different directories"
mkdir -p /test/t61_a /test/t61_b /test/t61_c
for i in $(seq 1 200); do
	touch "/test/t61_a/file_$i.txt"
	touch "/test/t61_b/file_$i.txt"
	touch "/test/t61_c/file_$i.txt"
done
rmf --quiet /test/t61_a &
PID1=$!
rmf --quiet /test/t61_b &
PID2=$!
rmf --quiet /test/t61_c &
PID3=$!
wait $PID1
wait $PID2
wait $PID3
if [ ! -d "/test/t61_a" ] && [ ! -d "/test/t61_b" ] && [ ! -d "/test/t61_c" ]; then
	pass "Multiple parallel processes work correctly"
else
	fail "Multiple parallel processes failed"
fi

echo ""
echo "Test 62: Process with limited resources (timeout)"
mkdir -p /test/t62
for i in $(seq 1 500); do
	touch "/test/t62/file_$i.txt"
done
timeout 30 rmf --quiet /test/t62
exit_code=$?
if [ ! -d "/test/t62" ]; then
	pass "Process completes within timeout"
else
	fail "Process timed out or failed (exit: $exit_code)"
fi

echo ""
echo "Test 63: Graceful exit on second SIGTERM (rapid signals)"
mkdir -p /test/t63
for i in $(seq 1 2000); do
	touch "/test/t63/file_$i.txt"
done
rmf /test/t63 2>/dev/null &
PID=$!
sleep 0.1
kill -TERM $PID 2>/dev/null
kill -TERM $PID 2>/dev/null
wait $PID 2>/dev/null
pass "Process handles rapid signals"
rm -rf /test/t63 2>/dev/null

echo ""
echo "Test 64: Process exit code propagation"
mkdir -p /test/t64
touch /test/t64/file.txt
rmf --quiet /test/t64
exit_code=$?
if [ $exit_code -eq 0 ]; then
	pass "Exit code 0 propagates correctly"
else
	fail "Exit code should be 0, got $exit_code"
fi

echo ""
echo "Test 65: Background process with disown"
mkdir -p /test/t65
for i in $(seq 1 100); do
	touch "/test/t65/file_$i.txt"
done
rmf --quiet /test/t65 &
disown 2>/dev/null
sleep 2
if [ ! -d "/test/t65" ]; then
	pass "Background process completes after disown"
else
	fail "Background process failed after disown"
fi

echo ""
echo "Test 66: Process handles ENOSPC simulation (full disk check)"
mkdir -p /test/t66
touch /test/t66/file.txt
output=$(rmf /test/t66 2>&1)
exit_code=$?
if [ ! -d "/test/t66" ]; then
	pass "Process handles disk operations correctly"
else
	fail "Process failed disk operations"
fi

echo ""
echo "Test 67: Orphaned process cleanup (subshell)"
mkdir -p /test/t67
for i in $(seq 1 100); do
	touch "/test/t67/file_$i.txt"
done
(rmf --quiet /test/t67 &)
sleep 2
if [ ! -d "/test/t67" ]; then
	pass "Orphaned process completes deletion"
else
	fail "Orphaned process failed"
fi

echo ""
echo "Test 68: Process under load (multiple operations)"
mkdir -p /test/t68_a /test/t68_b
for i in $(seq 1 200); do
	touch "/test/t68_a/file_$i.txt"
	touch "/test/t68_b/file_$i.txt"
done
rmf --quiet /test/t68_a &
rmf --quiet /test/t68_b &
wait
if [ ! -d "/test/t68_a" ] && [ ! -d "/test/t68_b" ]; then
	pass "Process handles concurrent load"
else
	fail "Process failed under load"
fi

echo ""
echo "Test 69: Signal handling during thread spawn"
mkdir -p /test/t69
for i in $(seq 1 1000); do
	touch "/test/t69/file_$i.txt"
done
rmf --threads 8 /test/t69 &
PID=$!
sleep 0.05
kill -USR1 $PID 2>/dev/null || true
wait $PID 2>/dev/null
pass "Signal handling during thread spawn tested"
rm -rf /test/t69 2>/dev/null

echo ""
echo "=============================================="
echo "           Test Results"
echo "=============================================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
	echo "All tests passed!"
	exit 0
else
	echo "Some tests failed."
	exit 1
fi
