#!/bin/bash
export DESKTOP_FORCE_MOBILE="Y"

declare -a targets
declare -a passed_tests
declare -a failed_tests

# Max inactivity duration in seconds before marking the test as failed
MAX_INACTIVITY=180 # Adjust as needed (e.g., 300 seconds = 5 minutes)

# Function to monitor test output and kill the process if inactive
monitor_test() {
    local test_pid=$1
    local log_file=$2
    local start_time=$(date +%s)

    while true; do
        sleep 10

        # Check if the process is still running
        if ! kill -0 $test_pid 2>/dev/null; then
            break
        fi

        # Check for log activity
        local last_modified=$(stat -c %Y "$log_file")
        local current_time=$(date +%s)
        if (( current_time - last_modified > MAX_INACTIVITY )); then
            echo "❌ Test hung due to inactivity, terminating..."
            kill -9 $test_pid
            return 1
        fi
    done

    return 0
}

# Collect all Dart test files in the integration_test directory
while IFS= read -r -d $'\0' file; do
  targets+=("$file")
done < <(find integration_test/test_suites -name "*.dart" -type f -print0)

# Run each test and collect results
for target in "${targets[@]}"
do
    if [[ "x$REMOVE_DATA_DIRECTORY" == "xY" ]]; then
        rm -rf ~/.local/share/com.example.cake_wallet ~/Documents/cake_wallet
    fi
    echo "Running test: $target"

    # Temporary log file to track activity
    log_file=$(mktemp)

    # Run the test in the background and log output
    flutter drive \
        --driver=test_driver/integration_test.dart \
        --target="$target" \
        --dart-define=CI_BUILD=true \
        >"$log_file" 2>&1 &
    test_pid=$!

    # Monitor the test for inactivity
    if monitor_test $test_pid "$log_file"; then
        echo "✅ Test passed: $target"
        passed_tests+=("$target")
    else
        echo "❌ Test failed or hung: $target"
        failed_tests+=("$target")
    fi

    # Clean up log file
    rm -f "$log_file"
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
