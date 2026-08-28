package terraform.s3

import rego.v1

in_scope(rc) if {
  rc.mode == "managed"
  some action in rc.change.actions
  action in {"create", "update"}
}

inline_encryption(after) if {
  configs := object.get(after, "server_side_encryption_configuration", [])
  some config in configs
  some rule in object.get(config, "rule", [])
  default := object.get(rule, "apply_server_side_encryption_by_default", {})
  object.get(default, "sse_algorithm", "") in {"AES256", "aws:kms"}
}

# Supports provider versions that model default encryption as a separate
# resource. Bucket values are normally resolved in plan JSON; matching names is
# a fallback for module/count addresses where the names intentionally align.
separate_encryption(bucket) if {
  enc := input.resource_changes[_]
  enc.mode == "managed"
  enc.type == "aws_s3_bucket_server_side_encryption_configuration"
  not ("delete" in enc.change.actions)
  bucket_name := object.get(bucket.change.after, "bucket", "")
  enc_bucket := object.get(enc.change.after, "bucket", "")
  enc_bucket == bucket_name
}

separate_encryption(bucket) if {
  enc := input.resource_changes[_]
  enc.mode == "managed"
  enc.type == "aws_s3_bucket_server_side_encryption_configuration"
  enc.name == bucket.name
  not ("delete" in enc.change.actions)
}

encrypted(bucket) if { inline_encryption(bucket.change.after) }
encrypted(bucket) if { separate_encryption(bucket) }

encryption_unknown(bucket) if {
  object.get(bucket.change.after_unknown, "server_side_encryption_configuration", false) == true
}

deny contains msg if {
  bucket := input.resource_changes[_]
  in_scope(bucket)
  bucket.type == "aws_s3_bucket"
  not encrypted(bucket)
  not encryption_unknown(bucket)
  msg := sprintf("S3 bucket %q has no verifiable default server-side encryption (AES256 or aws:kms).", [bucket.address])
}

deny contains msg if {
  bucket := input.resource_changes[_]
  in_scope(bucket)
  bucket.type == "aws_s3_bucket"
  not encrypted(bucket)
  encryption_unknown(bucket)
  msg := sprintf("S3 bucket %q encryption is unknown in this plan; make default encryption explicit.", [bucket.address])
}
