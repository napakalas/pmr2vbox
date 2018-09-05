#!/usr/bin/env bats

load test_helper

. lib/aws

@test "s3_to_ec2_snapshot basic" {
    fixture "aws_ec2_import-snapshot"
    export PATH=$FIXTURE_ROOT:$PATH
    s3_to_ec2_snapshot
    [ "${IMPORT_SNAPSHOT_TASK}" = 'import-snap-0123456789abcdef0' ]
}

@test "import_monitoring failed" {
    fixture "aws_ec2_describe-import-snapshot-tasks"
    IMPORT_SNAPSHOT_TASK=''
    run monitor_import
    [ "${status}" = 2 ]
}

@test "import_monitoring running non-terminated" {
    # this always produce the in progress status
    fixture "aws_ec2_describe-import-snapshot-tasks"
    export PATH=$FIXTURE_ROOT:$PATH
    IMPORT_SNAPSHOT_TASK='import-snap-0123456789abcdef0'
    run monitor_import
    [ "${status}" = 1 ]
}

@test "import_monitoring running done" {
    fixture "aws_ec2_describe-import-snapshot-done"
    export PATH=$FIXTURE_ROOT:$PATH
    IMPORT_SNAPSHOT_TASK='import-snap-0123456789abcdef0'
    # run directly to get the variable assignment
    monitor_import
    [ "${EC2_SNAPSHOT}" = "snap-fedcba98765432100" ]
}

# vim: set filetype=sh:
