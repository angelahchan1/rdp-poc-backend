module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 4.0"

  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_key"

  attributes = [
    {
      name = "image_key"
      type = "S"
    }
  ]
}
