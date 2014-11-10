shared_test_count=`ls xfstests/tests/shared/[0-9][0-9][0-9] |wc -l`
generic_test_count=`ls xfstests/tests/generic/[0-9][0-9][0-9] |wc -l`
total_test_count=$((generic_test_count + shared_test_count))
ran_test_count=`cat xfstests/results/check.log | grep Failed|awk '{print $4;}'`
failed_test_count=`cat xfstests/results/check.log | grep Failed|awk '{print $2;}'`
passed_test_count=$((ran_test_count - failed_test_count))
not_run_test_count=$((total_test_count - ran_test_count))

echo "Passed : "$passed_test_count
echo "Failed : "$failed_test_count
echo "Not run : "$not_run_test_count
