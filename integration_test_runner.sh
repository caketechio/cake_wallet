#!/bin/bash
export DESKTOP_FORCE_MOBILE="Y"

declare -a targets
declare -a passed_tests
declare -a failed_tests

# Collect all Dart test files in the integration_test directory
while IFS= read -r -d $'\0' file; do
  targets+=("$file")
done < <(find integration_test/test_suites -name "*.dart" -type f -print0)

# Run each test and collect results
for target in "${targets[@]}"
do
    if [[ "x$REMOVE_DATA_DIRECTORY" == "xY" ]];
    then
        rm -rf ~/.local/share/com.example.cake_wallet ~/Documents/cake_wallet
    fi
    echo "Running test: $target"
    if flutter drive \
      --driver=test_driver/integration_test.dart \
      --target="$target"; then
        echo "✅ Test passed: $target"
        passed_tests+=("$target")
    else
        echo "❌ Test failed: $target"
        failed_tests+=("$target")
    fi
done

# Provide a summary of test results
echo -e "\n===== Test Summary ====="
if [ ${#passed_tests[@]} -gt 0 ]; then
    echo "✅ Passed Tests:"
    for test in "${passed_tests[@]}"; do
        echo "  - $test"
    done
fi

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo -e "\n❌ Failed Tests:"
    for test in "${failed_tests[@]}"; do
        echo "  - $test"
    done
    # Exit with a non-zero status to indicate failure
    exit 1
else
    echo -e "\n🎉 All tests passed successfully!"
fi
