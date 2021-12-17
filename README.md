# content-fusion-log4j-patcher

This is a tool that removes the JndiLookup class from tje log4j library found in an Oxygen Content Fusion installation.

### Prerequisites
The patch requires the zip command to be installed before running and it must be ran as root.

### Instructions
To apply copy the log4shell-patch.sh on the Content Fusion host and execute it:
```
sudo bash log4shell-patch.sh
```
