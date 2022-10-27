# Troubleshooting 

## Helm chart failures 

There could be a case where a `terraform apply` fails during the installation/update of a helm chart component. In such scenarios, helm may not update the release status accordingly and by running `terraform apply` again you may receive the following error message: 

``` 
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress 
``` 

In order to fix this issue the release has to be rolled back to a previous revision version. The steps are described as below: 

``` 
helm list --failed -a -A  
helm history [chart] -n [namespace]  
helm rollback [chart] [revision] 
``` 

`helm history` should return information regarding the charts revisions, their status and description as whether it completed successfully or not. 
Run `terraform apply` again once the chart rollback is successful and it is not listed as *pending* anymore. 
