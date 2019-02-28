# Terraform scripts to create Azure VM with Mongo DB

## Init terraform

Run:

```bash
terraform init
```

## Plan changes

Run:

```bash
terraform plan -var-file="..\free_account.tfvars" -var-file="environment_configs\dev\development.tfvars"
```


## Apply changes

## Destroy changes
