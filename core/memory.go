package main

import "runtime"

type MemoryInfo struct {
	Sys          uint64 `json:"sys"`
	HeapObjects  uint64 `json:"heapObjects"`
	HeapUnused   uint64 `json:"heapUnused"`
	HeapIdle     uint64 `json:"heapIdle"`
	HeapReleased uint64 `json:"heapReleased"`
	Stacks       uint64 `json:"stacks"`
	Metadata     uint64 `json:"metadata"`
	GC           uint64 `json:"gc"`
	Other        uint64 `json:"other"`
}

func memoryInfoFromStats(stats runtime.MemStats) MemoryInfo {
	return MemoryInfo{
		Sys:          stats.Sys,
		HeapObjects:  stats.HeapAlloc,
		HeapUnused:   stats.HeapInuse - stats.HeapAlloc,
		HeapIdle:     stats.HeapIdle - stats.HeapReleased,
		HeapReleased: stats.HeapReleased,
		Stacks:       stats.StackSys,
		Metadata:     stats.MSpanSys + stats.MCacheSys + stats.BuckHashSys,
		GC:           stats.GCSys,
		Other:        stats.OtherSys,
	}
}
