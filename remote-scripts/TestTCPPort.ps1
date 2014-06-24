Import-Module .\TestLibs\RDFELibstemp.psm1 -Force



 

$DeployedServices = "ICA-IEndpointSingleHS-ubuntu1210pl-3-8-2013-8-44"
isAllSSHPortsEnabled -DeployedServices $DeployedServices