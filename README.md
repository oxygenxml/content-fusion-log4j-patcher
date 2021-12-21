# content-fusion-log4j-patcher

This is a tool that updates the log4j library, found in an Oxygen Content Fusion, to version 2.17. 

### Instructions

- Enable maintenance mode [1] in Content Fusion
- Extract [content-fusion-log4j-patcher.zip](https://github.com/oxygenxml/content-fusion-log4j-patcher/releases/download/1.1.0/content-fusion-log4j-patcher.zip) on the Content Fusion host and execute the log4shell-patch.sh script:
  ```
  sudo bash log4shell-patch.sh
  ```
- Disable maintenance mode [1] in Content Fusion

[1] https://www.oxygenxml.com/doc/versions/4.1/ug-content-fusion/topics/cf-enterprise-configuration.html?hl=Enable%20Maintenance%20Mode#cf-enterprise-configuration__dlentry_hh5_dgk_54b
