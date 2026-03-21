az deployment group create \
 --resource-group hello-rg \
 --template-file vm-arm-template.json \
 --parameters @vm-parameters.json
