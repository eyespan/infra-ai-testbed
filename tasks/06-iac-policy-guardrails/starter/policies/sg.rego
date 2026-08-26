package terraform.sg

# Stub: always allow. Replace with a deny on 0.0.0.0/0 to 22/3389.
deny contains msg if {
  false
  msg := "placeholder"
}
