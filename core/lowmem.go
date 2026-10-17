//go:build with_low_memory

package core

import "runtime/debug"

// The Network Extension is killed outright past its memory limit, so the
// collector has to start long before the heap gets near it.
const lowMemoryLimit = 32 * 1024 * 1024

func init() {
	debug.SetMemoryLimit(lowMemoryLimit)
}
