//go:build !(ios && cgo)

package main

func memoryFootprint() uint64 {
	return 0
}
