# SCCM-Patch-and-Boot
script for interacting with the sccm client.

# Used Case
Needed a single script that could be executed through a scheduled task to pull any updates made available to the machine, install them and reboot. The use of maintenance windows in the SCCM console was not a viable means for 100's of server owners trying to automate windows patching for 70,000 + Windows Servers. Instead of duplicating the same work (creating a software catalog, scheduling deployments to collections, building collections) between 100's of sys admins, have 1 collection and 1 deployment to thousands of machines (everybody takes the same patches). The server will query for updates in the background, weekly, and reboot if needed. 

# Script logic:
1.	generate a log file, log all details of steps below to it
2.	scan the patches that are currently installed
3.	look for any ‘missing/required’ patches by pulling any approvals made to it via sccm deployments
4.	kick off the installation of those approved patches
5.	kick off a loop to wait 3 minutes while patches are in an evaluation state of 6 or 7 (pending installation)
6.	if there are no patches in a pending state then check if a reboot is pending, if true - reboot 
7.	else, exit the script, no reboot is needed
