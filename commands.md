az deployment group create \
 --resource-group hello-rg \
 --template-file vm-arm-template.json \
 --parameters @vm-parameters.json

az deployment group create \
 --resource-group hello-rg \
 --template-file vm-arm-template.bicep \
 --parameters @vm-parameters-bicep.json
