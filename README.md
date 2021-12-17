# content-fusion-log4j-patcher

This is a tool that removes the JndiLookup class from tje log4j library found in an Oxygen Content Fusion installation.

### Prerequisites
The patch requires the zip command to be installed before running and it must be ran as root.

### Instructions

- Enable maintenance mode [1] in Content Fusion
- Copy the [log4shell-patch.sh](https://github.com/oxygenxml/content-fusion-log4j-patcher/releases/download/1.0.0/log4shell-patch.sh) to the Content Fusion host and execute it:
  ```
  sudo bash log4shell-patch.sh
  ```
- Disable maintenance mode [1] in Content Fusion

[1] https://www.oxygenxml.com/doc/versions/4.1/ug-content-fusion/topics/cf-enterprise-configuration.html?hl=Enable%20Maintenance%20Mode#cf-enterprise-configuration__dlentry_hh5_dgk_54b
