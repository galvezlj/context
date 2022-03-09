variable "context" {
  default = {}
}

variable "set" {
  default = {
    az = "c"
    prj = "ctsg"
    env = "uat"
    zone = "ez"
    tier = "db"
    name = "test"
    method = "terraform"
  }
}

variable "affix_formats" {
  default = {}
}

variable "output_tags" {
  default = []
}

variable "formatted_tags" {
  default = {Name = "az-name"}
}

locals {
  affix_formats_init = {
    prj = "%prj-%env",
    zone = "%prj-%env%zone",
    tier = "%prj-%env%zone%tier",
    az = "%az-%prj-%env%zone%tier",
    prj-name = "%prj-%env-%name",
    zone-name = "%prj-%env%zone-%name",
    tier-name = "%prj-%env%zone%tier-%name",
    az-name = "subnet-%az-%prj-%env%zone%tier-%name",
  }

  replacements = [for token, value in var.set :
    ["%${token}", value]
  ]

  affix_formats = length(var.affix_formats) > 0 ? var.affix_formats : length(lookup(var.context, "affix_formats", {})) > 0 ? var.context.affix_formats : local.affix_formats_init
  
  output_tags = coalescelist(var.output_tags, lookup(var.context, "output_tags", []), keys(var.set))
  
  context = merge(var.context, var.set,  {output_tags = local.output_tags, affix_formats = local.affix_formats})

  # # using simple replace
  # xcontext = merge(local.context, {d="-"})

  # replaced = {for affix_name, affix_format in var.affix_formats :
  #   affix_name => replace(affix_format, "-", "%d")
  # }
  # tokens = {for affix_name, replaced in local.replaced :
  #   affix_name => compact(split("%", replaced))
  # }
  # xlated = {for affix_name, tokens in local.tokens :
  #   affix_name => [ for token in tokens :
  #     lookup(local.xcontext, token, false) == false ? token :local.xcontext[token]
  #   ]
  # }
  # affixes = {for affix_name, xlated in local.xlated :
  #   affix_name => join("", xlated)
  # }

  # using regex and replace for better precision and speed
  # limitation: no text in between fields due to missing loop chaining capability in terraform
  xcontext = {for key, value in local.context :
    "%${key}" => value
  }

  tokens = {for affix_name, affix_format in local.affix_formats :
    affix_name => compact(flatten(regexall("([0-9A-Za-z]+)?(-)?(%[0-9A-Za-z]+)(-)?", affix_format)))
  }

  replaced = {for affix_name, tokens in local.tokens :
    affix_name => [ for token in tokens :
      lookup(local.xcontext, token, false) == false ? token :local.xcontext[token]
    ]
  }

  affixes = {for affix_name, replaced in local.replaced :
    affix_name => join("", replaced)
  }

  tags = {for tag in local.output_tags :
    tag => lookup(local.context, tag, null)
  }
  formatted_tags = {for tag, key in var.formatted_tags :
    tag => lookup(local.affixes, key, null)
  }
}

output "context" {
  value = local.context
}

output "affixes" {
  value = local.affixes
}

output "tags" {
  value = merge(local.tags, local.formatted_tags)
}

# /* slower but more precise using js to implement loop chaining */
# terraform {
#   required_providers {
#     javascript = {
#       source  = "apparentlymart/javascript"
#       version = "0.0.1"
#     }
#   }
# }

# output "affixes2" {
#   value = {
#     for token, value in data.javascript.replaceall : token => value.result
#   }
# }

# # using normal loop
# data "javascript" "replaceall" {
#   for_each = var.affix_formats
#   source = "for(var i = 0; i < replacements.length; i++) {input=input.replace(replacements[i][0], replacements[i][1])} input;"
#   vars = {
#     replacements = local.replacements
#     input = each.value
#   }
# }

# # using reduce
# data "javascript" "replaceall" {
#   for_each = var.affix_formats
#   source = "_.reduce(replacements, function(affix, rule) { return affix.replace(new RegExp(rule[0]), rule[1]);}, input)"
#   vars = {
#     replacements = local.replacements
#     input = each.value
#   }
# }
# /**/