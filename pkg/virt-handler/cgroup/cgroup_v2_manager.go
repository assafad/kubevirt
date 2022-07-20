package cgroup

import (
	runc_cgroups "github.com/opencontainers/runc/libcontainer/cgroups"
	runc_fs "github.com/opencontainers/runc/libcontainer/cgroups/fs2"
	runc_configs "github.com/opencontainers/runc/libcontainer/configs"
	"github.com/opencontainers/runc/libcontainer/devices"
)

var rulesPerPid = make(map[string][]*devices.Rule)

type v2Manager struct {
	runc_cgroups.Manager
	dirPath        string
	isRootless     bool
	execVirtChroot execVirtChrootFunc
}

func newV2Manager(config *runc_configs.Cgroup, dirPath string) (Manager, error) {
	runcManager, err := runc_fs.NewManager(config, dirPath)
	if err != nil {
		return nil, err
	}

	return newCustomizedV2Manager(runcManager, config.Rootless, execVirtChrootCgroups)
}

func newCustomizedV2Manager(runcManager runc_cgroups.Manager, isRootless bool, execVirtChroot execVirtChrootFunc) (Manager, error) {
	manager := v2Manager{
		runcManager,
		runcManager.GetPaths()[""],
		isRootless,
		execVirtChroot,
	}

	return &manager, nil
}

func (v *v2Manager) GetBasePathToHostSubsystem(_ string) (string, error) {
	return v.dirPath, nil
}

func (v *v2Manager) Set(r *runc_configs.Resources) error {
	// We want to keep given resources untouched
	resourcesToSet := *r

	//Add default rules
	resourcesToSet.Devices = append(resourcesToSet.Devices, GenerateDefaultDeviceRules()...)

	rulesToSet, err := addCurrentRules(rulesPerPid[v.dirPath], resourcesToSet.Devices)
	if err != nil {
		return err
	}
	rulesPerPid[v.dirPath] = rulesToSet
	resourcesToSet.Devices = rulesToSet

	err = v.execVirtChroot(&resourcesToSet, map[string]string{"": v.dirPath}, v.isRootless, v.GetCgroupVersion())
	return err
}

func (v *v2Manager) GetCgroupVersion() CgroupVersion {
	return V2
}

func (v *v2Manager) GetCpuSet() (string, error) {
	return getCpuSetPath(v, "cpuset.cpus.effective")
}
