variable "name" {
  description = "Name of the repository, for example \"platform/api\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", var.name)) && length(var.name) <= 256
    error_message = "A repository name is lower case: letters, digits, and . _ - / between them."
  }
}

variable "untagged_expiry_days" {
  description = "Days an untagged image is kept."
  type        = number
  default     = 7
}

variable "release_tag_patterns" {
  description = "Tag patterns of release images, which get their own retention."
  type        = list(string)
  default     = ["v*"]
}

variable "max_release_images" {
  description = "Release images kept, newest first."
  type        = number
  default     = 30
}

variable "max_other_images" {
  description = "Other images kept, newest first, once releases and untagged images are counted out."
  type        = number
  default     = 20
}
