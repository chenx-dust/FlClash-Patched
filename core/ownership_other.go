//go:build !(darwin || linux) || android || ios

package main

func initOwnership(homeDir string) {}

func scheduleReclaimOwnership() {}
