package main

import (
	"encoding/json"
	"runtime"
	"testing"
)

func TestMemoryInfoPartitionsSys(t *testing.T) {
	stats := runtime.MemStats{
		Sys:          4096,
		HeapAlloc:    1024,
		HeapInuse:    1280,
		HeapIdle:     2176,
		HeapReleased: 2048,
		StackSys:     256,
		MSpanSys:     32,
		MCacheSys:    32,
		BuckHashSys:  64,
		GCSys:        128,
		OtherSys:     128,
	}
	info := memoryInfoFromStats(stats)
	if info.HeapObjects != 1024 || info.HeapUnused != 256 || info.HeapIdle != 128 || info.Metadata != 128 {
		t.Fatalf("incorrect memory partition: %+v", info)
	}
	sum := info.HeapObjects + info.HeapUnused + info.HeapIdle + info.HeapReleased + info.Stacks + info.Metadata + info.GC + info.Other
	if sum != info.Sys {
		t.Fatalf("categories total %d, Sys is %d", sum, info.Sys)
	}
	data, err := json.Marshal(info)
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]uint64
	if err := json.Unmarshal(data, &payload); err != nil {
		t.Fatal(err)
	}
	expected := map[string]uint64{"sys": 4096, "heapObjects": 1024, "heapUnused": 256, "heapIdle": 128, "heapReleased": 2048, "stacks": 256, "metadata": 128, "gc": 128, "other": 128}
	for key, value := range expected {
		if payload[key] != value {
			t.Fatalf("%s = %d, want %d", key, payload[key], value)
		}
	}
}

func TestGetMemoryReturnsConsistentSnapshot(t *testing.T) {
	info := handleGetMemory()
	sum := info.HeapObjects + info.HeapUnused + info.HeapIdle + info.HeapReleased + info.Stacks + info.Metadata + info.GC + info.Other
	if info.Sys == 0 || sum != info.Sys {
		t.Fatalf("inconsistent runtime memory snapshot: %+v (sum %d)", info, sum)
	}
}
