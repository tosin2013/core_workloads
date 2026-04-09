#!/bin/bash
echo "Cleaning up test deployment sno-test1..."
oc delete clusterdeployment sno-test1 -n agent-sno-vms --ignore-not-found=true
oc delete agentclusterinstall sno-test1 -n agent-sno-vms --ignore-not-found=true
sleep 5
oc delete vm sno-test1-master-0 -n agent-sno-vms --ignore-not-found=true
oc delete infraenv infraenv-sno-test1 -n agent-sno-vms --ignore-not-found=true
oc delete secret pullsecret-sno-test1 -n agent-sno-vms --ignore-not-found=true
echo "Cleanup complete. Ready for fresh deployment."
