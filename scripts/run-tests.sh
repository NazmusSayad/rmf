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
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t1
rmf --quiet /test/t1
if [ ! -d "/test/t1" ]; then
	pass "Small directory deleted"
else
	fail "Small directory not deleted"
fi

echo ""
echo "Test 2: Delete medium directory"
$SCRIPTS_DIR/generate-test-data.sh 5000 /test/t2
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
if echo "$output" | grep -q "Refusing to delete protected path"; then
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
if echo "$output" | grep -q "Refusing to delete protected path" && [ $exit_code -eq 2 ]; then
	pass "--force does not bypass / protection (intentional)"
else
	fail "Unexpected behavior with --force on /"
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
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t12
output=$(rmf --threads 4 /test/t12 2>&1)
if echo "$output" | grep -q "Using 4 thread"; then
	pass "Custom thread count applied"
else
	fail "Custom thread count not applied"
fi

echo ""
echo "Test 13: Thread count clamping (max 256)"
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t13
output=$(rmf --threads 999 /test/t13 2>&1)
if echo "$output" | grep -q "Using 256 thread"; then
	pass "Thread count clamped to 256"
else
	fail "Thread count not clamped"
fi

echo ""
echo "Test 14: Thread count clamping (min 1)"
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t14
output=$(rmf --threads 0 /test/t14 2>&1)
if echo "$output" | grep -q "Using 1 thread"; then
	pass "Thread count clamped to 1"
else
	fail "Thread count not clamped to minimum"
fi

echo ""
echo "--- Progress Output Tests ---"

echo "Test 15: Progress output shown by default"
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t15
output=$(rmf /test/t15 2>&1)
if echo "$output" | grep -q "files deleted\|Using"; then
	pass "Progress output shown"
else
	fail "Progress output not shown"
fi

echo ""
echo "Test 16: Quiet mode suppresses output"
$SCRIPTS_DIR/generate-test-data.sh 100 /test/t16
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
