fixture() {
    FIXTURE_ROOT="$BATS_TEST_DIRNAME/fixtures/$1"
}

setup() {
    ORIGINAL_PWD=$PWD
    ORIGINAL_PATH=$PATH
    ORIGINAL_HOME=$HOME
    export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    cd $ORIGINAL_PWD
    rm -rf "${TEST_TMPDIR}"
    unset TEST_TMPDIR
    export PATH=$ORIGINAL_PATH
    export HOME=$ORIGINAL_HOME
}
