//go:build ios && cgo

package main

/*
#include <mach/mach.h>

static uint64_t phys_footprint(void) {
	task_vm_info_data_t info;
	mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
		return 0;
	}
	return info.phys_footprint;
}
*/
import "C"

// phys_footprint is the figure jetsam compares against the Network
// Extension's memory limit, so it includes allocations Go cannot see.
func memoryFootprint() uint64 {
	return uint64(C.phys_footprint())
}
