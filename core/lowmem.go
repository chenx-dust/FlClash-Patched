//go:build with_low_memory

package main

import "runtime/debug"

const lowMemoryLimit = 32 * 1024 * 1024

func init() {
	debug.SetMemoryLimit(lowMemoryLimit)
}
