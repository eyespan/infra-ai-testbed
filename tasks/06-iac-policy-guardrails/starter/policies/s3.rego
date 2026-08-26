package terraform.s3

# Stub: always allow. Replace with a real deny on unencrypted buckets.
deny contains msg if {
  false
  msg := "placeholder"
}
