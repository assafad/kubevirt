package openapi_test

import (
	"testing"

	"kubevirt.io/client-go/testutils"
)

func TestOpenapi(t *testing.T) {
	testutils.KubeVirtTestSuiteSetup(t, "Openapi Suite")
}
